#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
profile='stage'
filename=tmpValidUsers.txt
#######################################################################
############################# Generic Code ############################
#######################################################################


#######################################################################
######################### Feature Function Code #######################
#######################################################################

listUsers(){

  echo 'Creating supporting files'
  echo '' > tmpValidUsers.txt

  users=`aws iam list-users --profile $profile --query Users[*].UserName`
  users=`echo $users | tr -d ']' | tr -d '['`

  for user in $(echo $users | sed "s/,/ /g")
  do
      user=`echo $user | cut -d '"' -f2`
      if [[ $user =~ '@' ]]; then
          echo "User $user is human user"
          checkForAccessKeys
      else
          echo "User $user is service user - which can be ignored"
      fi
  done
}

checkForAccessKeys(){

  status=`aws iam list-access-keys --user-name $user --profile $profile --query AccessKeyMetadata[*].Status --output text`
  #echo "Status of access key for user $user is $status"

  if [[ $status == 'Active' ]]; then
      echo 'Since the status is active - moving it to valid list'
      echo "$user" >> tmpValidUsers.txt
  else
      echo "No Access key found for $user - ignoring this user"
  fi

}

mailStatus(){

  echo 'Fetching the current notification status'
  result=`aws ssm get-parameter --name /a2i/$profile/iam/users/accessKeyMailStatus --profile $profile  --query Parameter.Value --output text`
  notificationLevel=`echo $result | cut -d ':' -f1`
  notificationTime=`echo $result | cut -d ':' -f2`
  echo "The notification level is $notificationLevel and time is $notificationTime"
  now=`date +'%s'`
  echo "now is $now"
  diffTime=$((now-notificationTime))
  echo "diff is $diffTime"
  # DaysTime90=`date -d '-90 day' '+%s'`
  # echo "DaysTime90 is $DaysTime90"
  # echo "diff in 90 days and now is $((now-DaysTime90))"
  # DaysTime75=`date -d '-75 day' '+%s'`
  # echo "DaysTime75 is $DaysTime75"
  # echo "diff in 75 days and now is $((now-DaysTime75))"
  # DaysTime15=`date -d '-15 day' +'%s'`
  # echo "DaysTime15 is $DaysTime15"
  # echo "diff in 15 days and now is $((now-DaysTime15))"
  # DaysTime7=`date -d '-7 day' +'%s'`
  # echo "DaysTime7 is $DaysTime7"
  # echo "diff in 7 days and now is $((now-DaysTime7))"


   if [[ $notificationLevel =~ 'Third' ]]; then
         if [[ $diffTime -gt 7776000 ]]; then
              echo "The notification level is $notificationLevel and time diff is $diffTime"
              echo "This is the time to initiate the communication"
      	      echo 'Pulling the valid user list'
      		    listUsers
      	      sendFirstSessionMail
      	      echo 'Updating the status in SSM'
              aws ssm put-parameter --name /a2i/$profile/iam/users/accessKeyMailStatus --profile $profile --value "First : $now" --type String --overwrite
         else
              echo "The notification level is Third but diffrence is less than 90 days which is $diffTime seconds"
         fi
  elif [[ $notificationLevel =~ 'First' ]]; then
      	if [[ $diffTime -gt 258000 ]]; then
	            echo "The notification level is $notificationLevel and time diff is $diffTime"
              echo "This is the time to send remindere communication"
              echo 'Pulling the valid user list'
              listUsers
              sendSecondSessionMail
              echo 'Updating the status in SSM'
	            aws ssm put-parameter --name /a2i/$profile/iam/users/accessKeyMailStatus --profile $profile --value "Second : $now" --type String --overwrite
        else
              echo "The notification level is First but diffrence is less than 3 days which is $diffTime seconds"
      	fi
   elif [[ $notificationLevel =~ 'Second' ]]; then
        if [[ $diffTime -gt 150000 ]]; then
              echo "The notification level is $notificationLevel and time diff is $diffTime"
              echo "This is the time to rotate keys and share with individuals"
              echo 'Pulling the valid user list'
              listUsers
              sendThirdSessionMail
              echo 'Updating the status in SSM'
              aws ssm put-parameter --name /a2i/$profile/iam/users/accessKeyMailStatus --profile $profile --value "Third : $now" --type String --overwrite
        else
              echo "The notification level is Second but diffrence is less than 2 days which is $diffTime seconds"
        fi
   fi
}

sendFirstSessionMail(){

   echo "I am initiating communication for rotation of access keys "
   toMailList=''
   plannedTime=`date -d '5 day' '+%d %b %Y @ 9 AM'`
   while read line; do
    	if [[ $line == "" ]]; then #if1
    	    echo "Skipping empty line"
      else
    	    echo  "The user to mail is $line"
          if [[ $toMailList == "" ]]; then #if1
        			toMailList="$line"
        	else
        			toMailList="$toMailList,$line"
        	fi
    	fi #if1
   done < $filename

  echo "Final to mail list is $toMailList"
  echo 'Sending email'

  aws ses send-email \
       --from "a2isupport@axiomtelecom.com" \
       --destination "ToAddresses=${toMailList}","CcAddresses=yogesh.patil@axiomtelecom.com,anuj.kaushik@axiomtelecom.com" \
       --message "Subject={Data= A2i | $profile | Access key rotation notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> This is the notification regarding the future change of A2i AWS access keys assigned against your user.<br> <b>The change is scheduled to be done on ${plannedTime}.</b> <br> Please make a note that after specified time your existing access keys will not be useful. <br> Please replace old keys with new one which will be provided on ${plannedTime} via email. <br> This change is scheduled at every 90 days as part of best security practices guided by AWS. </b> <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
       --profile $profile
}

sendSecondSessionMail(){

 echo "I am sending reminder for rotation of access keys "
   toMailList=''
   plannedTime=`date -d '2 day' '+%d %b %Y @ 9 AM'`
   while read line; do
        if [[ $line == "" ]]; then #if1
            echo "Skipping empty line"
        else
            echo  "The user to mail is $line"
                if [[ $toMailList == "" ]]; then #if1
                        toMailList="$line"
                else
                        toMailList="$toMailList,$line"
                fi
         fi #if1
   done < $filename

  echo "Final to mail list is $toMailList"

  echo 'Sending email'

  aws ses send-email \
       --from "a2isupport@axiomtelecom.com" \
       --destination "ToAddresses=${toMailList}","CcAddresses=yogesh.patil@axiomtelecom.com,anuj.kaushik@axiomtelecom.com" \
       --message "Subject={Data= A2i | $profile | Access key rotation notification - Gentle Reminder ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> This is the notification regarding the future change of A2i AWS access keys assigned against your user. <br><b>The change is scheduled to be done on ${plannedTime}.</b> <br> Please make a note that after specified time your existing access keys will not be useful. <br> Please replace old keys with new one which will be provided on ${plannedTime}. </b> <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
       --profile $profile

}

sendThirdSessionMail(){

 echo "I am sending reminder for rotation of access keys "

   while read line; do
        if [[ $line == "" ]]; then #if1
            echo "Skipping empty line"
        else
            echo  "The user to mail is $line"
                        toMailList="$line"
                        user="$line"
                        rotateKeys
         fi #if1
   done < $filename

}

rotateKeys(){
    echo "I am rotating keys for $user"
    echo "Deleting existing keys for $user"
      oldAccessKey=`aws iam list-access-keys --user-name $user --profile $profile --max-item 1 --query AccessKeyMetadata[*].AccessKeyId | tr -d '"' | tr -d '[' | tr -d ']' | xargs`
      echo "oldAccessKey for $user is $oldAccessKey"
      aws iam delete-access-key --access-key-id $oldAccessKey --user-name $user --profile $profile

    echo "Creating new keys"

    keys=`aws iam create-access-key --user-name $user --profile $profile --query AccessKey.[AccessKeyId,SecretAccessKey]`

    if [[ $keys == '' ]]; then
          echo "Cant create keys for $user - ignoring for now"
          aws ses send-email \
               --from "a2isupport@axiomtelecom.com" \
               --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
               --message "Subject={Data= A2i | $profile | Access key rotation failure notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi Team <br><br> This is the notification regarding the failure of access key rotation job for user <b>$user </b><br>Please check this on priority. </b> <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
               --profile $profile
    else
          echo "I have received keys as "
          accessKey=`echo $keys | tr -d ']' | tr -d '[' | cut -d ',' -f1 | cut -d '"' -f2`
          secretKey=`echo $keys | tr -d ']' | tr -d '[' | cut -d ',' -f2 | cut -d '"' -f2`
          echo "accessKey is $accessKey and secretKey is $secretKey"
          sendCredentialsMail
    fi

}

sendCredentialsMail(){
    echo "I am sending credentials mail for $user"
    userNameToSend=`echo $user | cut -d '.' -f1 `
    aws ses send-email \
         --from "a2isupport@axiomtelecom.com" \
         --destination "ToAddresses=${toMailList}","CcAddresses=yogesh.patil@axiomtelecom.com" \
         --message "Subject={Data= A2i | $profile | Access key rotation notification - New Credentials ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi $userNameToSend <br><br> Please find below credentials to access A2i $profile account. <br> <b> AccessKey : $accessKey </b> <br> <b> SecretKey : $secretKey </b> <br> Please reach out to A2i DevOps team in case of any issues. <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
         --profile $profile
}


#######################################################################
############################# Main Function ###########################
#######################################################################

mailStatus

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
