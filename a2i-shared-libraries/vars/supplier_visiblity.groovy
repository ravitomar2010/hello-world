def call() {
	pipeline {
		agent {
            node 'master'
        }
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
			MEMORY = '256'
			ROLE = 'arn:aws:iam::530328198985:role/lambda-s3-vpc'
			TIMEOUT = '900'
		}
        stages {
            
			stage('Install the required packages locally') {
				when { anyOf { branch 'dev'; branch 'release'; branch 'master' } }
				steps{
					sendNotificationa2i 'STARTED'
					sh """
						PACKAGES=`jq -r '.dependencies | keys[] as \$k | "\\(\$k)@\\(.[\$k] | .)"' package.json`
                        mkdir -p lambda-layer/nodejs/node_modules
                        cd lambda-layer/nodejs
                        for pkg in \$PACKAGES
                        do
                            npm install --save \$pkg
                        done
                        cd ..
                        zip -r lambda-layer.zip nodejs -x *.git*
					"""
				}
			}
        
			stage('Create and Update Lambda Layer for Development and QA') {
				when { anyOf { branch 'dev'; branch 'release' } }
				steps {
					sh """
						~/assume-role.sh ~/.local/bin/aws lambda publish-layer-version \
						--layer-name ${APP_NAME}-${BRANCH_NAME} \
						--compatible-runtimes '["nodejs10.x"]' \
						--zip-file fileb://lambda-layer/lambda-layer.zip \
						--region eu-west-1 \
						| jq -r ' .LayerVersionArn' > layer_ver
						cat layer_ver
					"""		
				}
			}

			stage('Create and Update Lambda Layer for master') {
				when { anyOf { branch 'master' } }
				steps {
					sh """
						~/assume-role.sh ~/.local/bin/aws lambda publish-layer-version \
						--layer-name ${APP_NAME} \
						--compatible-runtimes '["nodejs10.x"]' \
						--zip-file fileb://lambda-layer/lambda-layer.zip \
						--region eu-west-1 \
						| jq -r ' .LayerVersionArn' > layer_ver
						cat layer_ver
					"""		
				}
			}

			stage('Create and update lambda archive') {
				when { anyOf { branch 'dev'; branch 'release'; branch 'master' } }
				steps {
					sh """
						zip -r lambda.zip . -x "*.git*" -x "*lambda-layer*" -x README.md -x Jenkinsfile
					"""
				}
			}

			stage('Create/Update lambda for Dev/QA') {
				when { anyOf { branch 'dev'; branch 'release'} }
				steps {
					sh """
						LAMBDA_INFO=\$(/var/lib/jenkins/assume-role.sh aws lambda list-functions --region eu-west-1)
						case "\$LAMBDA_INFO" in
							*${BRANCH_NAME}-${APP_NAME}*)
								echo "Lambda ${BRANCH_NAME}-${APP_NAME} exists updating...."
								/var/lib/jenkins/assume-role.sh /var/lib/jenkins/.local/bin/aws lambda update-function-configuration \
								--function-name ${BRANCH_NAME}-${APP_NAME} \
								--handler index.middleware \
								--timeout ${TIMEOUT} \
								--memory-size ${MEMORY} \
								--environment Variables="{environment=\${BRANCH_NAME}}" \
								--layers `cat layer_ver` \
								--role ${ROLE} \
								--region eu-west-1
								/var/lib/jenkins/assume-role.sh aws lambda update-function-code \
								--function-name ${BRANCH_NAME}-${APP_NAME} \
								--zip-file fileb://lambda.zip \
								--publish \
								--region eu-west-1
							;;
							*       )
								/var/lib/jenkins/assume-role.sh /var/lib/jenkins/.local/bin/aws lambda create-function \
								--function-name ${BRANCH_NAME}-${APP_NAME} \
								--runtime  nodejs10.x \
								--timeout ${TIMEOUT} \
								--role ${ROLE} \
								--handler index.middleware \
								--zip-file fileb://lambda.zip \
								--publish --memory-size ${MEMORY} \
								--vpc-config SubnetIds=subnet-047c2eddab2f30af3,SecurityGroupIds=sg-095b2561672b4e82f \
								--region eu-west-1 \
								--environment Variables="{environment=\${BRANCH_NAME}}" \
								--layers `cat layer_ver` \
								--role ${ROLE}
								
							;;
						esac
					"""
				}
			}

			stage('Create/Update lambda for master') {
				when { anyOf { branch 'master'} }
				steps {
					sh """
						LAMBDA_INFO=\$(/var/lib/jenkins/assume-role.sh aws lambda list-functions --region eu-west-1)
						case "\$LAMBDA_INFO" in
							*a2i-${APP_NAME}*)
								echo "Lambda a2i-${APP_NAME} exists updating...."
								/var/lib/jenkins/assume-role.sh /var/lib/jenkins/.local/bin/aws lambda update-function-configuration \
								--function-name a2i-${APP_NAME} \
								--handler index.middleware \
								--timeout ${TIMEOUT} \
								--memory-size ${MEMORY} \
								--environment Variables="{environment=\${BRANCH_NAME}}" \
								--layers `cat layer_ver` \
								--role ${ROLE} \
								--region eu-west-1
								/var/lib/jenkins/assume-role.sh aws lambda update-function-code \
								--function-name a2i-${APP_NAME} \
								--zip-file fileb://lambda.zip \
								--publish \
								--region eu-west-1
							;;
							*       )
								/var/lib/jenkins/assume-role.sh /var/lib/jenkins/.local/bin/aws lambda create-function \
								--function-name a2i-${APP_NAME} \
								--runtime  nodejs10.x \
								--timeout ${TIMEOUT} \
								--role ${ROLE} \
								--handler index.middleware \
								--zip-file fileb://lambda.zip \
								--publish --memory-size ${MEMORY} \
								--vpc-config SubnetIds=subnet-047c2eddab2f30af3,SecurityGroupIds=sg-095b2561672b4e82f \
								--region eu-west-1 \
								--environment Variables="{environment=\${BRANCH_NAME}}" \
								--layers `cat layer_ver` \
								--role ${ROLE}
								
							;;
						esac
					"""
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
				sendNotificationa2i currentBuild.result
			}
		}
	}
}