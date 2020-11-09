#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
# filename=tmpListOfEvents.txt
# status='Enable'
#functionsToDelete='A,B,C,D'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
  if [[ $profile == 'prod' ]]; then
      accountID='530328198985'
  else
      accountID='403475184785'
  fi
}

getSSMParameters(){
  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

deleteStateMachines(){
    echo "Deleting $functionToDelete"
    ARN='arn:aws:states:eu-west-1:'$accountID':stateMachine:'$functionToDelete

    echo "ARN to delete is $ARN"
    aws stepfunctions delete-state-machine --state-machine-arn $ARN --profile $profile
    echo "    $functionToDelete <br>" >> tmpFinalOP.txt
}

sendNotifications(){
  getSSMParameters
  echo 'Sending notification to team members'

      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=$devopsMailList" \
      --message "Subject={Data= $profile | Step-Function Deletion Notification - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
      --profile $profile

}


#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile

echo '' > tmpFinalOP.txt

echo 'I am preparing final output file'
echo '<pre>' > tmpFinalOP.txt
echo "Hi All <br><br>Please find below list of step-functions in $profile account which has been deleted due to inactivity." >> tmpFinalOP.txt
echo "<br>==========================================================" >> tmpFinalOP.txt

for functionToDelete in $(echo $functionsToDelete | sed "s/,/ /g")
do
    deleteStateMachines
done

echo "==========================================================" >> tmpFinalOP.txt
echo "<br>Please reach out to devops in case of any concerns <br>Regards<br>DevOps Team" >> tmpFinalOP.txt
echo '</pre>' >> tmpFinalOP.txt

sendNotifications

#############################
########## CleanUp ##########
#############################

rm -rf ./tmp*
