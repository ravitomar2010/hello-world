#!/bin/bash

###############################getting username and orgnisation ##########

username=`echo $emailid | cut -d '@' -f1`
organization=`echo $emailid | cut -d '@' -f2 | cut -d '.' -f1 | tr [a-z] [A-Z]`
firstName=`echo $emailid | cut -d '.' -f1 | tr [a-z] [A-Z]`
environment=`echo $env | tr [a-z] [A-Z]`
lastName=`echo $emailid | cut -d '@' -f1 | cut -d '.' -f2 | tr [a-z] [A-Z]`
echo $username
echo $firstName $lastName
echo $organization
#exit 1
###################################Function send email #############################
sendingMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=$emailid","CcAddresses=ravi.tomar@intsof.com,yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=AWS $environment $serviceName  Temp Access Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi $firstName <br> <br> Temp AWS access on service $serviceName has been provisioned to you.<br><br>Please check<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com" \
        --message "Subject={Data= AWS $environment $serviceName temp Access Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> AWS temp access on service $serviceName has been provisioned to $username .<br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env

}
############################## Main code ############

if [ $serviceName == "Lambda" ]
then
    aws iam add-user-to-group --user-name $emailid --group-name TempLambdaMaster --profile $env
    if [ $? -eq 0 ]
    then
        echo sending email
        sendingMail
    fi
elif [ $serviceName == "Redshift" ]
then

        aws iam add-user-to-group --user-name $emailid --group-name TempRedshiftMaster --profile $env
        if [ $? -eq 0 ]
        then
            echo sendingEmail
            sendingMail
        fi
elif [ $serviceName == "S3" ]
then

        aws iam add-user-to-group --user-name $emailid --group-name TempS3Master --profile $env
        if [ $? -eq 0 ]
        then
            echo sendingEmail
            sendingMail
        fi
elif [ $serviceName == "CloudWatch" ]
then

        aws iam add-user-to-group --user-name $emailid --group-name TempCloudWatchMaster --profile $env
        if [ $? -eq 0 ]
        then
            echo sendingEmail
            sendingMail
        fi
elif [ $serviceName == "StepFucntion" ]
then

        aws iam add-user-to-group --user-name $emailid --group-name TempStepFucntionMaster --profile $env
        if [ $? -eq 0 ]
        then
            echo sendingEmail
            sendingMail
        fi
elif [ $serviceName == "AWSForecast" ]
      then

              aws iam add-user-to-group --user-name $emailid --group-name TempForeCastMaster --profile $env
              if [ $? -eq 0 ]
              then
                  echo sendingEmail
                  sendingMail
              fi
elif [ $serviceName == "CloudWatchEvents" ]
      then
              aws iam add-user-to-group --user-name $emailid --group-name TempCloudWatchEventsMaster --profile $env
              if [ $? -eq 0 ]
              then
                  echo sendingEmail
                  sendingMail
              fi
else

        echo No selected option found


fi
