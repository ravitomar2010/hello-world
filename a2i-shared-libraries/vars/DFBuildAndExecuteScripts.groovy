
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
						when { anyOf { branch 'master'} }
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

			stage('Execute aws-dataset-input script for master') {
				when { anyOf { branch 'master'} }
				  steps{
				    sh """

							/data/venvs/prod-df/bin/python3 ./scripts/aws_dataset_input.py $env.GIT_BRANCH

				    """
				  }
			 }

			 stage('Execute a2i-df-model-output-pareto for master') {
 				when { anyOf { branch 'master'} }
 					steps{
 						sh """

 								response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-model-output-pareto" --profile prod`

 						"""
 					}
 			}

			stage('Execute safety-stock script for master') {
				when { anyOf { branch 'master'} }
				  steps{
				    sh """

				      /data/venvs/prod-df/bin/python3 ./scripts/safety-stock.py $env.GIT_BRANCH

				    """
				  }
			}

			stage('Execute a2i-df-safety_stock_demand for master') {
				when { anyOf { branch 'master'} }
					steps{
						sh """

								response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-safety_stock_demand" --profile prod`

						"""
					}
			}

			stage('Perform cleanup for master') {
				when { anyOf { branch 'master'} }
					steps{
						sh """
							 echo "For now I am not cleaning virtual environment"
							#sudo rm -rf /var/lib/jenkins/workspace/production-df-init_master/prod-df

						"""
					}
			}

			stage('Prepare code and environment for developer and qa') {
				when { anyOf { branch 'developer' ; branch 'qa' } }
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

			stage('Execute aws-dataset-input script for developer') {
				when { anyOf { branch 'developer' ; branch 'qa' } }
				  steps{
				    sh """

				       /data/venvs/stage-df/bin/python3 ./scripts/aws_dataset_input.py $env.GIT_BRANCH

				    """
				  }
			}

			stage('Execute a2i-df-model-output-pareto for developer') {
				when { anyOf { branch 'developer' ; branch 'qa' } }
				 steps{
					 sh """

							 response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:403475184785:stateMachine:a2i-df-model-output-pareto" --profile stage`

					 """
				 }
		 }

			stage('Execute safety-stock script for developer') {
				when { anyOf { branch 'developer' ; branch 'qa' } }
				  steps{
				    sh """

				      /data/venvs/stage-df/bin/python3 ./scripts/safety-stock.py $env.GIT_BRANCH

				    """
				  }
			}

			stage('Execute a2i-df-safety_stock_demand for developer') {
				when { anyOf { branch 'master'} }
					steps{
						sh """

								response=`aws stepfunctions start-execution --state-machine-arn "arn:aws:states:eu-west-1:403475184785:stateMachine:a2i-df-safety_stock_demand" --profile stage`

						"""
					}
			}

			stage('Perform cleanup for stage') {
				when { not { branch 'master'} }
					steps{
						sh """
							echo "For now I am not cleaning virtual environment"
							#sudo rm -rf /var/lib/jenkins/workspace/stage-df-init_developer/stage-df

						"""
					}
			}

		}//stages

		post {
			failure {
					echo "Sending failed build alerts"
					sendFatalAlerts currentBuild.result
					script {
                    if (env.BRANCH_NAME == 'master') {
                        echo 'I only execute on the master branch'
                    } else {
                        echo 'I execute elsewhere'
                    }
                }
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
