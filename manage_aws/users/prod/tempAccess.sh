#!/bin/bash

###############################getting username and orgnisation ##########

username=`echo $emailid | cut -d '@' -f1`
organization=`echo $emailid | cut -d '@' -f2 | cut -d '.' -f1 | tr [a-z] [A-Z]`
firstName=`echo $emailid | cut -d '.' -f1`
firstName=`echo "${firstName^}"`

environment=`echo $env | tr [a-z] [A-Z]`
lastName=`echo $emailid | cut -d '@' -f1 | cut -d '.' -f2 | tr [a-z] [A-Z]`
echo $username
echo $firstName $lastName
echo $organization
#exit 1
###################################Function send email #############################
sendMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=$emailid","CcAddresses=ravi.tomar@intsof.com,yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=AWS $environment $serviceNames  Temp Access Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi $firstName <br> <br> Temp AWS access on services <b>$serviceNames</b> has been provisioned to you.<br><br>Please check<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com" \
        --message "Subject={Data= AWS $environment $serviceNames temp Access Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> AWS temp access on services <b>$serviceNames</b> has been provisioned to <b>$username</b> .<br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env

}
############################## Main code ############

serviceNames=$(echo $serviceNames | sed "s/,/ /g")
echo $serviceNames
for serviceName in $serviceNames
  do
    if [ $serviceName == "Lambda" ]
    then
        aws iam add-user-to-group --user-name $emailid --group-name TempLambdaMaster --profile $env
        if [ $? -eq 0 ]
        then
            echo "Access granted on $serviceName"

        fi
    elif [ $serviceName == "Redshift" ]
    then

            aws iam add-user-to-group --user-name $emailid --group-name TempRedshiftMaster --profile $env
            if [ $? -eq 0 ]
            then
                 echo "Access granted on $serviceName"
            fi
    elif [ $serviceName == "S3" ]
    then

            aws iam add-user-to-group --user-name $emailid --group-name TempS3Master --profile $env
            if [ $? -eq 0 ]
            then
                  echo "Access granted on $serviceName"

            fi
    elif [ $serviceName == "CloudWatch" ]
    then

            aws iam add-user-to-group --user-name $emailid --group-name TempCloudWatchMaster --profile $env
            if [ $? -eq 0 ]
            then
                echo "Access granted on $serviceName"

            fi
    elif [ $serviceName == "StepFucntion" ]
    then

            aws iam add-user-to-group --user-name $emailid --group-name TempStepFucntionMaster --profile $env
            if [ $? -eq 0 ]
            then
                echo "Access granted on $serviceName"

            fi
    elif [ $serviceName == "AWSForecast" ]
          then

                  aws iam add-user-to-group --user-name $emailid --group-name TempForeCastMaster --profile $env
                  if [ $? -eq 0 ]
                  then
                      echo "Access granted on $serviceName"

                  fi
    elif [ $serviceName == "CloudWatchEvents" ]
          then
                  aws iam add-user-to-group --user-name $emailid --group-name TempCloudWatchEventsMaster --profile $env
                  if [ $? -eq 0 ]
                  then
                      echo "Access granted on $serviceName"

                  fi
    elif [ $serviceName == "SSM" ]
          then
                  aws iam add-user-to-group --user-name $emailid --group-name TempSSMMasters --profile $env
                  if [ $? -eq 0 ]
                  then
                      echo "Access granted on $serviceName"

                  fi
    else

            echo 'No selected option found'


    fi
  done
sendMail
