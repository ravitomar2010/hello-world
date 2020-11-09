#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################



######################### Test Parameters #############################
operation='start'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  # curr_dir=`pwd`
  # profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "dbClient is $dbClient"
  profile="${env}"
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

}

# stopInstances(){
#
# }

#######################################################################
############################# Main Function ###########################
#######################################################################

if [[ ${operation} == 'start' ]]; then
    echo 'Received start ec2 command moving ahead with the same'
elif [[ ${operation} == 'stop'  ]]; then
    echo 'Received stop ec2 command moving ahead with the same'
else
    echo 'Invalid command received - exiting'
    exit 1
fi


#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
