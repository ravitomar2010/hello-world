def call(Map pipelineArgs){
  
pipeline {
  agent any
  options {
    timeout(time: 2, unit: 'HOURS') 
    disableConcurrentBuilds()
  }
  environment {
    ORG = utility.getOrgName()
    APP_NAME = utility.getAppName()
    //CHARTMUSEUM_CREDS = credentials('jenkins-x-chartmuseum')
    DOCKER_REGISTRY_ORG = utility.getECRName()
    ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
    BUILD_OPTS = 'clean build -x test' //'clean build jacocoTestReport' //
    //BUILD_OPTS = 'clean build'
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
        sh "git tag -l"
        sh "echo \$(jx-release-version)-$PREVIEW_VERSION > VERSION"
        sh "sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" gradle.properties"
      }
    }
    stage('build && SonarQube analysis for dev branch') {
      when { anyOf { branch 'dev' } }
      environment {
        scannerHome = tool 'sonar'
      }
      steps {
        script {
          utility.createSonarProperty()
        }
        sh "sed -i \"s/sonar_projectKey/${APP_NAME}-${ENV_NAME}/g\" sonar.properties" 
        sh "sed -i \"s/sonar_projectName/${APP_NAME}-${ENV_NAME}/g\" sonar.properties"
        sh "sed -i \"s/sonar_projectVersion/${BUILD_NUMBER}/g\" sonar.properties"
        sh 'cat sonar.properties'
        sh "${steps.tool 'gradle'}/bin/gradle ${env.BUILD_OPTS}"
        sh 'tree'
        withSonarQubeEnv('hyke-dev-sonar') {
          sh "${scannerHome}/bin/sonar-scanner -Dproject.settings=sonar.properties"
        }
      }
    }
    stage('build for release branch') {
      when { anyOf { branch 'release' } }
      steps {
        sh "${steps.tool 'gradle'}/bin/gradle ${env.BUILD_OPTS}"
      }
    }
    /*stage('Test & Build') {
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
        sh "${steps.tool 'gradle'}/bin/gradle ${env.BUILD_OPTS}"
      }
    }*/
    stage('Docker Build & Artifect') {
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
        script {
          utility.createDockerfile()
        }
        // ensure we're not on a detached head
        sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
        sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        sh "rm Dockerfile"
        sh "cp build/libs/*.jar \${APP_NAME}.jar"
        archiveArtifacts "${APP_NAME}.jar"
      }
    }    
/*
    stage('Deploy on EKS for QA'){
      when {  
        expression { return pipelineArgs.deploy } 
        anyOf { branch 'release'}
      }
      environment {
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }
      steps{
        script {
          deployEKS.installChart()
        }
        echo "App should be accessible on url: http://${env.ENV_NAME}-pvt.hykeapi.com/${env.APP_NAME}/actuator/health"
      }
    }
  */  
    stage('Deploy to Dev and QA'){
    when {  
        expression { return pipelineArgs.deploy } 
        anyOf { branch 'dev' ; branch 'release' }
      }
      environment {
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }
      steps{
        script {
          deployEKS.installGradleIstioChart()
        }
        echo "App should be accessible on url: http://dev-pvt.hykeapi.com/${env.APP_NAME}/actuator/health"
      }
    }
    
    stage('Build Release (Production)') {
      when { allOf { branch 'master'; not { changeset "Makefile" }; not { changeset "gradle.properties" } } }
      environment {
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }      
      steps {
          script {
            utility.createDockerfile()
          }
          // ensure we're not on a detached head
          sh "git checkout master"
          // so we can retrieve the version in later steps
          sh "echo \$(jx-release-version) > VERSION"
          sh "echo VERSION := \$(cat VERSION)-SNAPSHOT > Makefile"
          sh 'sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" gradle.properties'
          sh "${steps.tool 'gradle'}/bin/gradle ${env.BUILD_OPTS}"
          sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
          sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          withCredentials([usernamePassword(credentialsId: "${env.GIT_CRED_ID}", passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
          //sh "git push origin $BRANCH_NAME --tags"
          sh """
             git config --global credential.helper store
             git config --global user.email \"admin.hyke@axiomtelecom.com\"
             git config --global user.name \"Hyke Admin\"
             git add Makefile gradle.properties && git commit -a -m \"release \$(cat VERSION)\" || :
             git tag -fa v\$(cat VERSION) -m \"Release version \$(cat VERSION)\"
             git push https://${GIT_USERNAME}:${GIT_PASSWORD}@bitbucket.org/\${ORG}/\${APP_NAME} $BRANCH_NAME --tags
             """
          sh "cp build/libs/*.jar \${APP_NAME}.jar"
          archiveArtifacts "${APP_NAME}.jar"
          }
        script {
          deployEKS.installProdGradleIstioChart()
        }
        echo "App should be accessible on url: http://prod-pvt.hykeapi.com/${env.APP_NAME}/actuator/health"           
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
