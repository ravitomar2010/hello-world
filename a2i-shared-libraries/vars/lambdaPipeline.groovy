
def call() {
	pipeline {
		agent any
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
			LAYER_PROD = 'arn:aws:lambda:eu-west-1:530328198985:layer:a2i-lambda-layer:22'
			LAYER_STAGE = 'arn:aws:lambda:eu-west-1:403475184785:layer:a2i-lambda-layer:14'
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
									echo "Working on \$dir"
									###Case having Layerfile in repo
									LayerFileToCheck="\$dir/Layerfile.txt"
									if test -f "\$LayerFileToCheck" ; then
											echo "Layers to include are"
											layersList=`cat "\$LayerFileToCheck"`
											LAYER_STAGE=''
											layerCount=0
												for layer in \$(echo "\$layersList" | tr "," "\n");
												do
																echo "layer to include is "
																echo \$layer
																newARN=`aws lambda list-layer-versions --layer-name \$layer --max-items 1 --profile stage | grep '"LayerVersionArn":' | cut -d ':' -f2- |  cut -d ',' -f1 | cut -d '"' -f2`
																if [ "\$layerCount" -eq 0 ]; then
																		echo "This is first layer to include"
																		LAYER_STAGE="\$newARN"
																		layerCount=1
																else
																    echo "This is other layer to include"
																	  LAYER_STAGE="\$LAYER_STAGE \$newARN"
																fi
												done;
											echo "Layer stage made is \$LAYER_STAGE"
									else
											echo "Repo doesn't have Layerfile defined"
											LAYER_STAGE='arn:aws:lambda:eu-west-1:403475184785:layer:a2i-lambda-layer:11'
									fi ###Case having Layerfile in repo


									########Actual deployment code
									dir=\${dir%*/}
									dir=`echo \$dir | sed -e "s/lambda//g"`
									dir=`echo \$dir | sed -e "s,/,,g"`
									#LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile stage)
									case "\$LAMBDA_INFO" in
									  *${BRANCH_NAME}-${APP_NAME}-\${dir}*)
									    echo "Lambda ${BRANCH_NAME}-${APP_NAME}-\${dir} exists updating...."
									    aws lambda update-function-configuration \
									    --function-name ${BRANCH_NAME}-${APP_NAME}-\${dir} \
									    --handler \${dir}.s3tords \
									    --timeout ${TIMEOUT} \
									    --memory-size ${MEMORY} \
									    --environment Variables="{environment=\${BRANCH_NAME}}" \
									    --layers \$LAYER_STAGE \
									    --role ${ROLE_STAGE} \
									    --region eu-west-1 \
									    --profile stage
									    #[--description <value>]
									    #[--vpc-config <value>]
									    #[--runtime <value>]
									    #[--dead-letter-config <value>]
									    #[--kms-key-arn <value>]
									    #--tracing-config Mode=Active \
									    #[--revision-id <value>]
									    #[--cli-input-json <value>]
									    #[--generate-cli-skeleton <value>];
									    aws lambda update-function-code \
									    --function-name ${BRANCH_NAME}-${APP_NAME}-\${dir} \
									    --zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
									    --publish \
									    --region eu-west-1 \
									    --profile stage;
									  ;;
									  *       )
									    aws lambda create-function \
									    --function-name ${BRANCH_NAME}-${APP_NAME}-\${dir} \
									    --runtime python3.6 \
									    --timeout ${TIMEOUT} \
									    --role ${ROLE_STAGE} \
									    --handler \${dir}.s3tords \
									    --zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
									    --publish --memory-size ${MEMORY} \
									    --vpc-config SubnetIds=subnet-00c0846e72d7d41c6,subnet-053ec79e10f124fee,SecurityGroupIds=sg-0357c3c6521e3d25d \
									    --region eu-west-1 \
									    --environment Variables="{environment=\${BRANCH_NAME}}" \
									    --layers \$LAYER_STAGE \
									    --profile stage
									  ;;
									esac
									########Actual deployment code

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

			 						echo "Working on \$dir"
			 						###Case having Layerfile in repo
			 						LayerFileToCheck="\$dir/Layerfile.txt"
			 						if test -f "\$LayerFileToCheck" ; then
			 								echo "Layers to include are"
			 								layersList=`cat "\$LayerFileToCheck"`
			 								LAYER_PROD=''
			 								layerCount=0
			 									for layer in \$(echo "\$layersList" | tr "," "\n");
			 									do
			 													echo "layer to include is "
			 													echo \$layer
			 													newARN=`aws lambda list-layer-versions --layer-name \$layer --max-items 1 --profile prod | grep '"LayerVersionArn":' | cut -d ':' -f2- |  cut -d ',' -f1 | cut -d '"' -f2`
			 													if [ "\$layerCount" -eq 0 ]; then
			 															echo "This is the first layer to include"
			 															LAYER_PROD="\$newARN"
			 															layerCount=1
			 													else
			 															echo "This is the other layer to include"
			 															LAYER_PROD="\$LAYER_PROD \$newARN"
			 													fi
			 									done;
			 								echo "Final layer to consider is \$LAYER_PROD"
			 						else
			 								echo "Repo doesn't have Layerfile defined"
			 								LAYER_PROD='arn:aws:lambda:eu-west-1:530328198985:layer:a2i-lambda-layer:20'
			 						fi ###Case having Layerfile in repo

			 					########## Actual deployment code
			 						dir=\${dir%*/}
			 						dir=`echo \$dir | sed -e "s/lambda//g"`
			 						dir=`echo \$dir | sed -e "s,/,,g"`
			 						#LAMBDA_INFO=\$(aws lambda list-functions --region eu-west-1 --profile prod)
			 						case "\$LAMBDA_INFO" in
			 							*production-${APP_NAME}-\${dir}*)
			 							echo "Lambda production-${APP_NAME}-\${dir} exists updating...."
			 							aws lambda update-function-configuration \
			 							--function-name production-${APP_NAME}-\${dir} \
			 							--handler \${dir}.s3tords \
			 							--timeout ${TIMEOUT} \
			 							--memory-size ${MEMORY} \
			 							--environment Variables={environment=production} \
			 							--layers \$LAYER_PROD \
			 							--role ${ROLE_PROD} \
			 							--region eu-west-1 \
										--tracing-config Mode=Active \
			 							--profile prod

			 							aws lambda update-function-code \
			 							--function-name production-${APP_NAME}-\${dir} \
			 							--zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
			 							--publish \
			 							--region eu-west-1 \
			 							--profile prod
			 						;;
			 						*       )
			 							aws lambda create-function \
			 							--function-name production-${APP_NAME}-\${dir} \
			 							--runtime python3.6 \
			 							--timeout ${TIMEOUT} \
			 							--role ${ROLE_PROD} \
			 							--handler \${dir}.s3tords \
			 							--zip-file fileb://${ORG}-${APP_NAME}-\${dir}.zip \
			 							--publish --memory-size ${MEMORY} \
			 							--vpc-config SubnetIds=subnet-047c2eddab2f30af3,SecurityGroupIds=sg-095b2561672b4e82f \
			 							--region eu-west-1 \
			 							--layers \$LAYER_PROD \
			 							--environment Variables={environment=production} \
										--tracing-config Mode=Active \
			 							--profile prod
			 						;;
			 						esac
			 					fi
			 				done
			 			"""
			 		}
			  }//stage-master

			stage('SonarQube analysis for developer branch') {
							environment {
									 SONARRUNER_HOME = tool name: 'sonarRunner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
							 }

									 when { anyOf { branch 'developer' ; branch 'qa'} }
									 steps {

										 withSonarQubeEnv('SonarQube') {
											 sh "${SONARRUNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${BUILD_TAG} -Dsonar.sources=${WORKSPACE}/ -Dsonar.language=py -Dsonar.projectName=${BUILD_TAG} -Dsonar.exclusions=java -Dsonar.projectVersion=1.0 -Dsonar.issuesReport.html.enable=true -Dsonar.report.export.path=${WORKSPACE}/report.json -Dsonar.issuesReport.console.enable=true"
										 }

										 sleep 60

	 									script {

	 		                   env.VUL = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${BUILD_TAG}&types=VULNERABILITY' | jq -r .total", returnStdout: true).trim()

	 		                   echo "VUL: ${env.VUL}"

	 							         env.BUG = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${BUILD_TAG}&types=BUG' | jq -r .total", returnStdout: true).trim()
	 		                   echo "BUG: ${env.BUG}"

	 			                 env.CODESMELL = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${BUILD_TAG}&types=CODE_SMELL' | jq -r .total", returnStdout: true).trim()
	 		                   echo "CODESMELL: ${env.CODESMELL}"
	 						        }

							 			slackSend channel: 'a2i-jenkins-alerts', color: "warning", message: """+++++++++++++++++++++++++++++++++++++++++++++++++\n*SonarQube Analysis Report*\n-------------------------------------------------\nPROJECTNAME : *${BUILD_TAG}*\nBRANCH : *${BRANCH_NAME}*\nBuildNumber :*${BUILD_ID}*\n\nTotal number of *VULNERABILITIES* are *${env.VUL}*\nTotal number of *BUGS* are *${env.BUG}*\nTotal number of *CODESMELL* are *${env.CODESMELL}*\n\nPlease check your SonarQube Analysis Report on this link..(<http://sonarqube.a2i.infra:9000/dashboard?id=${BUILD_TAG}|Click Here>)\n-------------------------------------------------"""
									}
				}//stage-sonardeveloper

			stage('SonarQube Analysis for master branch') {
			  	environment {
							 SONARRUNER_HOME = tool name: 'sonarRunner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
					 }

							 when { anyOf { branch 'master'} }
							 steps {

								 withSonarQubeEnv('SonarQube') {
									 sh "${SONARRUNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${BUILD_TAG} -Dsonar.sources=${WORKSPACE}/ -Dsonar.language=py -Dsonar.projectName=${BUILD_TAG} -Dsonar.exclusions=java -Dsonar.projectVersion=1.0 -Dsonar.issuesReport.html.enable=true -Dsonar.report.export.path=${WORKSPACE}/report.json -Dsonar.issuesReport.console.enable=true"
								 }

								 sh '''
								  #!/bin/bash
								  sleep 60;
								  Project="\$projectname"
									vul=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${BUILD_TAG}&types=VULNERABILITY" | jq -r .total`
									bug=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${BUILD_TAG}&types=BUG" | jq -r .total`
									codesmell=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${BUILD_TAG}&types=CODE_SMELL" | jq -r .total`

									echo "Total number of VULNERABILITIES are $vul"
									echo "Total number of BUGS are $bug"
									echo "Total number of CODE SMELL are $codesmell"

								aws ses send-email \
								--from "a2iteam@axiomtelecom.com" \
								--destination "ToAddresses=vanshika.garg@tothenew.com,axioma2ioffshoredev@intsof.com,radha.cheerath@axiomtelecom.com,anees.mohamed@axiomtelecom.com,nidhi.goel@axiomtelecom.com,axiomdipoffshoredev@intsof.com","CcAddresses=yogesh.patil@axiomtelecom.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com,anuj.kaushik@axiomtelecom.com" \
								--message "Subject={Data=SonarQube Analysis ${JOB_NAME} Report,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi Team <br><h1 style="color:blue">SonarQube Analysis Report</h1><br><b>ProjectName:</b> ${JOB_NAME}<br><b>Branch:</b> ${BRANCH_NAME}<br><b>Build Number:</b> ${BUILD_ID}<br><br><table BORDER=10 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC" width= 40% >
							 <tr padding= 8px>
							 <th colspan=2 border= 10px solid #dddddd padding= 8px style="text-align:center"><font face="Arial" color="BLACK">CODE QUALITY REPORT</font></th>
							 </tr>
							 <tr padding= 8px>
									 <td style="text-align:center"> <font face="Arial" color="RED">VULNERABILITIES</font></td>
									 <td style="text-align:center"><font face="Arial" color="RED">$vul</font></td>
							 </tr>
							 <tr padding= 8px>
									 <td style="text-align:center"> <font face="Arial" color="ORANGE">BUGS</font></td>
									 <td style="text-align:center"><font face="Arial" color="ORANGE">$bug</font></td>
							 </tr>
							 <tr padding= 8px>
									 <td style="text-align:center"> <font face="Arial" color="BLUE">CODE SMELLS</font></td>
									 <td style="text-align:center"><font face="Arial" color="BLUE">$codesmell</font></td>
							 </tr>
							 </table><br><h3>Please check your SonarQube Analysis Report on this link <a href="http://sonarqube.a2i.infra:9000/dashboard?id=${BUILD_TAG}">Click here</a></h3><br><b>Regards<br>DevOPS Team</b>,Charset=utf8}}" \
							--profile prod
              '''


							 }
			 }//stage-sonarmaster

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
				} // always
		} // post
	}//pipeline
}
