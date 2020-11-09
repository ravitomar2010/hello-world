#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile="$env"
dbClient='axiom'
#dbClient=$1
#sqlQuery=$1
fileName=restoreTableList.txt
snapshotID=rs:axiom-rnd-2020-07-19-01-53-36

#bucketName=''
#folderPath
#users='dolar_ghosh'
# BUILD_USER='yogesh.patil'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
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
  #echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftUserName,$accountID"
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

checkRestoreStatus(){

  timerCount=0;

  while [[ $timerCount -lt 600 ]]; do
    restoreStatus=`aws redshift describe-table-restore-status --cluster-identifier $redshfitClusterID --profile $profile --max-item 1 --query TableRestoreStatusDetails[*].Status --output text`
    restoreStatus=$(echo $restoreStatus | cut -d ' ' -f1)
    echo "Restore status is $restoreStatus"

    if [[ $restoreStatus == 'SUCCEEDED' ]]; then
        echo 'I have received SUCCEEDED status moving ahead with next table'
        timerCount=1000;
    elif [[ $restoreStatus == 'FAILED'  ]]; then
        echo "Received failure notification for $table - moving ahead for other tables"
        timerCount=1000;
        echo "$schema.$table" >> restoreFailedList.txt
    else
        echo "current status is $restoreStatus - still waiting since $timerCount seconds"
        sleep 5
        timerCount=$((timerCount + 5))
        #timer=$((timer + 5))
    fi
  done

}

startRestore(){
    echo "schema is $schema and table is $table"
    aws redshift restore-table-from-cluster-snapshot --cluster-identifier "$redshfitClusterID" --snapshot-identifier "$snapshotID" --source-database-name "$dbName" --source-schema-name "$schema"  --target-database-name "$dbName" --target-schema-name "$schema"  --profile $profile --source-table-name "$table" --new-table-name "$table"
    checkRestoreStatus

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
getConnectionDetails

echo 'Creating supporting file'
echo '' > restoreFailedList.txt

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
      echo "Table to process is $line"
      schema=$(echo $line | cut -d '.' -f1)
      table=$(echo $line | cut -d '.' -f2)
      startRestore

  fi #if1

done < $fileName

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
#sudo rm -rf ./tmp*
