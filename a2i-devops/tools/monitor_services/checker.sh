#!/bin/bash

checkAndNotify(){

  web_address=$1
  web_code=$2

  isnotified=`cat ~/notification.txt | grep $web_code | wc -l`;
  echo "Value of isnotified is $isnotified";

  if [[ $isnotified -gt 0 ]]; then

      ##Check if address is already notified
      echo "$web_address Already notified"
      notificationline=`cat ~/notification.txt | grep $web_code`
      lastnotifiedtime=`cat ~/notification.txt | grep $web_code | cut -d " " -f2`
      echo "lastnotifiedtime is $lastnotifiedtime for $web_address"

            { ##difference_checker
              ##Check if lastnotifiedtime if less than an hour
              diff=$(($dnow - $lastnotifiedtime))
              if [[ $diff -gt 900 ]]; then ##
                  cat ~/notification.txt > ~/tmp_notification.txt
                  echo "difference $diff between notification is more than an hour"
                  sed "s/$lastnotifiedtime/$dnow/g" ~/tmp_notification.txt > ~/notification.txt
                  echo "Notifiying for $web_address"
                  aws sns publish --topic-arn $topic_arn --message "The $web_address is not accessible -- please check" --profile prod
              else
                 echo "difference $diff between notification is less than an hour"
              fi ##
            } ##difference_checker
        ##Notification_checker
    else
          echo "Notifiying for $web_address"
          echo "$web_code $dnow" >> ~/notification.txt
        	aws sns publish --topic-arn $topic_arn --message "The $web_address is not accessible -- please check" --profile prod
    fi
}

checkAndRemoveFromNotificationFile(){
  echo "Inside"
  web_code=$1
    isnotified=`cat ~/notification.txt | grep $web_code | wc -l`
    if [[ $isnotified -gt 0 ]]; then
          cat ~/notification.txt > ~/tmp_notification.txt
          echo "Removing $web_code entry from notification file"
          #linetoremove=``
          #sed -i '' "/$web_code/d" ~/tmp_notification.txt > notification2.txt
          grep -v "$web_code" ~/tmp_notification.txt > ~/notification.txt
    fi
}


##########################################################################
##################            Initialisation           ###################
##########################################################################

filename=websites_list.txt
topic_arn='arn:aws:sns:eu-west-1:530328198985:a2i-devops-monitor-websites'

dnow=`date '+%s'`
echo "Current time is $dnow"

while read line; do
  if [[ $line == "" ]]; then
        echo "Skipping empty line"
  else
        web_address=`echo $line | cut -d " " -f-1`;
        web_code=`echo $line | cut -d " " -f2-`;
        echo "Web address is $web_address"
        echo "Web code is $web_code"

          isassecible=`curl -Isk $web_address | grep '200 OK' | wc -l`
          #echo "Access status is $isassecible"

          ##Check for HTML 2
          if [[ $isassecible -lt 1  ]]; then
              echo "Checking for HTTP 2 as failed for HTTP 1.1"
              isassecible=`curl -Isk $web_address | grep 'HTTP/2 200' | wc -l`
          fi

          echo "Access status is $isassecible"

          if [[ $isassecible -eq 0 ]]; then
                echo "$web_code is not working fine. reporting "
                checkAndNotify $web_address $web_code
          else
                echo "$web_address is working perfectly fine"
                checkAndRemoveFromNotificationFile $web_code
          fi
  fi  ##Blank line Check
done < $filename


rm -rf ~/tmp_notification*
