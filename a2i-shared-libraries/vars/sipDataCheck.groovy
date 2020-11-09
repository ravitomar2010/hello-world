
def call() {
pipeline {
		agent any

		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
		}

	stages {

			stage ('Check for branch name'){
				when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
				steps{
							echo 'Pulling... ' + env.GIT_BRANCH
						 }
			}

			stage('Prepare code and environment for master'){
			      when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
			          steps{
			            sendNotificationa2i 'STARTED'
			            sh """

			              echo "Working on master branch"

			              echo "Installing python3-venv if it doesn't exists"

			              sudo apt-get install python3-venv -y

			              echo "Installing required library for execution"

			              sudo apt-get install libpq-dev python-dev -y

			              sudo apt-get install python3-distutils -y

										sudo apt-get install libmysqlclient-dev -y

			              echo "Preparing Virtual environment prod-sip-datacheck"

			              python3 -m venv /data/venvs/prod-sip-datacheck

			              echo "Activating Virtual environment prod-sip-datacheck"

			              echo "Installing all dependencies in Virtual environment prod-sip-datacheck"

			              sudo /data/venvs/prod-sip-datacheck/bin/pip install -r ./scripts/source_sip_data_check/requirements.txt

			            """
			        }
			}

			stage('Execute sip data check script for master') {
			  when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
			    steps{
			      sh """

							cd ./scripts/source_sip_data_check
			        /data/venvs/prod-sip-datacheck/bin/python3 ./source_sip_data_check.py master

			      """
			    }
			 }

			 stage('Cleanup of venv for master branch') {
			  when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
			    steps{
			      sh """
									echo "For now I am not deleting virtual environment"

			      """
			    }
			 }


			stage('Prepare code and environment for developer and qa') {
				when {
						anyOf {
								expression { env.GIT_BRANCH ==~ 'origin/developer' }
								expression { env.GIT_BRANCH ==~ 'origin/qa' }
							}
						}
				steps{
			      //sendNotificationa2i 'STARTED'
			        sh """

			        echo "Installing python3-venv if it doesn't exists"

			        sudo apt-get install python3-venv -y

			        echo "Installing required libraries for execution"

			        sudo apt-get install libpq-dev python-dev -y

							sudo apt-get install python3-distutils -y

							sudo apt-get install libmysqlclient-dev -y

			        echo "Preparing Virtual environment stage-sip-datacheck"

			        python3 -m venv /data/venvs/stage-sip-datacheck

			        echo "Activating Virtual environment /data/venvs/stage-sip-datacheck"

			        echo "Installing all dependencies in Virtual environment stage-sip-datacheck"

			        sudo /data/venvs/stage-sip-datacheck/bin/pip install -r ./scripts/source_sip_data_check/requirements.txt

			        """
			  }
			}

			stage('Execute sip data check scripts for developer or qa branch') {
				when {
							anyOf {
									expression { env.GIT_BRANCH ==~ 'origin/developer' }
									expression { env.GIT_BRANCH ==~ 'origin/qa' }
								}
							}
				steps{
			      sh """

							cd ./scripts/source_sip_data_check
							/data/venvs/stage-sip-datacheck/bin/python3 ./source_sip_data_check.py developer

			      """
			    }
			}

			stage('Cleanup of venv for stage branch') {
				when {
						anyOf {
								expression { env.GIT_BRANCH ==~ 'origin/developer' }
								expression { env.GIT_BRANCH ==~ 'origin/qa' }
							}
						}
				steps{
					 sh """
					 				echo "For now I am not deleting virtual environment"
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
				// deleteDir()
				dir("${workspace}@tmp") {
				// deleteDir()
				}
				sendNotificationa2i currentBuild.result

			}
		}
	}
}
