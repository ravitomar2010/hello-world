#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'
# env='stage'

#######################################################################
############################# Generic Code ############################
#######################################################################


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
  echo '' > tmpZeroExecutionSF.txt
  echo '' > tmp3HourExecutionSF.txt
  echo '' > tmp1DayExecutionSF.txt
  echo '' > tmp1WeekExecutionSF.txt
  echo '' > tmpOlderExecutionSF.txt

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
        #echo "Status is $status"
        parseExecutionStatus
    fi #if1
  done < $filename

}

parseExecutionStatus(){

    if [[ $result == '[]' ]]; then
      echo "I found 0 executions for $ARN"
      # echo "$Name" >> tmpZeroExecutionSF.txt
      echo -e "<tr> <td>$Name</td> <td> ---- </td> </tr>" >> tmpZeroExecutionSF.txt

    else
      echo "I have received executions for $Name ; parsing it"
      status=`echo $result | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2`
      time=`echo $result | tr -d ']' | tr -d '[' | cut -d ',' -f2 | cut -d '.' -f1`
      echo "Received status is $status and execution time is $time"
      now=`date +%s`
      diff=$((${now}-${time}))
      echo "Diff is $diff"
        if [[ $diff -lt 10800 ]]; then
            echo " $Name is executed in last 3 hours"
            if [[ $status == 'FAILED' ]]; then
                echo -e "<tr> <td>$Name</td> <td><b style=color:Red;>$status</b></td> </tr>" >> tmp3HourExecutionSF.txt
                # echo -e "  $Name - <b style=color:Red;>$status</b> " >> tmp3HourExecutionSF.txt
            else
                echo -e "<tr> <td>$Name</td> <td>$status</td> </tr>" >> tmp3HourExecutionSF.txt
            fi

        elif [[ $diff -lt 86400 ]]; then
            echo "$Name is executed in last 24 hours"
            if [[ $status == 'FAILED' ]]; then
                echo -e "<tr> <td>$Name</td> <td><b style=color:Red;>$status</b></td> </tr>" >> tmp1DayExecutionSF.txt
                # echo -e "  $Name - <b style=color:Red;>$status</b> " >> tmp1DayExecutionSF.txt
            else
              echo -e "<tr> <td>$Name</td> <td>$status</td> </tr>" >> tmp1DayExecutionSF.txt
            fi
        elif [[ $diff -lt 604800 ]]; then
            echo "$Name is executed in last 1 week"
            if [[ $status == 'FAILED' ]]; then
                echo -e "<tr> <td>$Name</td> <td><b style=color:Red;>$status</b></td> </tr>" >> tmp1WeekExecutionSF.txt
                # echo -e "  $Name - <b style=color:Red;>$status</b> " >> tmp1WeekExecutionSF.txt
            else
                echo -e "<tr> <td>$Name</td> <td>$status</td> </tr>" >> tmp1WeekExecutionSF.txt
            fi
        else
            echo "$Name is not executed since last 1 week"
            lastExecutionTime=`date -d @"$time" +%d/%m/%Y`
            echo -e "<tr> <td>$Name</td> <td>$status - last executed on $lastExecutionTime</td> </tr>" >> tmpOlderExecutionSF.txt
            # echo -e "  $Name - $status - last executed on $lastExecutionTime " >> tmpOlderExecutionSF.txt
        fi
    fi

}

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "<h3>Hi All <br><br> Please find below status report for step-functions in $profile account</h3>" >> tmpFinalOP.txt
  echo '<table>' >> tmpFinalOP.txt
  # echo '<tr> <th style=font-size:20px;text-align:left;>Function</th> <th style=font-size:20px;text-align:left;>Status</th> </tr>' >> tmpFinalOP.txt
  # echo "<br>==========================================================" >> tmpFinalOP.txt
  # echo "<br><b>List of step-functions executed in last 3 hours </b><br>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of step-functions executed in last 3 hours </b></td></tr>" >> tmpFinalOP.txt

    # noOfLines=`cat tmp3HourExecutionSF.txt | wc -l`
    # if [[ $noOfLines -gt 1 ]]; then
          cat tmp3HourExecutionSF.txt >> tmpFinalOP.txt
    #       echo "==========================================================" >> tmpFinalOP.txt
    # else
    #       echo '---------------------------------------' >> tmpFinalOP.txt
    #       echo "<br>==========================================================" >> tmpFinalOP.txt
    # fi
  echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of step-functions executed in last 24 hours</b> </td></tr>" >> tmpFinalOP.txt

  # echo "<br><b>List of step-functions executed in last 24 hours</b> <br>" >> tmpFinalOP.txt
  #   noOfLines=`cat tmp1DayExecutionSF.txt | wc -l`
  #   if [[ $noOfLines -gt 1 ]]; then
          cat tmp1DayExecutionSF.txt >> tmpFinalOP.txt
  #         echo "==========================================================" >> tmpFinalOP.txt
  #   else
  #         echo '---------------------------------------' >> tmpFinalOP.txt
  #         echo "<br>==========================================================" >> tmpFinalOP.txt
  #   fi

  echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of step-functions executed in last 1 week </b> </td></tr>" >> tmpFinalOP.txt

  # echo "<br><b>List of step-functions executed in last 1 week </b><br>" >> tmpFinalOP.txt
  #   noOfLines=`cat tmp1WeekExecutionSF.txt | wc -l`
  #   if [[ $noOfLines -gt 1 ]]; then
          cat tmp1WeekExecutionSF.txt >> tmpFinalOP.txt
  #         echo "==========================================================" >> tmpFinalOP.txt
  #
  #   else
  #         echo '---------------------------------------' >> tmpFinalOP.txt
  #         echo "<br>==========================================================" >> tmpFinalOP.txt
  #
  #   fi
  echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of step-functions not executed in last 1 week </b> </td></tr>" >> tmpFinalOP.txt
  # echo "<br><b>List of step-functions not executed in last 1 week </b><br>" >> tmpFinalOP.txt
  #   noOfLines=`cat tmpOlderExecutionSF.txt | wc -l`
  #   if [[ $noOfLines -gt 1 ]]; then
          cat tmpOlderExecutionSF.txt >> tmpFinalOP.txt
  #         echo "==========================================================" >> tmpFinalOP.txt
  #   else
  #         echo '---------------------------------------' >> tmpFinalOP.txt
  #         echo "<br>==========================================================" >> tmpFinalOP.txt
  #   fi

  echo "<tr><td colspan=2><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt
  echo "<tr><td colspan=2><b style=font-size:15px;color:#339CFF;>List of step-functions which does not have any execution record </b> </td></tr>" >> tmpFinalOP.txt
  # echo "<br><b>List of step-functions which does not have any execution record </b><br>" >> tmpFinalOP.txt
  #   noOfLines=`cat tmpZeroExecutionSF.txt | wc -l`
  #   if [[ $noOfLines -gt 1 ]]; then
          cat tmpZeroExecutionSF.txt >> tmpFinalOP.txt
  #         echo "==========================================================" >> tmpFinalOP.txt
  #
  #   else
  #         echo '---------------------------------------' >> tmpFinalOP.txt
  #         echo "<br>==========================================================" >> tmpFinalOP.txt
  #   fi

  echo '</table>' >> tmpFinalOP.txt
  echo "<br><h3>Please reach out to devops in case of any concerns. <br>Regards<br>DevOps Team</h3>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

sendMail(){
    timeStamp=$(date '+%d-%m-%Y:%I-%M')
    getSSMParameters
    echo 'Sending email to concerned individuals'
    aws ses send-email \
    --from "$fromEmail" \
    --destination "ToAddresses=$toMail","CcAddresses=$devopsMailList" \
    --message "Subject={Data= $profile | step-functions execution report - ${timeStamp} ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
    --profile $profile
}

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

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
