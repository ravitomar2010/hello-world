#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpGroupList.txt
# dbClient='axiom'
# existingGroupList='';
# groupName='r_intsof'
executionMode=$1

##################### Test Parameters for modify execution mode ##############
#
# dbClient='hyke'
# env='stage'
# batchUser='batch_hyke_fact_model'
# schemaNames='wms_dbo'
# accessLevel='READ'

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

getConnectionDetails(){
  echo 'Fetching required parameters from SSM'
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$dbClient" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    redshiftUserName="axiom_rnd"
  else
    redshiftUserName="axiom_stage"
  fi
  # echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftUserName,$accountID"
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    sqlQueryFile=$1
    echo "Executing queries from file $sqlQueryFile"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -a -w -e -f $sqlQueryFile`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################


getGroupDetailsForUser(){

    sqlQuery=" SELECT count(*) FROM pg_user, pg_group WHERE pg_user.usesysid = ANY(pg_group.grolist)
               AND pg_group.groname = '${groupName}' AND pg_user.usename = '${userName}'"
    executeQueryAndGetResults "${sqlQuery}"
    echo "The user is member of group flag is ${results}"
    isUserMember=${results}
    if [[ ${isUserMember} -gt 0 && ${action} == 'ADD' ]]; then
        echo "User ${userName} is already member of ${groupName}"
    elif [[ ${isUserMember} -lt 1 && ${action} == 'ADD' ]]; then
        echo "User ${userName} is not member of ${groupName} - making necessary changes - ADD"
        sqlQuery="alter group ${groupName} add user ${userName}"
        executeQueryAndGetResults "${sqlQuery}"
    elif [[ ${isUserMember} -gt 0 && ${action} == 'DROP' ]]; then
        echo "User ${userName} is member of ${groupName} - making necessary changes - DROP"
        sqlQuery="alter group ${groupName} drop user ${userName}"
        executeQueryAndGetResults "${sqlQuery}"
    elif [[ ${isUserMember} -lt 1 && ${action} == 'DROP' ]]; then
        echo "User ${userName} is not a member of ${groupName}"
    fi

}

#######################################################################
############################# Main Function ###########################
#######################################################################

if [[ ${executionMode} == *'local'* ]]; then
      #### mode for modifying access for newly created schemas
      dbClient=`echo $executionMode | cut -d '@' -f2`
      echo "dbClient is set to $dbClient"

elif [[ ${executionMode} == *'modifyBatch'*  ]]; then
      #### mode for modifying batch users access
      echo "I am working on $executionMode execution mode"
      action=`echo $1 | cut -d '@' -f2`
      userName=`echo $2 | cut -d '@' -f1`
      groupName=`echo $2 | cut -d '@' -f2`
      env=$3
      dbClient=$4
      echo "userName is $userName , Action is $action, groupName is ${groupName} , env is $env and dbClient is $dbClient"
      getProfile
      getConnectionDetails
      getGroupDetailsForUser
elif [[ ${executionMode} == *'modifyIndividual'*  ]]; then
      #### mode for modifying individual users access
      echo "I am working on $executionMode execution mode"
      groupName=`echo $1 | cut -d '@' -f2`
      accessLevel=$2
      env=$3
      echo "GroupName is $groupName , AccessLevel is $accessLevel and env is $env"
      # getProfile
      # getGroupDetailsForUser
else
    echo "I dont have execution mode - exiting"
    exit 1;
fi


#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
