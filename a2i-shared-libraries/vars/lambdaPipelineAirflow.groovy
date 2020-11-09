
def call() {
	pipeline {
		agent any
		environment {
			ORG = utility.getOrgName()
			APP_NAME = utility.getAppName()
			GIT_CRED_ID = 'a2i_Git_repo'
			LAYER_PROD = 'arn:aws:lambda:eu-west-1:530328198985:layer:a2i-lambda-layer:20'
			LAYER_STAGE = 'arn:aws:lambda:eu-west-1:403475184785:layer:a2i-lambda-layer:11'
			MEMORY = '512'
			ROLE_PROD = 'arn:aws:iam::530328198985:role/lambda-s3-vpc'
			ROLE_STAGE = 'arn:aws:iam::403475184785:role/lambda-s3-vpc'
			TIMEOUT = '900'
		}
		stages {
			stage('Create and Update Lambda function if master branch') {
			    when { branch 'master' }
			    steps {
			      sh """
                    ####################################################### VARIABLE DECLARATION #############################################

                    repo=${APP_NAME}
                    branch=${branch}
                    connection_module="connection"
                    echo "Deploying repo ${repo} on branch ${branch}"

                    ####################################################### SETTING SESSION VARIABLE #############################################

                    #if branch is production then profile is prod else stage
                    if [ ${branch} == "master" ]
                    then
                        session="session = boto3.Session(profile_name='prod',region_name='eu-west-1')"
                    else
                        session="session = boto3.Session(profile_name='stage',region_name='eu-west-1')"
                    fi

                    ####################################################### GIT CLONE REPO #############################################

                    cloneRepo(){
                        if [ ! -d virtualEnv ]; then mkdir virtualEnv; fi
                        
                        if [ -d virtualEnv/${repo} ]
                        then
                            echo "Repo ${repo} already exists. Deleting!"
                            sudo rm -rf virtualEnv/${repo}
                            echo "virtualEnv/${repo} deleted."
                        fi
                        echo "Cloning repo: ${repo} in virtualEnv"
                        pwd
                        git clone git@github.com:axiom-telecom/${repo}.git virtualEnv/${repo}/
                        
                    }

                    ####################################################### REPLACING CLIENT WITH SESSION #############################################

                    replaceClientWithSession(){
                        file=$1
                        #replace boto3.resource with session.resource
                        sed -i 's/boto3.resource/session.resource/g' ${file}

                        #replace boto3.client with session.client
                        sed -i 's/boto3.client/session.client/g' ${file}

                        #removing the line 'session = boto3.Session()'
                        session_line=$(cat ${file} | grep 'boto3.Session()')
                        if [ ${#session_line} -ne 0 ]; then  sed -i "s/${session_line}//g" ${file}; fi
                    }

                    ####################################################### CREATING SESSION FOR PROFILE #############################################

                    addSession(){
                        file=$1
                        #grep import lines
                        import_lines=$(cat ${file} | grep ^'import ')
                        last_import_line=$(echo "${import_lines}" | tail -1)

                        #if file contains import boto3 line then create session for the profile
                        if [[ ${import_lines} == *"import boto3"* ]]
                        then
                            replace_with=$"${last_import_line}\n\n${session}"
                            sed -i "s/${last_import_line}/$replace_with/g" ${file}
                        fi
                    }

                    ####################################################### UPDATING BRANCH NAME #############################################

                    updateBranchName(){
                        file=$1
                        #Changing branch name
                        replace_with="'${branch}'"
                        sed -i "s|os.environ\['environment'\]|${replace_with}|g" ${file}
                    }

                    ####################################################### ADD CONNECTION MODULE #############################################
                        
                    addConnectionModule(){
                        conn=$(cat $lambda/${lambda_name}.py | grep 'connection.redshift')

                        # add connection module to the lambda if connection.redshift string found in lambda handler
                        if [ ${#conn} -ne 0 ]
                        then
                            echo -e "\nAdding connection module in ${lambda}"
                            cp -r ${connection_module} ${lambda}

                            replaceClientWithSession ${lambda}/connection/redshift.py
                            addSession ${lambda}/connection/redshift.py
                            updateBranchName ${lambda}/connection/redshift.py
                        fi
                    }

                    ####################################################### APPENDING LAMBDA HANDLER CALL #############################################

                    appendLambdaHandlerCall(){

                        # lambda_name=$(echo "${lambda}" | rev | cut -d '/' -f1 |rev)
                        # method_def_line=$(cat $lambda/${lambda_name}.py | grep -m1 "^def.*(event.*context.*):" )
                        # method_call=$(echo "${method_def_line}" | awk '{print $2}' | cut -d '(' -f1 )
                        echo -e "\ns3tords(event=None,context=None)" >> ${lambda}/${lambda_name}.py
                    }

                    ####################################################### MAIN CODE #############################################

                    cloneRepo

                    ################### FOR EACH LAMBDA ###################
                    for lambda in "virtualEnv/${repo}/lambda"/*
                    do  
                        lambda_name=$(echo "$lambda" | rev | cut -d '/' -f1 |rev)
                        echo -e "\n--------- Executing for Lambda ${lambda_name} ---------\n"

                        ################### FOR EACH PYTHON FILE IN LAMBDA ###################
                        for file in "${lambda}"/*.py
                        do      
                            echo "Updating file ${file}"
                            replaceClientWithSession ${file}
                            addSession ${file}
                            updateBranchName ${file}
                                
                        done

                        appendLambdaHandlerCall
                        #Adding connection module
                        addConnectionModule
                    done
			      """
			    }
			 }//stage-master
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
		} // post
	}//pipeline
}
