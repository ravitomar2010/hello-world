#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename='tmpLambdaListNames.txt'
workingLambdaName=''
profile=${env}

################################ Test Parameters ######################
#
# profile='prod'
# filename='tmpLambdaListNames.txt'
# workingLambdaName=''
# prefix='axiom-telecom'

#######################################################################
############################# Generic Code ############################
#######################################################################

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
	devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

getListOfLambdas(){
  echo "Fetching list of lambdas for $profile"
  aws lambda list-functions --profile $profile --query "Functions[?starts_with(FunctionName,'"${prefix}"') ].FunctionName" > tmpLambdaListNames.txt
}

listAndDeleteLambdas(){
  while read line; do
  	if [[ $line == "" || $line == '[' || $line == ']' || $line == '[]' ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "I am working on lambda $line"
        workingLambdaName=$(echo $line | tr -d '"')
        aws lambda delete-function --function-name ${workingLambdaName} --profile ${profile}
    fi
    done < $filename

}

sendNotifications(){
  getSSMParameters

  aws ses send-email \
  --from "a2isupport@axiomtelecom.com" \
  --destination "ToAddresses=$devopsMailList","CcAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data=${env} | A2i Lambda Deletion Notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All\,<br><br>This is to notify you all that lambdas with prefix ${prefix} has been deleted from ${env} environment by ${BUILD_USER}.<br>Please reach out to devops in case of any issues.<br><br>Thanks and Regards\,<br>DevOps Team,Charset=utf8}}" \
  --profile prod
}


#######################################################################
############################# Main Function ###########################
#######################################################################

getListOfLambdas
listAndDeleteLambdas
sendNotifications

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
# rm -rf ./tmp*
