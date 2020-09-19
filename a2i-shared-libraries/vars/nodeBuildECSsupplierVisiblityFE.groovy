def call(Map pipelineArgs){
  
  pipeline {
    agent any

    environment {
      ORG = utility.getOrgName()
      APP_NAME = utility.getAppName()
      DOCKER_REGISTRY_ORG = utilityData.getECRName()
      ENV_NAME = utility.getEnvironment("$BRANCH_NAME")
      GIT_CRED_ID = 'BitBucketAdmin'
      REPO_URL = utility.getRepoURL()
    }

    stages {
      stage('Git Pull') {
        when { anyOf { branch 'dev'; branch 'release'} }
        environment {
          PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
          
        }
        steps {
          //sendNotificationa2i 'STARTED'
          sh "git checkout $BRANCH_NAME"
          sh "git config --global credential.helper store"
          sh "echo \$(jx-release-version)-$PREVIEW_VERSION > VERSION"
          sh "sed -i -e \"s/appVersion.*/appVersion = \'\$(cat VERSION)\'/\" node.properties"
        }
      }
      
      stage('Initialize ECR and ECS') {
        environment {
          PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
          IMAGE="${DOCKER_REGISTRY_ORG}/${ORG}/${APP_NAME}-${ENV_NAME}"
          APP_TD = 'task_definition.json'
          PHASE = "build:${ENV_NAME}"
        }
        steps {
          script{
            def repo_result = utilityData.createDockerRegistry("${ORG}/${APP_NAME}-${ENV_NAME}")
          }
        }
      }

      stage('Install & Test') {
        when { anyOf { branch 'dev'; branch 'release'} }
        environment {
          PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
          DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
          DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
          PHASE = "test:commit"
        }
        steps {
          script{
            utilityData.createDockerfile()
          }
          sh "mkdir ${WORKSPACE}/coverage"
          sh "sed -i -e \"s/PHASE/${PHASE}/\" Dockerfile"
          //sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          //sh "docker run -t -v ${WORKSPACE}/coverage:/usr/src/app/coverage -e PHASE=${PHASE} \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}:\$(cat VERSION)"
          //sh "ls -ltr ${WORKSPACE}/coverage"
          //cobertura coberturaReportFile: 'coverage/cobertura-coverage.xml'
        }
      }
      
      stage('Docker Build & Artefact') {
        when { anyOf { branch 'dev'; branch 'release'} }
        environment {
          PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
          DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
          DC = utility.createImageSecret("$PREVIEW_NAMESPACE")
          PHASE = "build:${ENV_NAME}"
        }
        steps {
          sh "rm -rf Dockerfile"
          script {
            utilityData.createDockerfile()
          }
          sh "sed -i -e \"s/PHASE/${PHASE}/\" Dockerfile"
          sh "docker build . -t \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}-\${ENV_NAME}:\$(cat VERSION)"
          sh "eval \$(/var/lib/jenkins/assume-role.sh aws ecr get-login --no-include-email --region eu-west-1) && sleep 10"
          sh "docker push \${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME}-\${ENV_NAME}:\$(cat VERSION)"
          sh "rm Dockerfile"
        }
      }
      
      stage('Deploy to ECS non-prod') {
        when { anyOf { branch 'dev'; branch 'release'} }
        environment {
          PREVIEW_VERSION = "$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          DOCKER_REGISTRY = "${env.DOCKER_REGISTRY_ORG}"
          IMAGE="${DOCKER_REGISTRY_ORG}/${ORG}/${APP_NAME}-${ENV_NAME}"
          APP_TD = 'task_definition.json'
          PHASE = "build:${ENV_NAME}"
        }
        steps {
          script{
            utility.createTD()
            def repo_result = utilityData.createDockerRegistry("${ORG}/${APP_NAME}-${ENV_NAME}")
            if (initECS.isServiceSupplier()){
              println('Updating service...')
              def BE_IMAGE = utilityData.getECRRepoLatestTag("axiom-telecom/a2i-data-supplier-visibility-api-${ENV_NAME}")
              println(BE_IMAGE)
              initECS.initTaskDefinition_FE(BE_IMAGE)
              def ver = initECS.getVersionSupplier()
              initECS.updateService(ver)
            }
            else {
              println('Creating cluster and service...')
              initECS.createCluster()
              initECS.initTaskDefinition_FE()
              def lbARN = initECS.createLB()
              def tgARN1 = initECS.createTargetGroup("${APP_NAME}-${ENV_NAME}", "80")
              def tgARN2 = initECS.createTargetGroup("supplier-api-${ENV_NAME}", "3003")
              println(lbARN)
              println(tgARN1)
              println(tgARN2)
              initECS.createListener(tgARN1, "443", lbARN, 'HTTPS')
              initECS.createListener(tgARN2, "3003", lbARN, 'HTTPS')
              initECS.createService(tgARN1, tgARN2)
            }
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
        //sendNotificationa2i currentBuild.result
      }
    }
  }
}