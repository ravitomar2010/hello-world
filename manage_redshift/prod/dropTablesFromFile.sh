#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
filename=tmpListOfTables.txt
# status='Enable'
dbClient='axiom'
# schemaName='edi_dbo'
# tables='temp_edi_imei_pool,temp_edi_imei_mo_pool,temp_edi_imei_pool_stg'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
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
    results=`psql -atAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

dropTables(){
  echo 'Working on dropping tables'
  getConnectionDetails

  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Working on table $line"
        sqlQuery="DROP TABLE IF EXISTS ${line}"
        echo "query to drop table is $sqlQuery"
        executeQueryAndGetResults "${sqlQuery}"
    fi #if1
  done < $filename

  # for table in $(echo $tables | sed "s/,/ /g")
  # do
  #     echo "I am dropping table $table"
  #     sqlQuery="DROP TABLE IF EXISTS ${schemaName}.${table}"
  #     echo "query to drop table is $sqlQuery"
  #     executeQueryAndGetResults "${sqlQuery}"
  # done

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
dropTables
# prepareOutput
# sendNotifications

#############################
########## CleanUp ##########
#############################
echo 'Working on workspace cleanup'
# rm -rf ./tmp*
