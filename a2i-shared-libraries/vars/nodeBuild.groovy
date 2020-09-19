def call(Map pipelineArgs){
  
pipeline {
  agent any

  environment {
    ORG = utility.getOrgName()
    APP_NAME = utility.getAppName()
    //CHARTMUSEUM_CREDS = credentials('jenkins-x-chartmuseum')
    DOCKER_REGISTRY_ORG = utility.getECRName()
    ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
    BUILD_OPTS = 'clean build -x test'
    GIT_CRED_ID = 'BitBucketAdmin'
    REPO_URL = utility.getRepoURL()
  }
  stages {
    stage('Git Pull') {
      when { anyOf { branch 'dev'; branch 'release'} }
      environment {
        //PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER".replaceAll('\\/','_')
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }
      steps {
        // ensure we're not on a detached head
        sendNotifications 'STARTED'
        sh "git checkout $BRANCH_NAME"
        sh "git config --global credential.helper store"
        sh "echo \$(jx-release-version)-$PREVIEW_VERSION > VERSION"
        sh "sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" node.properties"
      }
    }

    stage('Install & Test') {
      when { anyOf { branch 'dev'; branch 'release'} }
      environment {
        //PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER".replaceAll('\\/','_')
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
        PHASE = "test:commit"
      }
      steps {
        script{
          utility.createDockerfile()
        }
        sh "mkdir ${WORKSPACE}/coverage"
        sh "docker build . --build-arg ENV_NAME=${ENV_NAME} -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "docker run -t -v ${WORKSPACE}/coverage:/usr/src/app/coverage -e PHASE=${PHASE} \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "ls -ltr ${WORKSPACE}/coverage"
        cobertura coberturaReportFile: 'coverage/cobertura-coverage.xml'
      }
    }
    
    stage('Docker Build & Artefact') {
      when { anyOf { branch 'dev'; branch 'release'} }
      environment {
        //PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER".replaceAll('\\/','_')
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
       //PHASE = "build:${ENV_NAME}"
      }
      steps {
        script {
          utility.createDockerfile()
        }
        // ensure we're not on a detached head
        sh "docker build . --build-arg ENV_NAME=${ENV_NAME} -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
        sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "rm Dockerfile"
      }
    }    
    stage('Deploy on EKS'){
      when {  
        expression { return pipelineArgs.deploy } 
        anyOf { branch 'dev'; branch 'release'}
      }
      environment {
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
        //PHASE = "build:${ENV_NAME}"
        PHASE = "start:${ENV_NAME}"
      }
      steps{
        script {
          deployEKS.installNodeChart()
        }
      }
    }
    stage('Build Release (Production)') {
      when { allOf { branch 'master'; not { changeset "Makefile" }; not { changeset "node.properties" } } }
      environment {
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
        //PHASE = "build:${ENV_NAME}"
        PHASE = "start:${ENV_NAME}"
      } 
      steps {
          script{
            utility.createDockerfile()
          }
        // ensure we're not on a detached head
          sh "git checkout master"
            // so we can retrieve the version in later steps
          sh "echo \$(jx-release-version) > VERSION"
          sh "echo VERSION := \$(cat VERSION)-SNAPSHOT > Makefile"
          sh 'sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" node.properties'
          sh "docker build . --build-arg ENV_NAME=${ENV_NAME} -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
          sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          withCredentials([usernamePassword(credentialsId: "${env.GIT_CRED_ID}", passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
          //sh "git push origin $BRANCH_NAME --tags"
          sh """
             git config --global credential.helper store
             git config --global user.email \"admin.hyke@axiomtelecom.com\"
             git config --global user.name \"Hyke Admin\"
             git add Makefile node.properties && git commit -a -m \"release \$(cat VERSION)\" || :
             git tag -fa v\$(cat VERSION) -m \"Release version \$(cat VERSION)\"
             git push https://${GIT_USERNAME}:${GIT_PASSWORD}@bitbucket.org/\${ORG}/\${APP_NAME} $BRANCH_NAME --tags
             """
          }
          script {
            deployEKS.installProdNodeChart()
          }
      }
    }
  }
  post {
      always {
        echo "Cleaning up ${WORKSPACE}"
        // clean up our workspace 
        deleteDir()
        // clean up tmp directory 
        dir("${workspace}@tmp") {
            deleteDir()            
        
        }
        sendNotifications currentBuild.result
      }
    }
  }
}
