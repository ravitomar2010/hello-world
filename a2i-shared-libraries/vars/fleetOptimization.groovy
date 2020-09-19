def call() {
pipeline
  {
		agent any

		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
		}

		stages {

				stage('Prepare virtual environment for master branch'){
							agent {
									node {
													label 'emr'
											  }
							}
							when { expression { env.GIT_BRANCH ==~ 'origin/master' } }

						  steps {
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
				stage('Execute training scripts for master branch ') {
					when { expression { env.GIT_BRANCH ==~ 'origin/master' } }
					  steps{
					    sh """

							echo 'run this stage - only if the branch = master branch'


					    """
					  }
				 }
		}





	}
}
