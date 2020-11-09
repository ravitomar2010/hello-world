#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# soureProfile='stage'
# destProfile='prod'
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
  fromEmail=`aws ssm get-parameter --name /a2i/${destProfile}/ses/fromemail --profile ${destProfile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${destProfile}/ses/toAllList --profile ${destProfile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${destProfile}/ses/fromemail --profile ${destProfile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################


getListOfSFARN(){

  echo "Fetching list of step functions for $profile environment"
  aws stepfunctions list-state-machines --profile $profile --query stateMachines[*].stateMachineArn > tmpListOfSFARN.txt

}

checkEligibility(){

  

}

prepareMetadata(){
  echo "Gathering information for step function $functionToMigrate"
  functionARN=`echo "$listofsfinsource" | grep -e "$functionToMigrate" | cut -d ':' -f2- | cut -d "," -f1 | head -n 1`
  functionARN=`echo "$functionARN" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
  echo "$functionARN"
  # # functionDetails=`aws stepfunctions describe-state-machine --state-machine-arn $ARN --profile $soureProfile`
  definition=`aws stepfunctions describe-state-machine --state-machine-arn $functionARN --profile $soureProfile | grep '"definition":' | cut -d ':' -f2-`
  # # definition=$(echo $definition | sed 's/\\n//g' | sed 's/\\//g' | cut -c 2- | rev | cut -c 3- | rev)
  # # echo "$definition"
  definition=$(echo $definition | sed 's/\\n//g' | sed 's/\\t//g' | sed 's/\\//g' | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev)
  # # roleARN=`aws stepfunctions describe-state-machine --state-machine-arn $functionARN --profile $soureProfile | grep '"roleArn":' | cut -d ':' -f2- | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
  echo "$definition"
  # # echo "$definition" | python -m json.tool
  # # echo "$roleARN"

  if [[ $soureProfile == 'prod' ]]; then
      #sourceAccountID='530328198985'
      #destinationAccountID='403475184785'
      #echo "$definition" | python -m json.tool
      #sourceAccountID='403475184785'
      #destinationAccountID='530328198985'
      if [[ $isFollowsNewConventions == true ]]; then
        definition=$(echo $definition | sed 's/530328198985/403475184785/g' | sed 's/production-/developer-/g')
        definition=$(echo "$definition" | python -m json.tool)
      else
        definition=$(echo $definition | sed 's/530328198985/403475184785/g' | sed 's/axiom-telecom-/developer-/g')
        definition=$(echo "$definition" | python -m json.tool)
      fi
      # # roleARN=$(echo $roleARN | sed 's/403475184785/530328198985/g')
      roleARN='arn:aws:iam::403475184785:role/a2i-stage-sfn-role'
      functionARN=$(echo $functionARN | sed 's/530328198985/403475184785/g')
      # # echo "Function definition is "
      # # echo "$definition" | python -m json.tool
      # # echo "ARN is $roleARN"
  else
      #sourceAccountID='403475184785'
      #destinationAccountID='530328198985'
      if [[ $isFollowsNewConventions == true ]]; then
        definition=$(echo $definition | sed 's/403475184785/530328198985/g' | sed 's/developer-/production-/g')
        definition=$(echo "$definition" | python -m json.tool)
      else
        definition=$(echo $definition | sed 's/403475184785/530328198985/g' | sed 's/developer-/axiom-telecom-/g')
        definition=$(echo "$definition" | python -m json.tool)
      fi
      # # roleARN=$(echo $roleARN | sed 's/403475184785/530328198985/g')
      roleARN='arn:aws:iam::530328198985:role/a2i-prod-sfn-role'
      functionARN=$(echo $functionARN | sed 's/403475184785/530328198985/g')
      # # echo "Function definition is "
      # # echo "$definition" | python -m json.tool
      # # echo "ARN is $roleARN"
  fi
}

migrateFunctions(){
  listofsfindest=`aws stepfunctions list-state-machines --profile $destProfile`
  # # echo "Creating Step function $functionToMigrate"
  checkIfAlreadyExistsinDest=`echo $listofsfindest | grep $functionToMigrate | wc -l`

  echo -e "\n\n\n Final parameters are : "
  echo "Function I am migrating is $functionToMigrate"
  echo "functionARN is $functionARN"
  echo "roleARN is $roleARN"
  echo "Definition is $definition"

  if [[ $checkIfAlreadyExistsinDest -gt 0 ]]; then
        echo "Step Function already exists -- Updating the same"
        response=`aws stepfunctions update-state-machine --state-machine-arn $functionARN --definition "$definition" --role-arn $roleARN --profile $destProfile`
        sendStatusMail
    else
        echo "Creating step function -- As it doesnt exists"
        response=`aws stepfunctions create-state-machine --name $functionToMigrate --definition "$definition" --role-arn $roleARN --profile $destProfile`
        sendStatusMail
  fi

}

sendStatusMail(){

  getSSMParameters

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
  --message "Subject={Data= $destProfile | CI-CD | step-functions migration notification - $functionToMigrate ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br> This is to notify that new version of step function entitled as <b> $functionToMigrate </b> is migrated to production environment. <br> Please reach out to DevOps team in case of any issue or concerns. <br> Thanks and Regards <br> DevOps Team. ,Charset=utf8}}" \
  --profile $destProfile

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
# getListOfSFARN
checkEligibility
