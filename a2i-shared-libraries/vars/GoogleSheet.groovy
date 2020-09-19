
def call() {
pipeline {
		agent any
		triggers {
      cron( env.BRANCH_NAME.equals('master') ? '00 18 * * *' : '')
  }
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
		}

	stages {

			stage ('Check for branch name'){
				steps{
							echo 'Pulling... ' + env.GIT_BRANCH
						 }
			}

   		stage('Prepare code and environment for master'){
						when { anyOf { branch 'master'} }
								steps{
					    	  sendNotificationa2i 'STARTED'
									sh """

									echo "Working on $env.GIT_BRANCH branch"

									echo "Installing python3-venv if it doesn't exists"

									sudo apt-get install python3-venv -y

									echo "Installing required library for execution"

									sudo apt-get install libpq-dev python-dev -y

									sudo apt-get install python3-distutils -y

									echo "Preparing Virtual environment Google-Sheet-PROD"

	                python3 -m venv /data/venvs/Google-Sheet-PROD

			            echo "Activating Virtual environment Google-Sheet"

				          echo "Installing all dependencies in Virtual environment Google-Sheet"

				          sudo /data/venvs/Google-Sheet-PROD/bin/pip install -r ./requirements.txt

									"""
				   		}
			}

	 	stage('Execute SOPS Receipient script for master') {
				when { anyOf { branch 'master'} }
				  steps{
				    sh """

				      /data/venvs/Google-Sheet-PROD/bin/python3 ./sops_recipient.py $env.GIT_BRANCH

				    """
				  }
			}

		stage('Prepare code and environment for developer') {
				when { anyOf { branch 'developer' } }
				steps{
				    //sendNotificationa2i 'STARTED'
							sh """

							echo "Working on $env.GIT_BRANCH branch"

							echo "Installing python3-venv if it doesn't exists"

							sudo apt-get install python3-venv -y

							echo "Installing required library for execution"

							sudo apt-get install libpq-dev python-dev -y

							sudo apt-get install python3-distutils -y

							echo "Preparing Virtual environment Google-Sheet-STAGE"

							python3 -m venv /data/venvs/Google-Sheet-STAGE

							echo "Activating Virtual environment Google-Sheet"

							echo "Installing all dependencies in Virtual environment Google-Sheet"

							sudo /data/venvs/Google-Sheet-STAGE/bin/pip install -r ./requirements.txt

							"""
				}
			}

			stage('Execute SOPS Receipient script for Developer') {
				when { anyOf { branch 'developer' } }
				  steps{
				    sh """

						 /data/venvs/Google-Sheet-STAGE/bin/python3 ./sops_recipient.py $env.GIT_BRANCH

				    """
				  }
			}
			stage('SonarQube Analaysis developer branch') {
			environment {
							SONARRUNER_HOME = tool name: 'sonarRunner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
					}

							when { anyOf { branch 'developer'} }
							steps {

								script {
											 env.MYVAR = sh( script: "echo 'jenkins-${JOB_NAME}' | sed 's|/|-|g'", returnStdout: true).trim()
											 echo "MYVAR: ${env.MYVAR}"
											}
								withSonarQubeEnv('SonarQube') {

									sh "${SONARRUNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${env.MYVAR} -Dsonar.sources=${WORKSPACE}/ -Dsonar.language=py -Dsonar.projectName=${env.MYVAR} -Dsonar.exclusions=java -Dsonar.projectVersion=1.0 -Dsonar.issuesReport.html.enable=true -Dsonar.report.export.path=${WORKSPACE}/report.json -Dsonar.issuesReport.console.enable=true"
								}

              sleep 60

							script {

                   env.VUL = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${env.MYVAR}&types=VULNERABILITY' | jq -r .total", returnStdout: true).trim()

                   echo "VUL: ${env.VUL}"

					         env.BUG = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${env.MYVAR}&types=BUG' | jq -r .total", returnStdout: true).trim()
                   echo "BUG: ${env.BUG}"

	                 env.CODESMELL = sh( script: "curl -sX GET 'http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=${env.MYVAR}&types=CODE_SMELL' | jq -r .total", returnStdout: true).trim()
                   echo "CODESMELL: ${env.CODESMELL}"
				        }

	slackSend channel: 'a2i-jenkins-alerts', color: "warning", message: """+++++++++++++++++++++++++++++++++++++++++++++++++\n*SonarQube Analysis Report*\n-------------------------------------------------\nPROJECTNAME : *jenkins-Google-sheet-pipeline-master*\nBRANCH : *${BRANCH_NAME}*\nBuildNumber :*${BUILD_ID}*\n\nTotal number of *VULNERABILITIES* are *${env.VUL}*\nTotal number of *BUGS* are *${env.BUG}*\nTotal number of *CODESMELL* are *${env.CODESMELL}*\n\nPlease check your SonarQube Analysis Report on this link..(<http://sonarqube.a2i.infra:9000/dashboard?id=${env.MYVAR}|Click Here>)\n-------------------------------------------------"""



							}
			}//stage-sonardeveloper


			stage('SonarQube Analaysis master') {
			environment {
							SONARRUNER_HOME = tool name: 'sonarRunner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
					}

							when { anyOf { branch 'master'} }
							steps {

								script {
                       env.MYVAR = sh( script: "echo 'jenkins-${JOB_NAME}' | sed 's|/|-|g'", returnStdout: true).trim()
                       echo "MYVAR: ${env.MYVAR}"
                      }
								withSonarQubeEnv('SonarQube') {

									sh "${SONARRUNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${env.MYVAR} -Dsonar.sources=${WORKSPACE}/ -Dsonar.language=py -Dsonar.projectName=${env.MYVAR} -Dsonar.exclusions=java -Dsonar.projectVersion=1.0 -Dsonar.issuesReport.html.enable=true -Dsonar.report.export.path=${WORKSPACE}/report.json -Dsonar.issuesReport.console.enable=true"
								}

								sh '''
								 #!/bin/bash
								 sleep 60;
								 projectkey=`echo "jenkins-\${JOB_NAME}" | sed 's|/|-|g'`

								 vul=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${projectkey}&types=VULNERABILITY" | jq -r .total`
								 bug=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${projectkey}&types=BUG" | jq -r .total`
								 codesmell=`curl -sX GET "http://sonarqube.a2i.infra:9000/api/issues/search?componentKeys=\${projectkey}&types=CODE_SMELL" | jq -r .total`

								 echo "Total number of VULNERABILITIES are $vul"
								 echo "Total number of BUGS are $bug"
								 echo "Total number of CODE SMELL are $codesmell"


								 aws ses send-email \
								 --from "a2iteam@axiomtelecom.com" \
								 --destination "ToAddresses=axioma2ioffshoredev@intsof.com,raj.bhalla@intsof.com,anees.mohamed@axiomtelecom.com,axiomdipoffshoredev@intsof.com","CcAddresses=yogesh.patil@axiomtelecom.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com,anuj.kaushik@axiomtelecom.com" \
								 --message "Subject={Data=SonarQube Analysis ${JOB_NAME} Report,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><h1 style="color:blue">SonarQube Analysis Report</h1><br><b>ProjectName:</b> ${JOB_NAME}<br><b>Branch:</b> ${BRANCH_NAME}<br><b>Build Number:</b> ${BUILD_ID}<br><br><table BORDER=10 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC" width= 40% >
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
								</table><br><h3>Please check your SonarQube Analysis Report on this link <a href="http://sonarqube.a2i.infra:9000/dashboard?id=${projectkey}">Click here</a></h3><br><b>Regards<br>DevOPS Team</b>,Charset=utf8}}" \
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
				//deleteDir()
				// clean up tmp directory
				dir("${workspace}@tmp") {
					deleteDir()
				}
				sendNotificationa2i currentBuild.result
				} // always
		} //post
	}
}
