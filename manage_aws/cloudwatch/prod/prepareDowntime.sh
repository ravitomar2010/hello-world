#!/bin/bash


#######################################################################
########################### Global Variables ##########################
#######################################################################
filename=tmpListOfEvents.txt
# status='Enable'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

getSSMParameters(){
  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

listEvents(){

    echo 'Listing all active events'
    aws events list-rules --profile $profile --query 'Rules[?(ManagedBy!=`states.amazonaws.com` && State==`ENABLED`)]'.[Name][] | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ',' > tmpListOfEvents.txt

}

enableEvents(){

    echo 'Enabling all the disabled events'
    getSSMValue
    while read line; do
      if [[ $line == "" ]]; then ##if1
          echo "Skipping empty line"
      else
          echo "I am working on event $line"
          aws events enable-rule --name $line --profile $profile
      fi
    done < $filename
    sendNotifications
}

getSSMValue(){

      echo 'Getting ssm paramaters after disabling rules'
      aws ssm get-parameter --name /a2i/$profile/cloudwatch/events/disabledRules --profile $profile --query Parameter.Value --output text > tmpListOfEvents.txt
}

disableEvents(){

    echo 'Disabling all the enabled events'
    # aws events enable-rule --name
    while read line; do
      if [[ $line == "" ]]; then ##if1
          echo "Skipping empty line"
      else
          echo "I am working on event $line"
          aws events disable-rule --name $line --profile $profile
      fi
    done < $filename
    setSSMValue
    sendNotifications
}

setSSMValue(){

      echo 'Setting ssm paramaters after disabling rules'
      aws ssm put-parameter --name /a2i/$profile/cloudwatch/events/disabledRules --value "$(cat tmpListOfEvents.txt)" --type String --overwrite --profile $profile
}

sendNotifications(){
  getSSMParameters
  echo 'Sending notification to team members'

  if [[ $status == 'Enable' ]]; then
      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
      --message "Subject={Data= $profile | Downtime-Notification - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> This is to notify that all the cloudwatch events has been enabled after planned downtime in <b>$profile</b> environment. <br>The next execution will happend at scheduled interval.<br> Please validate all your concerned events in $profile environment.<br> Please reach out to DevOps team in case of any issue or concerns. <br><br> Thanks and Regards <br> DevOps Team. ,Charset=utf8}}" \
      --profile $profile
  else
      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
      --message "Subject={Data= $profile | Downtime-Notification - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br>This is to notify that all the cloudwatch events has been disabled as part of planned downtime in <b>$profile</b> environment. <br> We will keep you posted after downtime is completed - after enabling these rules.<br> Please reach out to DevOps team in case of any issue or concerns. <br><br> Thanks and Regards <br> DevOps Team. ,Charset=utf8}}" \
      --profile $profile
  fi


}


#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile

  if [[ $status == 'Enable' ]]; then
      enableEvents
  else
      listEvents
      disableEvents
  fi

#############################
########## CleanUp ##########
#############################

rm -rf ./tmp*
