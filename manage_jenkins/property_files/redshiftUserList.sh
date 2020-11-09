#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile='stage'
dbClient='axiom'
#dbClient=$1
#sqlQuery=$1
#fileName=$2
#bucketName=''
#folderPath

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

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -qtAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -qtAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    echo "Executing queries from file "
    sqlQueryFile=$1
    echo "Query File is $sqlQueryFile"
    results=`psql -qtAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

getProdDetails(){
    profile='prod'

    getConnectionDetails

    echo 'Generating normal users on prod'

    sqlQuery="select usename from pg_user where usename not like '%batch%' order by 1"

    executeQueryAndWriteResultsToFile "${sqlQuery}" "/data/extralibs/redshift/prod/UsersList.txt"

    echo 'Generating batch users list'

    sqlQuery="select usename from pg_user where usename like '%batch%' order by 1"

    executeQueryAndWriteResultsToFile "${sqlQuery}" "/data/extralibs/redshift/prod/BatchUsersList.txt"
}

getStageDetails(){
  profile='stage'

  getConnectionDetails

  echo 'Generating normal users on stage'

  sqlQuery="select usename from pg_user where usename not like '%batch%' order by 1"

  executeQueryAndWriteResultsToFile "${sqlQuery}" "/data/extralibs/redshift/stage/UsersList.txt"

  echo 'Generating batch users list for stage'

  sqlQuery="select usename from pg_user where usename like '%batch%' order by 1"

  executeQueryAndWriteResultsToFile "${sqlQuery}" "/data/extralibs/redshift/stage/BatchUsersList.txt"
}

#######################################################################
############################# Main Function ###########################
#######################################################################

echo 'Working on prod environment'
getProdDetails
echo 'Working on stage environment'
getStageDetails

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf /data/s3space/${filename}
