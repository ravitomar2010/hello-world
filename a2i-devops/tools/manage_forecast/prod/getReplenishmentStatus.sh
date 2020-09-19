#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'
retry=0;

########################## Test Parameters ############################
#
# profile='prod'
# location='UAE'
# SFName='a2i-df-system-replenishment'
# retry=0;

#######################################################################
############################# Generic Code ############################
#######################################################################


#######################################################################
######################### Feature Function Code #######################
#######################################################################

getListOfSFARN(){

  echo "Fetching list of step functions for $profile environment"
  # aws stepfunctions list-state-machines --profile $profile --query stateMachines[*].stateMachineArn > tmpListOfSFARN.txt
  # echo '"arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-system-replenishment",' > tmpListOfSFARN.txt
  # echo '"arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-system-replenishment-ksa"' >> tmpListOfSFARN.txt
  echo '"arn:aws:states:eu-west-1:530328198985:stateMachine:'$SFName'"' > tmpListOfSFARN.txt
}

getExecutionHistory(){

  echo 'Getting execution history of df step function'
  filename=tmpListOfSFARN.txt

  # echo 'Creating supporting files'
  # echo '' > tmp3HourExecutionSFSuccess.txt
  # echo '' > tmp3HourExecutionSFFailure.txt


  while read line; do
  	if [[ $line == "" || $line == "[" || $line == "]" ]]; then #if1
  	    echo "Skipping empty line"
    else
        # echo "Working on sf $line"
        ARN=`echo $line | cut -d '"' -f2`
        Name=`echo $line | rev | cut -d ':' -f1 | rev | cut -d '"' -f1`
        echo "ARN to work on is $ARN"
        echo "Name of SF is $Name"
        waitCount=0;
        while [[ $waitCount -le 4 ]]; do
            #statements
            result=`aws stepfunctions list-executions --state-machine-arn ${ARN} --profile ${profile} --max-items 1 --query executions[*].[status,startDate][]`
            executionARN=`aws stepfunctions list-executions --state-machine-arn ${ARN} --profile ${profile} --max-items 1 --query executions[*].[executionArn][]`
            echo "Status is $result"
            echo "executionARN is $executionARN"
            parseExecutionStatus
        done
    fi #if1
  done < $filename

}

getFailureReason(){

    echo "Trying to extract failure reason for $Name"
    failureReason=`aws stepfunctions get-execution-history --execution-arn $executionARN --profile $profile --max-items 1 --reverse-order --query events[*].executionFailedEventDetails.cause --output text | sed 's/[^a-z  A-Z 0-9 :/\.-_]//g' | tr -d '[]' | head -n -1`
    #failureReason=`echo $failureReason | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2`
    echo "Failure reason for $Name is $failureReason"
}

parseExecutionStatus(){

    if [[ $result == '[]' ]]; then
        echo "I found 0 executions for $ARN"
        echo "$Name<br>" >> tmpZeroExecutionSF.txt
    else
        echo "I have received executions for $Name ; parsing it"
        status=`echo $result | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2`
        executionTime=`echo $result | tr -d ']' | tr -d '[' | cut -d ',' -f2 | cut -d '.' -f1`
        executionARN=`echo $executionARN | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2 `
        echo "Received status is $status , execution time is $executionTime and executionARN is $executionARN"

        if [[ $status == 'FAILED' && $retry -gt 0 ]]; then
           echo 'Step function is failed and retried once'
           prepareOutputFailed
           waitCount=10;
        elif [[ $status == 'FAILED' ]]; then
             echo 'Step function is failed and retrying once'
             retryCoreExecution
             waitCount=10;
        elif [[ $status == 'SUCCEEDED' ]]; then
             prepareOutputSuccess
             waitCount=10;
        elif [[ $waitCount -gt 2 ]]; then
            echo 'I found timeout while monitoring'
            prepareOutputFailed
            waitCount=10;
        else
              echo "I am waiting for execution status"
              waitCount=$(( waitCount + 1 ))
              echo "waitCount is $waitCount"
              echo 'I am sleeping for 15 minutes'
              sleep 900;
        fi
    fi

}

retryCoreExecution(){
  nextSFName=''
  if [[ location=='KSA' ]]; then
      nextSFNameARN='arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-ksa-replenishment'
      echo '"arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-ksa-replenishment"' > tmpListOfSFARN.txt
  else
      nextSFNameARN='arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-replenishment'
      echo '"arn:aws:states:eu-west-1:530328198985:stateMachine:a2i-df-replenishment"' > tmpListOfSFARN.txt
  fi

  echo "Executing the replenishment step function ${nextSFNameARN}"
  aws stepfunctions start-execution --state-machine-arn ${nextSFNameARN} --profile $profile
  retry=10;
  sleep 900;

  getExecutionHistory

}

prepareOutputFailed(){

  failureTimeStamp=`date -d @${executionTime} '+%d-%m-%Y'`
  # echo "Failure time stamp is $successTimeStamp and received time is $executionTime"

  echo 'I am preparing final output file in case of failed SF'
  echo '<pre>' > tmpFinalOP.txt
  echo "<p style=font-size:18px;>Hi All\, <br><br>This is to notify you all that replenishment for<b style=color:Red;> $location has FAILED</b> for ${failureTimeStamp}." >> tmpFinalOP.txt

  # echo "<br>==========================================================" >> tmpFinalOP.txt
  # echo "<br><b>List of step-functions executed in last 3 hours </b><br>" >> tmpFinalOP.txt
  # cat tmp3HourExecutionSFFailure.txt >> tmpFinalOP.txt
  # echo "==========================================================" >> tmpFinalOP.txt

  echo "<br>Please reach out to DevOps in case of any concerns. <br>Regards\,<br>DevOps Team</p>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

  echo 'Preparing subject line'
  subject="Critical-Alert | Replenishment status | $location | FAILED | $(date +%d-%b-%Y)"
  echo "Final subject is $subject"
}

prepareOutputSuccess(){

  successTimeStamp=$(date -d @${executionTime} '+%d-%m-%Y')
  # echo "Success time stamp is $successTimeStamp and received time is $executionTime"
  echo 'I am preparing final output file in case of success SF'
  echo '<pre>' > tmpFinalOP.txt
  echo "<p style=font-size:18px;>Hi All\, <br><br>This is to notify you all that replenishment for<b style=color:Blue;> $location is successful</b> for ${successTimeStamp}." >> tmpFinalOP.txt

  # echo "<br>==========================================================" >> tmpFinalOP.txt
  # echo "<br><b>List of step-functions executed in last 3 hours </b><br>" >> tmpFinalOP.txt
  # cat tmp3HourExecutionSFFailure.txt >> tmpFinalOP.txt
  # echo "==========================================================" >> tmpFinalOP.txt

  echo "<br>Please reach out to DevOps in case of any concerns. <br>Regards\,<br>DevOps Team</p>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

  echo 'Preparing subject line'
  subject="Replenishment status | $location | Success | $(date +%d-%b-%Y)"
  echo "Final subject is $subject"
}

sendMail(){

  getSSMParameters
  timeStamp=`date -d @${executionTime} '+%d-%m-%Y:%I-%M'`
  echo 'Sending email to concerned individuals'
  # aws ses send-email \
  # --from "$fromEmail" \
  # --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
  # --message "Subject={Data= ${subject} ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
  # --profile $profile

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data= ${subject} ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
  --profile $profile

}

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getListOfSFARN
getExecutionHistory
sendMail

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
# rm -rf ./tmp*