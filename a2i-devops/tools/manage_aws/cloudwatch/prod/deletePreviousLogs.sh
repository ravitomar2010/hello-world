#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile=''

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

sendNotifications(){
    timeStamp=$(date '+%d-%m-%Y:%I-%M')
    prepareOutput
    getSSMParameters
    echo 'Sending email to concerned individuals'
    aws ses send-email \
    --from "$fromEmail" \
    --destination "ToAddresses=$devopsMailList" \
    --message "Subject={Data= $profile | Cloudwatch Logs Retention changed - ${timeStamp} ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
    --profile $profile
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

changeLogRetention(){

    logGroups=$(aws logs describe-log-groups --profile $profile --query logGroups[?retentionInDays!=\`90\`].logGroupName --output text)

    noOfLogsGroups=`echo $logGroups | wc -l | xargs`
    echo "Received $noOfLogsGroups log groups to apply changes"
    for logGroup in $logGroups
    do
            echo "Working on $logGroup now"
            result=`aws logs put-retention-policy --log-group-name $logGroup --retention-in-days 90 --profile $profile`
            if [[ $result -eq 0 ]]; then
                    echo "Retention policy of log group $logGroup has been set for 90 days"
                    # echo "$logGroup" >> successloggroup.txt
            else
                    echo "ERROR - Failed to set the retention policy for $logGroup"
                    # echo "$logGroup" >> unsuccessloggroup.txt
            fi
    done

}

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "<h3>Hi All\,<br><br>Cloudwatch retention period has been changed for $noOfLogsGroups log groups in $profile account." >> tmpFinalOP.txt
  echo "Please reach out to devops in case of any concerns. <br><br>Regards\,<br>DevOps Team</h3>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
changeLogRetention
getSSMParameters
sendNotifications


#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
