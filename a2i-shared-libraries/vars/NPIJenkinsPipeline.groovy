
def call() {
pipeline {
		agent any
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
     BRANCH_NAME = "${GIT_BRANCH.split("/")[1]}"
		}

	stages {

			stage ('Check for branch name'){
					steps{
								echo 'Pulling... ' + env.GIT_BRANCH
								echo 'Branch name:' + env.BRANCH_NAME
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

											echo "Preparing Virtual environment npi-prod"

			                python3 -m venv /data/venvs/npi-prod

					            echo "Activating Virtual environment NPI"

						          echo "Installing all dependencies in Virtual environment NPI"

						          sudo /data/venvs/npi-prod/bin/pip install -r ./scripts/NPI/requirement.txt

									"""
				   		}
			}

	 	stage('Execute similiar product finder script for master') {
				when { anyOf { branch 'master'} }
				  steps{
				    sh """

				      /data/venvs/npi-prod/bin/python3 ./scripts/NPI/Similar_Product_Finder.py $env.GIT_BRANCH

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

							echo "Preparing Virtual environment npi-stage"

							python3 -m venv /data/venvs/npi-stage

							echo "Activating Virtual environment NPI"

							echo "Installing all dependencies in Virtual environment NPI"

							sudo /data/venvs/npi-stage/bin/pip install -r ./scripts/NPI/requirement.txt

							"""
				}
			}

			stage('Execute Similar-Product-Finder script for Developer') {
				when { anyOf { branch 'developer' } }
				  steps{
				    sh """

						 /data/venvs/npi-stage/bin/python3 ./scripts/NPI/Similar_Product_Finder.py $env.BRANCH_NAME

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
				} // always
		} //post
	}
}
