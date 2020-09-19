
def call() {
pipeline {
		agent any

		environment {
					GIT_CRED_ID = 'a2i_Git_repo'
		}

	stages {

			stage ('Check for branch name'){
				steps{
							echo 'Pulling... ' + env.GIT_BRANCH
						 }
			}

   		stage('Prepare code and environment for master'){
								steps{

								//	sendNotificationa2i 'STARTED'

									sh """

											echo "Working on master branch"

											echo "Installing python3-venv if it doesn't exists"

											sudo apt-get install python3-venv -y

											echo "Installing required library for execution"

											sudo apt-get install libpq-dev python-dev -y

											sudo apt-get install python3-distutils -y

											echo "Preparing Virtual environment sync-redshift"

											python3 -m venv sync-redshift

											echo "Activating Virtual environment sync-redshift"

											echo "Installing all dependencies in Virtual environment sync-redshift"

											sudo ./sync-redshift/bin/pip install -r ./requirements.txt

									"""
				   		}
			}


			stage('Execute script for master') {
				  steps{
					sh """

						  echo "Executing scripts ${WORKSPACE}"
						  ./sync-redshift/bin/python3 ./main.py

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
				sh """
						echo "Cleaning up ${WORKSPACE}"
						#sudo rm -rf ${WORKSPACE}

						echo "Cleaning up ${WORKSPACE}@tmp"
						#sudo rm -rf ${workspace}@tmp
				"""
				sendNotificationa2i currentBuild.result
			}
		}
	}
}
