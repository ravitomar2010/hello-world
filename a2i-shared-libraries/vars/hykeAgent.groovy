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
        //sendNotifications 'STARTED'
        sh "git checkout $BRANCH_NAME"
        sh "git config --global credential.helper store"
        sh "echo \$(jx-release-version)-$PREVIEW_VERSION > VERSION"
        sh "sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" gradle.properties"
      }
    }

    stage('Build') {
      when { anyOf { branch 'dev'; branch 'release'; branch 'master'} }
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
    }

    stage('S3Upload-nonprod') {
      when { anyOf { branch 'dev'; branch 'release' } }
      environment {
        //PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER".replaceAll('\\/','_')
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }
      steps {
        //script {
        //  utility.createDockerfile()
        //}
        // ensure we're not on a detached head
        //sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        //sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
        //sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        //sh "rm Dockerfile"
        sh "cp build/libs/*.jar ${APP_NAME}-${BRANCH_NAME}.jar"
        withAWS(region:'eu-west-1',credentials:'hyke-agent-s3') {
          //def identity=awsIdentity();//Log AWS credentials
          // Upload files from working directory 'dist' in your project workspace
          s3Upload(bucket:"hyke-agent", includePathPattern:"${APP_NAME}-${BRANCH_NAME}.jar")
        }
        //archiveArtifacts "${APP_NAME}.jar"
      }
    }  
    stage('S3Upload-prod') {
      when { anyOf { branch 'master'} }
      environment {
        //PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER".replaceAll('\\/','_')
        PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
        DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
      }
      steps {
        //script {
        //  utility.createDockerfile()
        //}
        // ensure we're not on a detached head
        //sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        //sh "eval \$(aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
        //sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
        //sh "rm Dockerfile"
        sh "cp build/libs/*.jar ${APP_NAME}-${BRANCH_NAME}.jar"
        withAWS(region:'eu-west-1',credentials:'hyke-agent-s3') {
          //def identity=awsIdentity();//Log AWS credentials
          // Upload files from working directory 'dist' in your project workspace
          s3Upload(bucket:"hyke-agent", includePathPattern:"${APP_NAME}-*.jar")
        }
        //archiveArtifacts "${APP_NAME}.jar"
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
        //sendNotifications currentBuild.result
      }
    }
  }
}
