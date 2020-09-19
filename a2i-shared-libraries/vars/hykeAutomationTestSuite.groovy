
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

			              echo "Preparing Virtual environment prod-hyke-testsuite"

			              python3 -m venv /data/venvs/prod-hyke-testsuite

			              echo "Activating Virtual environment prod-hyke-testsuite"

			              echo "Installing all dependencies in Virtual environment prod-hyke-testsuite"

			              sudo /data/venvs/prod-hyke-testsuite/bin/pip install -r ./requirements.txt

			            """
			        }
			}

			stage('Execute test suite for master') {
			  when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
			    steps{
			      sh """

			        /data/venvs/prod-hyke-testsuite/bin/python3 ./launch.py master

			      """
			    }
			 }

			 stage('Send test report for master') {
 			  when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
 			    steps{
 			      sh """

 			        /data/venvs/prod-hyke-testsuite/bin/python3 ./sendEmail.py prod

 			      """
 			    }
 			 }

			 stage('Cleanup of venv for master branch') {
			  when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
			    steps{
			      sh """
									echo "For now I am not deleting vitual environment"
									#sudo rm -rf /var/lib/jenkins/workspace/production-aws-forecast/prod-forecast

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

			        echo "Preparing Virtual environment stage-hyke-testsuite"

			        python3 -m venv /data/venvs/stage-hyke-testsuite

			        echo "Activating Virtual environment /data/venvs/stage-hyke-testsuite"

			        echo "Installing all dependencies in Virtual environment stage-hyke-testsuite"

			        sudo /data/venvs/stage-hyke-testsuite/bin/pip install -r ./requirements.txt

			        """
			  }
			}

			stage('Execute test suite for developer or qa branch') {
				when {
							anyOf {
									expression { env.GIT_BRANCH ==~ 'origin/developer' }
									expression { env.GIT_BRANCH ==~ 'origin/qa' }
								}
							}
				steps{
			      sh """

			         /data/venvs/stage-hyke-testsuite/bin/python3 launch.py developer

			      """
			    }
			}

			stage('Send test report for stage env') {
			when {
					anyOf {
							expression { env.GIT_BRANCH ==~ 'origin/developer' }
							expression { env.GIT_BRANCH ==~ 'origin/qa' }
						}
					}
				 steps{
					 sh """

						 /data/venvs/prod-hyke-testsuite/bin/python3 ./sendEmail.py stage

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
					 				echo "For now I am not deleting vitual environment"
								 #sudo rm -rf /var/lib/jenkins/workspace/stage-aws-forecast/stage-forecast

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