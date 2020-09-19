
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

										echo "Preparing Virtual environment prod-df-ksa"

										python3 -m venv /data/venvs/prod-df-ksa

										echo "Activating Virtual environment prod-df-ksa"

										echo "Installing all dependencies in Virtual environment prod-df-ksa"

										sudo /data/venvs/prod-df-ksa/bin/pip install -r ./scripts/requirements.txt

									"""
				   		}
			}


			stage('Execute safety-stock script for master') {
				when { anyOf { expression { env.GIT_BRANCH ==~ 'origin/master' } } }
				  steps{
					sh """

							/data/venvs/prod-df-ksa/bin/python3 ./scripts/safety-stock.py master

					"""
				  }
			}

			stage('Execute a2i-df-replenishment for master') {
				when { anyOf { expression { env.GIT_BRANCH ==~ 'origin/master' } } }
					steps{
						sh """

								response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-system-replenishment-ksa" --profile prod`

						"""
					}
			}

			stage('Cleanup of venv for master branch') {
			 when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
				 steps{
					 sh """
					 				echo "For now I am not deleting Virtual environment"
					 			 #sudo rm -rf /data/venvs/prod-df-ksa
								 #sudo rm -rf /var/lib/jenkins/workspace/production-daily-safety-stock-and-replenishment/prod-df-ksa

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

							echo "Installing required library for execution"

							sudo apt-get install libpq-dev python-dev -y

							echo "Preparing Virtual environment stage-df-ksa"

							python3 -m venv /data/venvs/stage-df-ksa

							echo "Activating Virtual environment stage-df-ksa"

							echo "Installing all dependencies in Virtual environment stage-df-ksa"

							sudo /data/venvs/stage-df-ksa/bin/pip install -r ./scripts/requirements.txt

							"""
				}
			}


			stage('Execute safety-stock script for developer') {
				when {
						anyOf {
								expression { env.GIT_BRANCH ==~ 'origin/developer' }
								expression { env.GIT_BRANCH ==~ 'origin/qa' }
							}
						}
				steps{
				    sh """

							#echo "Inside safety-stock step"
				      /data/venvs/stage-df-ksa/bin/python3 ./scripts/safety-stock.py developer

				    """
				  }
			}

			stage('Execute a2i-df-replenishment for stage') {
			when {
						anyOf {
								expression { env.GIT_BRANCH ==~ 'origin/developer' }
								expression { env.GIT_BRANCH ==~ 'origin/qa' }
							}
						}
		  steps{
			    sh """

							echo "Inside a2i-df-replenishment step"
			        response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:403475184785:stateMachine:a2i-df-system-replenishment-ksa" --profile stage`

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
					 			 echo "For now I am not deleting Virtual environment"
								 #sudo rm -rf /data/venvs/stage-df-ksa

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
