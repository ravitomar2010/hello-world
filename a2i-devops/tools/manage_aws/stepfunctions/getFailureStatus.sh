#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'
# env='stage'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

getListOfSFARN(){

  echo "Fetching list of step functions for $profile environment"
  aws stepfunctions list-state-machines --profile $profile --query stateMachines[*].stateMachineArn > tmpListOfSFARN.txt

}

getExecutionHistory(){

  echo 'Getting execution history of each step function'
  filename=tmpListOfSFARN.txt

  echo 'Creating supporting files'
  echo '' > tmp3HourExecutionSFSuccess.txt
  echo '' > tmp3HourExecutionSFFailure.txt


  while read line; do
  	if [[ $line == "" || $line == "[" || $line == "]" ]]; then #if1
  	    echo "Skipping empty line"
    else
        # echo "Working on sf $line"
        ARN=`echo $line | cut -d '"' -f2`
        Name=`echo $line | rev | cut -d ':' -f1 | rev | cut -d '"' -f1`
        echo "ARN to work on is $ARN"
        echo "Name of SF is $Name"
        result=`aws stepfunctions list-executions --state-machine-arn ${ARN} --profile ${profile} --max-items 1 --query executions[*].[status,startDate][]`
        executionARN=`aws stepfunctions list-executions --state-machine-arn ${ARN} --profile ${profile} --max-items 1 --query executions[*].[executionArn][]`
        #echo "Status is $status"
        #echo "executionARN is $executionARN"
        parseExecutionStatus
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
      time=`echo $result | tr -d ']' | tr -d '[' | cut -d ',' -f2 | cut -d '.' -f1`
      executionARN=`echo $executionARN | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2 `
      echo "Received status is $status , execution time is $time and executionARN is $executionARN"
      now=`date +%s`
      timeToNotify=$(date -d @"$time")
      diff=$((${now}-${time}))
      echo "Diff is $diff"
      if [[ $status == 'FAILED' ]]; then
          if [[ $diff -lt 10800 ]]; then
              getFailureReason
              echo "<b style=color:Red;>$Name - $status - Failure time $timeToNotify</b>" >> tmp3HourExecutionSFFailure.txt
              echo "<br><b>The reason for failure is :</b>' $failureReason '<br>" >> tmp3HourExecutionSFFailure.txt
              #echo "----------------------------------------" >> tmp3HourExecutionSFFailure.txt

          fi
      else
          echo "$Name" >> tmp3HourExecutionSFSuccess.txt
      fi
    fi

}

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "Hi All <br><br> Please find below list of failed step-functions in last 3 hours in $profile environment" >> tmpFinalOP.txt

  echo "<br>==========================================================" >> tmpFinalOP.txt
  #echo "<br><b>List of step-functions executed in last 3 hours </b><br>" >> tmpFinalOP.txt
  cat tmp3HourExecutionSFFailure.txt >> tmpFinalOP.txt
  echo "==========================================================" >> tmpFinalOP.txt

  echo "<br> Please reach out to devops in case of any concerns <br>Regards<br>DevOps Team" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

sendMail(){


    noOfFailedSF=`cat tmp3HourExecutionSFFailure.txt | wc -l`

    if [[ $noOfFailedSF -gt 1 ]]; then
      getSSMParameters
      timeStamp=$(date '+%d-%m-%Y:%I-%M')
      echo 'Sending email to concerned individuals'
      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=yogesh.patil@axiomtelecom.com" \
      --message "Subject={Data= $profile | critical-alert | step-functions Failure notification - ${timeStamp} ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
      --profile $profile
    fi

}

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`

}
#######################################################################
############################# Main Function ###########################
#######################################################################


getListOfSFARN
getExecutionHistory
prepareOutput
sendMail

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
