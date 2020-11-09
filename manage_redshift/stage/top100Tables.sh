#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile='stage'
client='axiom'

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

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    echo "Executing queries from file "
    sqlQueryFile=$1
    echo "Query File is $sqlQueryFile"
    results=`psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

sendNotificationsToDevelopersMail(){
  echo "Sending notification"
  #`aws sns publish --topic-arn "arn:aws:sns:eu-west-1:$accountID:stage-devops-notifications-to-developers"  --message "$final_results" --profile $profile`;
  python3 ./sendEmailTop100.py
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile

sql='select "table", size from SVV_TABLE_INFO order by size desc limit 100;'
getConnectionDetails
#executeQueryAndGetResults "${sql}"
msgToAdd=" Hi All, \n\n Please find below list of top 100 tables sorted as per the size for $profile account \n\n"


#sendNotificationsToDevelopersMail
executeQueryAndWriteResultsToFile "${sql}" tmp_query_results.csv

results=`cat tmp_query_results.csv`
final_results=`echo -e "${msgToAdd} ${results}"`
#echo "$final_results"

sendNotificationsToDevelopersMail


#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
rm -rf ./tmp_query_results*
