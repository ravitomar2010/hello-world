def call() {
	pipeline {
		agent any
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
		}
		stages {
			stage('Create code archives for master') {
				when { anyOf { branch 'master'} }
				steps{
					sh """
						ls -ltr
                        zip -r lambda-layer.zip . -x *.git*
					"""
				}
			}

			stage('Create and Update Lambda function for master branch') {
				when { anyOf { branch 'master'} }
				steps {
					sh """
							echo "Size of the compressed layer file is "
							du -sh ./lambda-layer.zip
					    aws lambda publish-layer-version --layer-name ${APP_NAME} --compatible-runtimes '["python3.6","python3.7"]' --zip-file fileb://lambda-layer.zip --region eu-west-1 --profile prod
					"""
				}
			}
			stage('Create code archives for developer') {
				when { anyOf { branch 'developer'} }
				steps{
					sh """
						ls -ltr
                        zip -r lambda-layer.zip . -x *.git*
					"""
				}
			}

			stage('Create and Update Lambda function for developer branch') {
				when { anyOf { branch 'developer'} }
				steps {
					sh """
					    aws lambda publish-layer-version --layer-name ${APP_NAME} --compatible-runtimes '["python3.6","python3.7"]' --zip-file fileb://lambda-layer.zip --region eu-west-1 --profile stage
					"""
				}
			}
		}
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
			}
		}
	}
}
