#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile='stage'
filename='changeInstanceType.txt'
client='axiom'
#operationType='downgrade'
operationType=$1
instanceProfile=''
instanceID=''
desiredInstanceType=''
iseligibileToUpdate='0'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

getConnectionDetails(){
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$client" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    redshiftUserName="axiom_rnd"
  else
    redshiftUserName="axiom_stage"
  fi
  #echo "$host,$port,$dbName,$masterpassword,$redshiftUserName "
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

getParameters(){
  lineToProcess=$1
  echo "$lineToProcess"
  instanceProfile=`echo $lineToProcess | cut -d ' ' -f1`
  instanceID=`echo $lineToProcess | cut -d ' ' -f2`
  echo "Working on Instance profile $instanceProfile"
  echo "Instance id is $instanceID"

  if [[ $operationType == 'upgrade' ]]; then
    desiredInstanceType=`echo "$lineToProcess" | cut -d ' ' -f3 | cut -d "=" -f2`
  elif [[ $operationType == 'downgrade' ]]; then
    desiredInstanceType=`echo "$lineToProcess" | cut -d ' ' -f4 | cut -d "=" -f2`
  else
    echo "operation type is not supported $operationType"
    exit 1
  fi
  echo "Desired Instance Type is $desiredInstanceType"
}

validateCurrentInstanceType(){
  echo "Validating current instane type"
  currentInstanceType=`aws ec2 describe-instances --instance-ids $instanceID --profile $profile | grep -e '"InstanceType":' | cut -d ':' -f2 | cut -d '"' -f2`

  if [[ $currentInstanceType == $desiredInstanceType ]]; then
      echo "Instance type already sattisfied .. Moving Ahead.."
      iseligibileToUpdate='0'
  else
      echo "Instance type is different.. Moving ahead with update.."
      iseligibileToUpdate='1'
  fi

}
stopInstanceAndWaitToComplete(){
  echo "Stopping instace $instanceProfile"

  aws ec2 stop-instances --instance-ids $instanceID --profile $profile
  sleep 5

  stop_count=1;
  timer=0;
    while [[ $stop_count -gt 0 ]]; do
        if [[ $timer -lt 600 ]]; then
            stop_count=`aws ec2 describe-instance-status --instance-ids $instanceID --profile $profile | grep '"Name":' | wc -l`
            echo "Still waiting for instance $instanceProfile to get stopped since last $timer seconds"
            sleep 5;
            timer=$((timer + 5))
        else
            stop_count=0;
            echo "Timeout error occured while stopping the instance $instanceProfile. Please check.. !!"
            return 0
        fi
    done
    sleep 5
    echo "Stopped the instance $instanceProfile. Moving ahead..."

}

startInstanceAndWaitToComplete(){
  echo "Starting instace $instanceProfile"

  aws ec2 start-instances --instance-ids $instanceID --profile $profile
  sleep 5

  stop_count=0;
  timer=0;
    while [[ $stop_count -lt 1 ]]; do
        if [[ $timer -lt 600 ]]; then
            stop_count=`aws ec2 describe-instance-status --instance-ids $instanceID --profile $profile | grep '"Name": "running"' | wc -l`
            echo "Still waiting for instance $instanceProfile to get started since last $timer seconds"
            aws ec2 start-instances --instance-ids $instanceID --profile $profile
            sleep 5;
            timer=$((timer + 5))
        else
            stop_count=3;
            echo "Timeout error occured while starting the instance $instanceProfile. Please check.. !!"
            return 0
        fi
    done
    echo "Started the instance $instanceProfile. Moving ahead..."

}

changeInstanceTypeAndWait(){
  echo "Modifying instance type to $desiredInstanceType"
  aws ec2 modify-instance-attribute --instance-id=$instanceID --instance-type $desiredInstanceType --profile $profile
  sleep 2

  currentInstanceType=`aws ec2 describe-instances --instance-ids $instanceID --profile $profile | grep -e '"InstanceType":' | cut -d ':' -f2 | cut -d '"' -f2`

  while [[ $currentInstanceType != $desiredInstanceType ]]; do
      sleep 5
      echo "Still modifying instance ..."
      aws ec2 modify-instance-attribute --instance-id=$instanceID --instance-type $desiredInstanceType --profile $profile
      sleep 2
      currentInstanceType=`aws ec2 describe-instances --instance-ids $instanceID --profile $profile | grep -e '"InstanceType":' | cut -d ':' -f2 | cut -d '"' -f2`
  done
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
      #echo "line is $line"
      getParameters "${line}"
      validateCurrentInstanceType
        if [[ $iseligibileToUpdate -eq '1' ]]; then
          echo "Updating instance"
          stopInstanceAndWaitToComplete
          changeInstanceTypeAndWait
          startInstanceAndWaitToComplete
        else
          echo "Moving ahead with next instance"
        fi
  fi
done < $filename

#############################
########## CleanUp ##########
#############################

# echo "Working on CleanUp"
# rm -rf ./tmp_query_results*
