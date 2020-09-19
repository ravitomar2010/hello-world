
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

										echo "Preparing Virtual environment prod-df"

										python3 -m venv /data/venvs/prod-df

										echo "Activating Virtual environment prod-df"

										echo "Installing all dependencies in Virtual environment prod-df"

										sudo /data/venvs/prod-df/bin/pip install -r ./scripts/requirements.txt

									"""
				   		}
			}


			stage('Execute safety-stock script for master') {
				when { anyOf { expression { env.GIT_BRANCH ==~ 'origin/master' } } }
				  steps{
					sh """

							/data/venvs/prod-df/bin/python3 ./scripts/safety-stock.py master

					"""
				  }
			}

			stage('Execute a2i-df-replenishment for master') {
				when { anyOf { expression { env.GIT_BRANCH ==~ 'origin/master' } } }
					steps{
						sh """

								response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-system-replenishment" --profile prod`

						"""
					}
			}

			stage('Cleanup of venv for master branch') {
			 when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
				 steps{
					 sh """
					 				echo "For now I am not deleting Virtual environment"
					 			 #sudo rm -rf /data/venvs/prod-df
								 #sudo rm -rf /var/lib/jenkins/workspace/production-daily-safety-stock-and-replenishment/prod-df

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

							echo "Preparing Virtual environment stage-df"

							python3 -m venv /data/venvs/stage-df

							echo "Activating Virtual environment stage-df"

							echo "Installing all dependencies in Virtual environment stage-df"

							sudo /data/venvs/stage-df/bin/pip install -r ./scripts/requirements.txt

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
				      /data/venvs/stage-df/bin/python3 ./scripts/safety-stock.py developer

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
			        response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:403475184785:stateMachine:a2i-df-system-replenishment" --profile stage`

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
								 #sudo rm -rf /data/venvs/stage-df

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
