#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'
##client='axiom'
filename='tmpLambdaListNames.txt'
workingLambdaName=''

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
  # aws lambda list-functions --profile $profile | grep '"FunctionName":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListNames.txt
  aws lambda list-functions --query Functions[*].FunctionName --profile $profile > tmpLambdaListNames.txt
  #aws lambda list-functions --max-items 1 --profile $profile | grep '"FunctionName":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListNames.txt
  #aws lambda list-functions --max-items 2 --function-version ALL --profile $profile | grep '"FunctionArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListARNs.txt
}

getDeleteEligibleFunctionARNs(){

  aws lambda list-versions-by-function --function-name $workingLambdaName --profile $profile | grep '"FunctionArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListARNs.txt
  tail -n +2 tmpLambdaListARNs.txt > tmpLambdaListARNs-1.txt
  sed '$d' tmpLambdaListARNs-1.txt | sed '$d' |  sed '$d' > tmpLambdaEligibleToDel.txt
}

listAndDeleteLambdas(){
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "I am working on lambda $line"
        workingLambdaName=$line
        getDeleteEligibleFunctionARNs
        deleteLambdaPreviousVersions
        #aws lambda delete-function --function-name $line --profile $profile
    fi
    done < $filename

}

deleteLambdaPreviousVersions(){
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "I am deleting lambda version $line"
        aws lambda delete-function --function-name $line --profile $profile
    fi
    done < tmpLambdaEligibleToDel.txt
}

getStatusHistory(){

    echo 'I am getting history for each lambda'
    echo 'Creating supporting files'
    echo '' > tmpOlderLambdaList.txt
    echo '' > tmpZeroExecutionLambdaList.txt
    filename='tmpLambdaListNames.txt'
    while read line; do
    	if [[ $line == "" || $line == "[" || $line == "]" ]]; then #if1
    	    echo "Skipping empty line"
      else
          # echo "Working on sf $line"
          Name=`echo $line | cut -d '"' -f2`
          # Name=`echo $line | rev | cut -d ':' -f1 | rev | cut -d '"' -f1`
          # echo "ARN to work on is $ARN"
          echo "Name of Lambda is $Name"
          #result=`aws stepfunctions list-executions --state-machine-arn ${ARN} --profile ${profile} --max-items 1 --query executions[*].[status,startDate][]`
          #echo "Status is $status"
          #parseExecutionStatus
          lastEventTimeStamp=`aws logs describe-log-streams --log-group-name /aws/lambda/$Name --profile $profile --query logStreams[*].lastEventTimestamp | tr -d '[' | tr -d ']' | sort -r | head -n 1 | tr -d ' ' | tr -d ',' | cut -c 1-10`
          echo "lastEventTimestamp is $lastEventTimeStamp"
          currentTimeStamp=`date +%s`
          diff=$(( currentTimeStamp - lastEventTimeStamp ))
          echo "Difference is $diff"

          if [[ $lastEventTimeStamp == '' ]]; then
              echo "$Name is not having any execution record."
              # echo "$Name " >> tmpZeroExecutionLambdaList.txt
              echo -e "<tr> <td>$Name</td> <td><b>-</b></td> </tr>" >> tmpZeroExecutionLambdaList.txt

          elif [[ $diff -gt 7780000 ]]; then
              echo "$Name is older than 90 days and is eligible to delete."
              executionTime=`date -d @${lastEventTimeStamp} +%d-%b-%Y`
              # echo "$Name $executionTime " >> tmpOlderLambdaList.txt
              echo -e "<tr> <td>$Name</td> <td><b style=color:Red;>$executionTime</b></td> </tr>" >> tmpOlderLambdaList.txt

          else
              executionTime=`date -d @${lastEventTimeStamp} +%d-%b-%Y--%r`
              echo "$Name is having recent execution ($executionTime) hence ignoring for deletion."
          fi
      fi #if1
    done < $filename

}

sendNotification(){

    echo 'Sending notification to conerned individuals'

    echo 'Preparing output'
    prepareOutput

    echo 'Sending mail'
    getSSMParameters

    aws ses send-email \
    --from "a2isupport@axiomtelecom.com" \
    --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList,$devopsMailList,anuj.kaushik@axiomtelecom.com" \
    --message "Subject={Data= $profile | Junk-Unused Lambdas ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
    --profile $profile

    # aws ses send-email \
    # --from "a2isupport@axiomtelecom.com" \
    # --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
    # --message "Subject={Data= $profile | Junk-Unused Lambdas ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
    # --profile $profile

}

prepareOutput(){

    echo '<pre>' > tmpFinalOP.txt
    # echo "<p style=font-size=15px;>Hi All\, <br>Please find below list of lambdas which are older/ junk/ unused in $profile account.</p>" >> tmpFinalOP.txt
    echo "<h3>Hi All\, <br><br>Please find below list of lambdas which are older/ junk/ unused in $profile account.</h3>" >> tmpFinalOP.txt
    echo '<table>' >> tmpFinalOP.txt
    echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
    echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of lambdas not executed in last 90 days </b></td></tr>" >> tmpFinalOP.txt
    echo "<tr><td colspan=2><b style=font-size:15px;color:black;>Function-Name</b></td><td><b style=font-size:15px;color:black;text-align:left;>Last executed on</b></td></tr>" >> tmpFinalOP.txt
    cat tmpOlderLambdaList.txt >> tmpFinalOP.txt
    echo '<tr><td>-------------+++++++++++----------</td><td>++++++++++-----------++++++++++</td></tr>' >> tmpFinalOP.txt
    echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of lambdas which dont have any execution record </b></td></tr>" >> tmpFinalOP.txt
    cat tmpZeroExecutionLambdaList.txt >> tmpFinalOP.txt
    echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
    echo "</table><br><h3>Please delete these lambdas from respective repository and let us know so we can delete this from env also." >> tmpFinalOP.txt
    echo "Please reach out to devops in case of any concerns. <br>Regards\,<br>DevOps Team</h3>" >> tmpFinalOP.txt
    echo '</pre>' >> tmpFinalOP.txt
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getListOfLambdas
getStatusHistory
sendNotification

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
