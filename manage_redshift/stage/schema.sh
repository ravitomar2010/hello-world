#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpSchemaList.txt
# dbClient='axiom'
existingSchemaList='';
# schemaNames='testdevopss'
dbClient=$1

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
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/${dbClient}" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    redshiftuserName="axiom_rnd"
  else
    redshiftuserName="axiom_stage"
  fi
  #echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftuserName,$accountID"
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    sqlQueryFile=$1
    echo "Executing queries from file $sqlQueryFile"
    results=`psql -atAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

fetchSchemaListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/${dbClient}/schema" --with-decryption --profile $profile --output text --query Parameter.Value > tmpSchemaList.txt

}

setSchemaListInSSM(){

	echo 'Checking if schema already exists in ssm schema list'
  for schemaName in $(echo $schemaNames | sed "s/,/ /g")
  do
    	if [[ $schemaName == '' ]]; then
    			echo 'No schemaName is provided as argument - Will not update SSM'
    	elif grep -inx "$schemaName" tmpschemaList.txt ; then
    			echo "schema $schemaName already exists in SSM schema list"
    	else
    			echo "schema $schemaName does not exists in SSM schema list - adding the same"
    			echo "$schemaName" >> tmpschemaList.txt
    			echo 'sorting schema file '
    			sort -o tmpSchemaList.txt tmpSchemaList.txt
    			aws ssm put-parameter --name "/a2i/$profile/redshift/${dbClient}/schema" --value "$(cat tmpSchemaList.txt)" --type String --overwrite --profile $profile
    	fi
  done
}

createSchemas(){

  #Get the list of existing schemas
  echo "Fetching the list of existing schemas from ${dbClient} DB"
  sqlQuery="select s.nspname as table_schema from pg_catalog.pg_namespace s join pg_catalog.pg_user u on u.usesysid = s.nspowner order by table_schema;"
  executeQueryAndGetResults "${sqlQuery}"
  existingSchemaList="${results}"
  # echo "The list of existing schema is $existingSchemaList"

  echo 'Fetching existing group/ access and user list'
  fetchUserListFromSSM
  fetchGroupListFromSSM
  fetchAccessListFromS3

  while read line; do
    echo "Working on $line schema"
    if [[ $line == "" ]]; then #if 1
      echo "Skipping empty line"
    else
        schemaName=$line
        isSchemaExists=`echo $existingSchemaList | grep $schemaName | wc -l`

        if [[ $isSchemaExists -gt 0 ]]; then #if 2
            echo "Schema $schemaName already exists"
            #echo "batch_$schemaName mstr_batch_$schemaName"
            # checkAndResolveDependency $schemaName
        else
            echo "I am creating schema $schemaName"
            sqlQuery="create schema if not exists $schemaName;"
            echo "sql is $sqlQuery"
            executeQueryAndGetResults "$sqlQuery"
            checkAndResolveDependency $schemaName
        fi #if 2

    fi #if 1
  done < $filename

}

checkAndResolveDependency(){
  localSchemaName=$1
  #echo "$localSchemaName"
  echo "Trying to resolve dependency for $localSchemaName"
  if [[ $localSchemaName == *"dbo"* ]]; then
        echo "$localSchemaName contains dbo"
        tempSchemaName=`echo $localSchemaName | rev | cut -c 5- | rev`
        # echo "Temporary schema name is mstr_batch_$tempSchemaName"
        # echo "Temporary user name is batch_$tempSchemaName"
        groupEntryFlag=`cat tmpGroupsList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`
        userEntryFlag=`cat tmpUsersList.txt  | grep "batch_$tempSchemaName" | wc -l`
        accessEntryFlag=`cat tmpAccessList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`

        if [[ $groupEntryFlag -eq 0 ]]; then
            echo "Group entry doesn't exists"
            ./groups.sh "mstr_batch_$tempSchemaName"
        fi

        if [[ $userEntryFlag -eq 0 ]]; then
            echo "User entry doesn't exists"
            ./users.sh "batch_$tempSchemaName mstr_batch_$tempSchemaName"
        fi

        if [[ $accessEntryFlag -eq 0 ]]; then
            echo "Access entry doesn't exists"
            echo "mstr_batch_$tempSchemaName MASTER audit_sysmgmt, $localSchemaName, ${tempSchemaName}_stage" > tmpAccessList.txt
            ./access.sh "local@${dbClient}"

            echo 'Setting access files in S3'
            fetchAccessListFromS3
            echo "mstr_batch_$tempSchemaName MASTER audit_sysmgmt, $localSchemaName, ${tempSchemaName}_stage" >> tmpAccessList.txt
            setAccessListInS3
        fi

  elif [[ $localSchemaName == *"stage"* ]]; then
      #echo "$localSchemaName contains stage"
      tempSchemaName=`echo $localSchemaName | rev | cut -c 7- | rev`
      # echo "Temporary schema name is mstr_batch_$tempSchemaName"
      # echo "Temporary user name is batch_$tempSchemaName"
      groupEntryFlag=`cat tmpGroupsList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`
      userEntryFlag=`cat tmpUsersList.txt  | grep "batch_$tempSchemaName" | wc -l`
      accessEntryFlag=`cat tmpAccessList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`

      if [[ $groupEntryFlag -eq 0 ]]; then
          echo "Group entry doesn't exists"
           ./groups.sh "mstr_batch_$tempSchemaName"
      fi

      if [[ $userEntryFlag -eq 0 ]]; then
          echo "User entry doesn't exists"
           ./users.sh "batch_$tempSchemaName mstr_batch_$tempSchemaName"
      fi

      if [[ $accessEntryFlag -eq 0 ]]; then
          echo "Access entry doesn't exists"
          echo "mstr_batch_$tempSchemaName MASTER audit_sysmgmt, ${tempSchemaName}_dbo, $localSchemaName" > tmpAccessList.txt
          ./access.sh "local@${dbClient}"

          echo 'Setting access files in S3'
          fetchAccessListFromS3
          echo "mstr_batch_$tempSchemaName MASTER audit_sysmgmt, ${tempSchemaName}_dbo, $localSchemaName" >> tmpAccessList.txt
          setAccessListInS3

      fi

  else
      #echo "$localSchemaName is individual schema"
      #echo "$localSchemaName contains dbo"
      tempSchemaName=`echo $localSchemaName`
      #echo "Temporary schema name is mstr_batch_$tempSchemaName"
      #echo "Temporary user name is batch_$tempSchemaName"
      groupEntryFlag=`cat tmpGroupsList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`
      userEntryFlag=`cat tmpUsersList.txt  | grep "batch_$tempSchemaName" | wc -l`
      accessEntryFlag=`cat tmpAccessList.txt | grep "mstr_batch_$tempSchemaName" | wc -l`

      if [[ $groupEntryFlag -eq 0 ]]; then
          echo "Group entry doesn't exists"
           ./groups.sh "mstr_batch_$tempSchemaName"
      fi

      if [[ $userEntryFlag -eq 0 ]]; then
          echo "User entry doesn't exists"
           ./users.sh "batch_$tempSchemaName mstr_batch_$tempSchemaName"
      fi

      if [[ $accessEntryFlag -eq 0 ]]; then
          echo "Access entry doesn't exists"
          echo "mstr_batch_$tempSchemaName MASTER $localSchemaName" > tmpAccessList.txt
          ./access.sh "local@${dbClient}"

          echo 'Setting access files in S3'
          fetchAccessListFromS3
          echo "mstr_batch_$tempSchemaName MASTER $localSchemaName" >> tmpAccessList.txt
          setAccessListInS3

      fi
  fi

}

fetchAccessListFromS3(){

  aws s3 cp s3://a2i-devops-stage/redshift/axiom/accessList.txt ./tmpAccessList.txt --profile $profile

}

setAccessListInS3(){

  sort -o tmpAccessList.txt tmpAccessList.txt
  aws s3 cp ./tmpAccessList.txt s3://a2i-devops-stage/redshift/axiom/accessList.txt --profile $profile

}

fetchUserListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/users" --with-decryption --profile $profile --output text --query Parameter.Value > tmpUsersList.txt

}

fetchGroupListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/groups" --with-decryption --profile $profile --output text --query Parameter.Value > tmpGroupsList.txt

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
getConnectionDetails
fetchSchemaListFromSSM
setSchemaListInSSM
createSchemas

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
sudo rm -rf ./tmp*
