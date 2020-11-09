
def call() {
pipeline {
		agent any
		triggers {
      cron( env.BRANCH_NAME.equals('master') ? '00 09,20 * * *' : '')
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
							/data/venvs/Google-Sheet-STAGE/bin/python3 ./kdr_status_recipient.py $env.GIT_BRANCH

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
						 /data/venvs/Google-Sheet-STAGE/bin/python3 ./kdr_status_recipient.py $env.GIT_BRANCH

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
