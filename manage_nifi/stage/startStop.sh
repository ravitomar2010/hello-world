#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

operation=$1
filename='tmpNifiEC2Instances.txt'

######################### Test Parameters #############################
# operation='start'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "dbClient is $dbClient"
  echo "profile is $profile"
  if [[ $profile == 'stage' ]]; then
      redshfitClusterID='axiom-rnd'
  else
      redshfitClusterID='axiom-stage'
  fi
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

fetchUserListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/users" --with-decryption --profile $profile --output text --query Parameter.Value > tmpUsersList.txt

}

startInstances(){
      echo 'Starting ec2 instances'
      fetchInstanceDetails
      instanceCount=0
      while read line; do
        if [[ $line == "" ]]; then ### if1
            echo "Skipping empty line"
        else
            ### echo "Working on $line"
            insatnceID=`echo $line | cut -d ' ' -f2 | cut -d '"' -f2`
            instanceTag=`echo $line | cut -d ' ' -f1`
            echo "insatnceID is ${insatnceID} and instanceTag ${instanceTag}"
            aws ec2 start-instances --instance-ids "${insatnceID}" --profile ${profile}
            instanceCount=$((instanceCount + 1))
            echo "Instance count is ${instanceCount}"
            sleep 900s
            # syncImages
        fi ### if 1
      done < $filename
      # syncImages
}

stopInstances(){
      echo 'Stopping ec2 instances'
      fetchInstanceDetails

      while read line; do
        if [[ $line == "" ]]; then ### if1
            echo "Skipping empty line"
        else
            ### echo "Working on $line"
            insatnceID=`echo $line | cut -d ' ' -f2 | cut -d '"' -f2`
            instanceTag=`echo $line | cut -d ' ' -f1`
            echo "insatnceID is ${insatnceID} and instanceTag ${instanceTag}"
            aws ec2 stop-instances --instance-ids "${insatnceID}" --profile ${profile}
            # sleep 30s
        fi ### if 1
      done < $filename
}

fetchInstanceDetails(){

    echo "Creating support files"
    echo '' > tmpNifiEC2Instances.txt
    echo '' > tmpNifiSlaveInstances.txt

    echo 'Fetching Instances'
    instanceids=`aws ec2 describe-instances \
    --filters "Name=tag:Application,Values=nifi" --profile ${profile} \
    --query Reservations[*].Instances[*].InstanceId[] | tr -d '[' | tr -d ']' | tr -d ','`

    echo "Instance ids are ${instanceids}"
    for instanceId in ${instanceids}; do
        echo "Checking for instance id ${instanceId}"
        instanceTag=$(aws ec2 describe-tags \
            --filters "Name=resource-id,Values=${instanceId}"\
            --profile stage --query 'Tags[?Key==`Name`].[Value][]' --output text)
        echo "${instanceTag} ${instanceId}" >> tmpNifiEC2Instances.txt
    done

}

syncImages(){
      if [[ ${instanceCount} -eq 1 ]]; then
         echo "${instanceTag} is first instance of nifi - Treating this as master node"
         sleep 120s
         stopNifiService
      else
          echo "${instanceTag} is not first instance of nifi - Treating this as slave node"
          echo "${line}" >> tmpNifiSlaveInstances.txt
      fi
      # noOfNodes=`cat tmpNifiEC2Instances.txt | grep . | wc -l`
      # echo "No of instances are ${noOfNodes}"
      # aws ssm get-parameter --name "/a2i/stage/ec2/nifi-1/jenkins" --with-decryption --profile $profile

}

stopNifiService(){
    if [[ ${instanceCount -eq 1 } ]]; then
         ec2Pass=`aws ssm get-parameter --name "/a2i/stage/ec2/${instanceTag}/jenkins" --with-decryption --profile $profile`
    fi
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
if [[ ${operation} == 'start' ]]; then
    echo 'Received start ec2 command moving ahead with the same'
    startInstances
elif [[ ${operation} == 'stop'  ]]; then
    echo 'Received stop ec2 command moving ahead with the same'
    stopInstances
else
    echo 'Invalid command received - exiting'
    exit 1
fi

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
