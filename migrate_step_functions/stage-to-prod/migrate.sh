#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# soureProfile='stage'
# destProfile='prod'
sourceAccountID=''
destinationAccountID=''
functionARNToDelete=''
#functionToMigrate=$1


#######################################################################
############################# Generic Code ############################
#######################################################################

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

restructureDefinition(){
  #states_head=$(echo $definition | jq . | grep -n -m1 States | cut -d ':' -f1)
  #echo "$definition" | head -$states_head > newDef.json
  echo "restructuring definition"
  newDefinition="\"States\": {"
  start_at=$(echo $definition | jq -r '.StartAt')
  next=$start_at
  while [ $next != null ]
  do
    state=".States.$next"
    state=$(echo $definition | jq -r $state)
    newDefinition+=$(echo "\"$next\": $state,")
    next=$(echo $state | jq -r '.Next')
  done
    newDefinition=$(echo $newDefinition | sed '$ s/,$/}/' | sed 's|&|\\&|g')
    replace="\"States\": \"new_value\""
    newDefinition=$(echo $definition | jq '.States="new_value"' | sed "s|$replace|$newDefinition|g")
    definition=$(echo "$newDefinition" | jq .)
    echo "New Definition post restructuring is: $definition"
}


checkStepFunction(){
  # definition=$1
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

executeFunctionAndGetDefinition(){
    # definition=$1
    echo "Appending Retry"
    start_at=$(echo $definition | jq -r '.StartAt')
    next=$start_at
    echo $next

    while [ $next != null ]
    do
        #Fetching State from definition
        #state=$(echo $definition | jq -r $state)
        state=".States.$next"
        state=$(echo $definition | jq -r $state)
        #Fetching next from state
        next=$(echo $state | jq -r '.Next')
        #Fetching Resource from state
        resource=$(echo $state | jq -r '.Resource')

        #Appending retry if resource contains lambda
        if [[ $resource == "arn:aws:lambda"* ]] || [[ $resource == "arn:aws:states"* ]]
        then
                replace="$resource\","
                replace_with="$resource\",\"Retry\": [{\"BackoffRate\" : 2, \"ErrorEquals\": [\"States.ALL\"],\"IntervalSeconds\": 60,\"MaxAttempts\": 2}],"
                definition=$(echo $definition | sed "s/${replace}/${replace_with}/g")
        fi
    done

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
      definition=$(echo $definition | sed 's/530328198985/403475184785/g' | sed 's/production-/developer-/g')
      definition=$(echo "$definition" | jq '.')
      # # roleARN=$(echo $roleARN | sed 's/403475184785/530328198985/g')
      roleARN='arn:aws:iam::403475184785:role/a2i-stage-sfn-role'
      functionARN=$(echo $functionARN | sed 's/530328198985/403475184785/g')
      # # echo "Function definition is "
      # # echo "$definition" | python -m json.tool
      # # echo "ARN is $roleARN"
  else
      #sourceAccountID='403475184785'
      #destinationAccountID='530328198985'
      definition=$(echo $definition | sed 's/403475184785/530328198985/g' | sed 's/developer-/production-/g')
      definition=$(echo "$definition" | jq '.')
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
  checkIfAlreadyExistsinDest=`echo $listofsfindest | grep -w -i $functionToMigrate | wc -l`

  echo -e "\n\n\n Final parameters are : "
  echo "Function I am migrating is $functionToMigrate"
  echo "functionARN is $functionARN"
  echo "roleARN is $roleARN"
  echo "Current Definition is: $definition"
  restructureDefinition
  if [[ $isFollowRetry == true ]]; then
    executeFunctionAndGetDefinition
    definition=$(echo "$definition" | jq '.')
    echo "definition for retry is $definition"
  fi
  checkStepFunction
}

sendStatusMail(){

  getSSMParameters

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
  --message "Subject={Data= $destProfile | CI-CD | step-functions migration notification - $functionToMigrate ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p>Hi All <br><br>This is to notify that new version of step function entitled as <b> $functionToMigrate </b> is migrated to <b>production</b> environment.</p><p>Please reach out to DevOps team in case of any issue or concerns.<br><br>Thanks and Regards <br><b>DevOps Team</b></p> ,Charset=utf8}}" \
  --profile $destProfile

}

#######################################################################
############################# Main Function ###########################
#######################################################################

for functionToMigrate in $(echo $functionsToMigrate | sed "s/,/ /g")
do
  setInfraParameters
  checkIfArgumentsAreNull
  echo "Function to migrate is $functionToMigrate"
  checkIfSFExistsInSource
  prepareMetadata
  migrateFunctions
done
