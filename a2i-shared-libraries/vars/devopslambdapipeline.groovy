
def call() {
	pipeline {
		agent any
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
			LAYER_PROD = 'arn:aws:lambda:eu-west-1:530328198985:layer:a2i-lambda-devops-layer:1'
			LAYER_STAGE = 'arn:aws:lambda:eu-west-1:403475184785:layer:a2i-lambda-devops-layer:1'
			MEMORY = '512'
			ROLE_PROD = 'arn:aws:iam::530328198985:role/lambda-s3-vpc'
			ROLE_STAGE = 'arn:aws:iam::403475184785:role/lambda-s3-vpc'
			TIMEOUT = '900'
		}
		stages {
			stage('Create code archives') {
				when { anyOf { branch 'developer' ; branch 'qa' ; branch 'master'} }
				steps{
				    sendNotificationa2i 'STARTED'
					sh """
						ls -ltr
						for dir in lambda/*
						do
							if [ -d \"\$dir\" ]; then
								dir=\${dir%*/}
								dir=`echo \$dir | sed -e 's/lambda//g'`
								dir=`echo \$dir | sed -e 's,/,,g'`
								cd lambda/\${dir}
								rm -rf ${ORG}-${APP_NAME}-\${dir}.zip
								zip -r ${ORG}-${APP_NAME}-\${dir}.zip .
								cp ${ORG}-${APP_NAME}-\${dir}.zip ../..
								cd -
							fi
						done
					"""
				}
			}

			stage('Create and Update Lambda function for Development and QA') {
				when { anyOf { branch 'developer' ; branch 'qa'} }
				steps {
					sh """
						LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile stage)
						for dir in lambda/*     # list directories in the form "/tmp/dirname/"
						do
							if [ -d "\$dir" ]; then
								dir=\${dir%*/}
								dir=`echo \$dir | sed -e "s/lambda//g"`
								dir=`echo \$dir | sed -e "s,/,,g"`
								#LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile stage)
								case "\$LAMBDA_INFO" in
									*devops-${APP_NAME}-\${dir}*)
										echo "Lambda devops-${APP_NAME}-\${dir} exists updating...."
										aws lambda update-function-configuration \
										--function-name devops-${APP_NAME}-\${dir} \
										--handler \${dir}.s3tords \
										--timeout ${TIMEOUT} \
										--memory-size ${MEMORY} \
										--environment Variables="{environment=\${BRANCH_NAME}}" \
										--layers ${LAYER_STAGE} \
										--role ${ROLE_STAGE} \
										--region eu-west-1 \
										--profile stage
										#[--description <value>]
										#[--vpc-config <value>]
										#[--runtime <value>]
										#[--dead-letter-config <value>]
										#[--kms-key-arn <value>]
										#[--tracing-config <value>]
										#[--revision-id <value>]
										#[--cli-input-json <value>]
										#[--generate-cli-skeleton <value>]
										aws lambda update-function-code \
										--function-name devops-${APP_NAME}-\${dir} \
										--zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
										--publish \
										--region eu-west-1 \
										--profile stage
									;;
									*       )
										aws lambda create-function \
										--function-name devops-${APP_NAME}-\${dir} \
										--runtime python3.6 \
										--timeout ${TIMEOUT} \
										--role ${ROLE_STAGE} \
										--handler \${dir}.s3tords \
										--zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
										--publish --memory-size ${MEMORY} \
										--vpc-config SubnetIds=subnet-00c0846e72d7d41c6,subnet-053ec79e10f124fee,SecurityGroupIds=sg-0357c3c6521e3d25d \
										--region eu-west-1 \
										--environment Variables="{environment=\${BRANCH_NAME}}" \
										--layers ${LAYER_STAGE} \
										--profile stage
									;;
								esac
							fi
						done

					"""
				}
			}//stage

			stage('Create and Update Lambda function if master branch') {
			    when { branch 'master' }
			    steps {
			      sh """
			        LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile prod)
			        for dir in lambda/*     # list directories in the form "/tmp/dirname/"
			        do
			          if [ -d "\$dir" ]; then
			            dir=\${dir%*/}
			            dir=`echo \$dir | sed -e "s/lambda//g"`
			            dir=`echo \$dir | sed -e "s,/,,g"`
			            #LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile prod)
			            case "\$LAMBDA_INFO" in
			              *devops-${APP_NAME}-\${dir}*)
			              echo "Lambda ${ORG}-${APP_NAME}-\${dir} exists updating...."
			              aws lambda update-function-configuration \
			              --function-name ${ORG}-${APP_NAME}-\${dir} \
			              --handler \${dir}.s3tords \
			              --timeout ${TIMEOUT} \
			              --memory-size ${MEMORY} \
			              --environment Variables={environment=production} \
			              --layers ${LAYER_PROD} \
			              --role ${ROLE_PROD} \
			              --region eu-west-1 \
										--profile prod

			              aws lambda update-function-code \
			              --function-name devops-${APP_NAME}-\${dir} \
			              --zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
			              --publish \
			              --region eu-west-1 \
										--profile prod
			            ;;
			            *       )
			              aws lambda create-function \
			              --function-name devops-${APP_NAME}-\${dir} \
			              --runtime python3.6 \
			              --timeout ${TIMEOUT} \
			              --role ${ROLE_PROD} \
			              --handler \${dir}.s3tords \
			              --zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
			              --publish --memory-size ${MEMORY} \
			              --vpc-config SubnetIds=subnet-047c2eddab2f30af3,SecurityGroupIds=sg-095b2561672b4e82f \
			              --region eu-west-1 \
			              --layers ${LAYER_PROD} \
			              --environment Variables={environment=production} \
										--profile prod
			            ;;
			            esac
			          fi
			        done
			      """
			    }
			  }
		}//stages
		post {
			failure {
					echo "Sending failed build alerts"
					sendFatalAlerts currentBuild.result
			}
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
