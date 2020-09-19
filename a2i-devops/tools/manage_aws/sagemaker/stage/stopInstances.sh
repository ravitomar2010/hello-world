#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# profile='prod'
# sourceAccountID=''
# destinationAccountID=''
# functionARNToDelete=''
#functionToMigrate=$1


#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

setInfraParameters(){
  if [[ $soureProfile == 'prod' ]]; then
    sourceAccountID='530328198985'
    destinationAccountID='403475184785'
    profile='prod'
  else
    sourceAccountID='403475184785'
    destinationAccountID='530328198985'
    profile='stage'
  fi
  # echo "Source account id is set to $sourceAccountID and destination is $destinationAccountID"

}

checkIfSFExistsInSource(){
    listofsfinsource=`aws stepfunctions list-state-machines --profile $soureProfile`

    checkIfAlreadyExistsinSource=`echo $listofsfinsource | grep $functionToMigrate | wc -l`
    # # echo "checkIfAlreadyExistsinDest is $checkIfAlreadyExistsinDest"
    if [[ $checkIfAlreadyExistsinSource -eq 0 ]]; then
          echo "The specified function does not exists in source"
          exit 1
    fi
}

checkIfArgumentsAreNull(){

  if [[ $functionToMigrate == '' ]]; then
    echo "No function name specified. Exiting...!!"
    exit 1
  fi

}


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
checkEligibility(){

  echo "Checking eligibility for sagamaker instances"
  instances=$(aws sagemaker list-notebook-instances --profile prod --query 'NotebookInstances[?NotebookInstanceStatus==`InService`].[NotebookInstanceName][]' | tr -d ']' | tr -d '[' | tr -d '"' | tr -d ',' )
  if [[ $instances == '' ]]; then
    #statements
    echo "No valid instances found"
    exit 0;
  fi
}

getListOfActiveNotebookInstances(){

  echo "Fetching list of active sagemaker instanes for $profile environment"
  instances=$(aws sagemaker list-notebook-instances --profile prod --query 'NotebookInstances[?NotebookInstanceStatus==`InService`].[NotebookInstanceName][]' | tr -d ']' | tr -d '[' | tr -d '"' | tr -d ',' )
  echo "I found following instances $instances"

}

sendWarningMail(){

  getSSMParameters

  echo "I am preparing warning mail"
  echo '<pre>' > tmpWarningOP.txt
  echo 'Hi All\, <br>This is to notify that the following <x style=color:Red;>sagemaker notebook instaces will be stopped in next 15 minutes </x> as part of daily scheduled task.' >> tmpWarningOP.txt
  echo '' >> tmpWarningOP.txt
  echo '##############################' >> tmpWarningOP.txt
  echo "$instances" >> tmpWarningOP.txt
  echo '' >> tmpWarningOP.txt
  echo '##############################' >> tmpWarningOP.txt
  echo '' >> tmpWarningOP.txt
  echo 'Please reach out to DevOps team in case of any issue or concerns.' >> tmpWarningOP.txt
  echo 'Thanks and Regards\,' >> tmpWarningOP.txt
  echo 'DevOps Team.' >> tmpWarningOP.txt
  echo '</pre>' >> tmpWarningOP.txt

  # echo 'I am sending mail'
  # aws ses send-email \
  # --from "a2isupport@axiomtelecom.com" \
  # --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
  # --message "Subject={Data= $profile | Sagemaker | notebook instances stop notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpWarningOP.txt),Charset=utf8}}" \
  # --profile $profile

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
  --message "Subject={Data= $profile | Sagemaker | notebook instances stop notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpWarningOP.txt),Charset=utf8}}" \
  --profile $profile

}

sendStatusMail(){

  getSSMParameters

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=$devopsMailList" \
  --message "Subject={Data= $profile | Sagemaker | notebook instances stop notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All\,<br><br>This is to notify that active sagemaker notebook instance are stopped for $profile environment.<br>Thanks and Regards\, <br> DevOps Team. ,Charset=utf8}}" \
  --profile $profile

}

shutdownInstances(){

  for instance in $(echo $instances | sed "s/,/ /g")
  do
      echo "I am shutting down $instance"
      aws sagemaker stop-notebook-instance --notebook-instance-name $instance --profile $profile
  done
}
#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
checkEligibility
getListOfActiveNotebookInstances
sendWarningMail
echo "I will wait for 15 minutes before shutting down instances"
sleep 900
echo "I am shutting down instance"
shutdownInstances
sendStatusMail

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
