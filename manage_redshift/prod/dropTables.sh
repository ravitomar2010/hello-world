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
  for table in $(echo $tables | sed "s/,/ /g")
  do
      echo "I am dropping table $table"
      sqlQuery="DROP TABLE IF EXISTS ${schemaName}.${table}"
      echo "query to drop table is $sqlQuery"
      executeQueryAndGetResults "${sqlQuery}"
  done

}

sendNotifications(){
  getSSMParameters
  echo 'Sending notification to team members'

      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList" \
      --message "Subject={Data= $profile | Redshift drop table notification - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data= $(cat tmpFinalOP.txt) ,Charset=utf8}}" \
      --profile $profile

}

prepareOutput(){

  echo '' > tmpFinalOP.txt
  echo '<pre>' >> tmpFinalOP.txt
  echo "Hi All <br><br>This is to notify that following tables has been dropped from $profile environment.<br>" >> tmpFinalOP.txt
  # echo "<br>==========================================================" >> tmpFinalOP.txt
  echo "<table border=1px;>  <tr>    <th>Schema</th>    <th>Table</th>  </tr>" >> tmpFinalOP.txt
    for table in $(echo $tables | sed "s/,/ /g")
    do
        echo "<tr><td>${schemaName}</td><td>${table}</td></tr>" >> tmpFinalOP.txt
    done
  echo '</table>' >> tmpFinalOP.txt
  # echo "==========================================================" >> tmpFinalOP.txt
  echo "<br>We have a backup of these tables valid for next 7 days.<br>Please reach out to DevOps team in case of any issue or concerns. <br><br>Thanks and Regards <br> DevOps Team." >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
dropTables
prepareOutput
sendNotifications

#############################
########## CleanUp ##########
#############################
echo 'Working on workspace cleanup'
# rm -rf ./tmp*
