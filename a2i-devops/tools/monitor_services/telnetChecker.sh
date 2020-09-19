#!/bin/bash
var="$input"
IFS=','   
############### Sending Telnet Email Notifiction ###########
sendemail(){

          aws ses send-email \
          --from "a2iteam@axiomtelecom.com" \
          --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=ravi.tomar@intsof.com" \
          --message "Subject={Data=telnet unsuccessfull to $1 on $2,Charset=utf8},Body={Text={Data=,Charset=utf8},Html={Data=Hi Team</br></br>Service $3 is down on host $1.</br></br>Please check</br></br></br>Regards</br>Devops Team,Charset=utf8}}" \
          --profile stage

}

############ Sending Telnet Notification  ################
sendsms(){

        aws sns publish --topic-arn arn:aws:sns:eu-west-1:403475184785:TelnetAlertNotificationDevops --subject "Connection status" --message "The connection with host $1 at port number $2 with application $3 was unsuccessfull" --profile stage

}

read -a strarr <<<"$var"  
for line in "${strarr[@]}"
do
  hostname=`echo $line | awk '{print $1}'`
  port=`echo $line | awk '{print $2}'`
  name=`echo $line | awk '{print $3}'`
  if ! nc -z -v -w5 $hostname $port
  then
          sendsms $hostname $port $name
          sendemail $hostname $port $name
  fi
done

