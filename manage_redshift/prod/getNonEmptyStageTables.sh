#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# profile='stage'
# dbClient='axiom'
# dbClient=$1
#sqlQuery=$1
#fileName=$2
#bucketName=''
#folderPath
filename=tmpListOfEvents.txt

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
  #echo "$host,$port,$dbName,$masterpassword,$redshiftUserName "
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
    results=`psql -tX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    echo "Executing queries from file "
    sqlQueryFile=$1
    echo "Query File is $sqlQueryFile"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

getSSMParameters(){
  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

listEvents(){

    echo 'Listing all active events'
    aws events list-rules --profile $profile --query 'Rules[?(ManagedBy!=`states.amazonaws.com` && State==`ENABLED`)]'.[Name][] | tr -d '"' | tr -d '[' | tr -d ']' | tr -d ',' > tmpListOfEvents.txt

}

enableEvents(){

    echo 'Enabling all the disabled events'
    filename='tmpListOfEvents.txt'
    getSSMValue
    while read line; do
      if [[ $line == "" ]]; then ##if1
          echo "Skipping empty line"
      else
          echo "I am working on event $line"
          aws events enable-rule --name $line --profile $profile
      fi
    done < $filename
    # sendNotifications
}

getSSMValue(){

      echo 'Getting ssm paramaters after disabling rules'
      aws ssm get-parameter --name /a2i/$profile/cloudwatch/events/disabledRules --profile $profile --query Parameter.Value --output text > tmpListOfEvents.txt
}

disableEvents(){

    echo 'Disabling all the enabled events'
    # aws events enable-rule --name
    while read line; do
      if [[ $line == "" ]]; then ##if1
          echo "Skipping empty line"
      else
          echo "I am working on event $line"
          aws events disable-rule --name $line --profile $profile
      fi
    done < $filename
    setSSMValue
    # sendNotifications
}

setSSMValue(){

      echo 'Setting ssm paramaters after disabling rules'
      aws ssm put-parameter --name /a2i/$profile/cloudwatch/events/disabledRules --value "$(cat tmpListOfEvents.txt)" --type String --overwrite --profile $profile
}

sendNotifications(){
  getSSMParameters
  echo 'Sending notification to team members'

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList,anuj.kaushik@axiomtelecom.com" \
  --message "Subject={Data= $profile | $dbClient | List of Non empty stage tables - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt) ,Charset=utf8}}" \
  --profile $profile

  # aws ses send-email \
  # --from "yogesh.patil@axiomtelecom.com" \
  # --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
  # --message "Subject={Data= $profile | $dbClient | List of Non empty stage tables - $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt) ,Charset=utf8}}" \
  # --profile $profile


}

prepareOutput(){

  filename='tmpTableList.csv'
  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "<h3>Hi All <br><br>Please find below list of tables from $dbClient database which has non zero size and belongs to stage schema in $profile account</h3>" >> tmpFinalOP.txt
  echo '<table>' >> tmpFinalOP.txt
  echo '<tr><td><b>DBName</b></td><td><b>SchemaName</b></td><td><b>TableName</b></td><td><b>Size</b></td></tr>' >> tmpFinalOP.txt
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Working on line $line"
        db=`echo $line | cut -d '|' -f1`
        schema=`echo $line | cut -d '|' -f2`
        line=`echo $line | cut -d '|' -f2- | cut -d '|' -f2-`
        table=`echo $line | cut -d '|' -f1`
        size=`echo $line | cut -d '|' -f2`
        # echo "db is $db schema is $schema table is $table and size is $size"
        echo "<tr><td>${db}</td><td>${schema}</td><td>${table}</td><td>${size}</td></tr>" >> tmpFinalOP.txt

    fi #if1
  done < $filename

  echo '</table>' >> tmpFinalOP.txt
  echo "<br><h3>Please reach out to devops in case of any concerns. <br>Regards<br>DevOps Team</h3>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt
}

#######################################################################
############################# Main Function ###########################
#######################################################################


getProfile

echo 'Disabling cloudwatch events to pull report'
listEvents

disableEvents

sleep 900;

echo 'Working on axiom database'

dbClient='axiom'

getConnectionDetails

sqlQuery="select \"database\",\"schema\",\"table\",\"size\" from svv_table_info where schema like '%_stage%' and size > 0 order by size desc;"

executeQueryAndWriteResultsToFile "${sqlQuery}" "tmpTableList.csv"

echo 'Enabling cloudwatch events to pull report'

prepareOutput

sendNotifications

echo 'Working on hyke database'

dbClient='hyke'

getConnectionDetails

sqlQuery="select \"database\",\"schema\",\"table\",\"size\" from svv_table_info where schema like '%_stage%' and size > 0 order by size desc;"

executeQueryAndWriteResultsToFile "${sqlQuery}" "tmpTableList.csv"

echo 'Enabling cloudwatch events to pull report'

prepareOutput

sendNotifications

enableEvents

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# rm -rf tmp*
