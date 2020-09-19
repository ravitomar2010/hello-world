#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
# filename=tmpListOfEvents.txt
# status='Enable'
# dbClient='axiom'
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

getSSMParameters(){
  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery and results file will be $outputFile"
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

vacuumList(){
  echo 'Preapring list of tables to run vacuum'
  sqlQuery="SELECT \"schema\" + '.' + \"table\" FROM svv_table_info where unsorted > 5 order by 1"
  outputFile='tmpVacuumList.txt'
  executeQueryAndWriteResultsToFile "${sqlQuery}" "${outputFile}"
}

analyzeList(){
  echo 'Preapring list of tables to run analyze'
  sqlQuery="SELECT \"schema\" + '.' + \"table\" FROM svv_table_info where stats_off > 10 order by 1 "
  outputFile='tmpAnalyzeList.txt'
  executeQueryAndWriteResultsToFile "${sqlQuery}" "${outputFile}"

}

vacuumOnTables(){
  echo 'Working on vacuuming tables'
  filename='tmpVacuumList.txt'
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Working on table $line"
        sqlQuery="vacuum $line"
        executeQueryAndGetResults "${sqlQuery}"
    fi #if1
  done < $filename
}

analyzeOnTables(){
  echo 'Working on analyzing tables'
  filename='tmpAnalyzeList.txt'
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Working on table $line"
        sqlQuery="ANALYZE VERBOSE $line"
        executeQueryAndGetResults "${sqlQuery}"
    fi #if1
  done < $filename
}

#######################################################################
############################# Main Function ###########################
#######################################################################

  getProfile

  echo 'I am working on axiom client'
  dbClient='axiom'
  getConnectionDetails
  vacuumList
  vacuumOnTables
  analyzeList
  analyzeOnTables

  echo 'I am working on hyke client'
  dbClient='hyke'
  getConnectionDetails
  vacuumList
  vacuumOnTables
  analyzeList
  analyzeOnTables

#############################
########## CleanUp ##########
#############################

rm -rf ./tmp*
