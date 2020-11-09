#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpAccessList.txt
# dbClient='axiom'
# existingGroupList='';
# groupName='r_intsof'
executionMode=$1
dbClient=$2

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
    psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -a -w -e -f $sqlQueryFile
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

setInputParameters(){
  if [[ $executionMode == 'auto' ]]; then
      echo 'Execution mode is auto'
      # aws s3 cp s3://a2i-devops-stage/redshift/axiom/accessList.txt ./tmpAccessList.txt --profile $profile
  else
      echo 'Execution mode is local so setting dbClient'
      dbClient=`echo $executionMode | cut -d '@' -f2`
      echo "dbClient is set to $dbClient"
  fi
}

fetchAccessListFromS3(){

  if [[ $executionMode == 'auto' ]]; then
      echo 'Execution mode is auto'
      aws s3 cp s3://a2i-devops-stage/redshift/${dbClient}/accessList.txt ./tmpAccessList.txt --profile $profile
  else
      echo 'Execution mode is local so skipping loading of file'
  fi

}

prepareAccessQueries(){

  echo "Creating supporting files"
  echo '' > tmpAccessQueries.txt

  filename=tmpAccessList.txt
  while read line; do
    if [[ $line == "" ]]; then ##if1
        echo "Skipping empty line"
    else
          groupname=`echo $line | cut -d ' ' -f1`
          echo "I am modifying group $groupname"
          groupflag=`echo group_list.txt | grep -e $groupname | wc -l`
          permissions=`echo $line | cut -d ' ' -f2`
          echo "Permission levels are $permissions"
          schemas=`echo $line | cut -d ' ' -f3-`
          echo "List of groups are $schemas"

          if [[ $schemas == 'ALL' ]]; then
              echo "Permissions are for ALL the schemas"
              provideAccessToAllSchemas
          else
              echo "Permissions are for Specific schemas"
              provideAccessToSpecificSchemas
          fi
    fi
  done < $filename
}

provideAccessToAllSchemas(){
  echo "All schema access modules for groupname $local_groupname and permissions are $local_permissions"

        if [[ $permissions == "READ" ]]; then

            while read schema; do
            #do
                sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sqlQuery="${sql1}${sql2}${sql3}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < schema_list.txt
        elif [[ $permissions == "READWRITE"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sqlQuery="${sql1}${sql2}${sql3}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < schema_list.txt
        elif [[ $permissions == "MASTER"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupname;"
                sqlQuery="${sql1}${sql2}${sql3}${sql4}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < schema_list.txt
        else
            echo "Wrong Permission levels for $groupname"
       fi
    #fi
}

provideAccessToSpecificSchemas(){
  echo "Specific schema access modules"
   if [[ $permissions == "READ" ]]; then

       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sqlQuery="${sql1}${sql2}${sql3}"
           echo "Final sql is $sql"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;

   elif [[ $permissions == "READWRITE"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sqlQuery="${sql1}${sql2}${sql3}"
           echo "Final sql is $sqlQuery"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;
   elif [[ $permissions == "MASTER"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupname;"
           sqlQuery="${sql1}${sql2}${sql3}${sql4}"
           echo "Final sql is $sqlQuery"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;
   else
       echo "Wrong Permission levels for $groupname"
  fi
}

grantAccess(){
    echo 'I am done with preparing queries - Executing the same'
    executeQueryFile "tmpAccessQueries.txt"
}

#######################################################################
############################# Main Function ###########################
#######################################################################

echo "dbClient is $dbClient"
getProfile
setInputParameters
getConnectionDetails
fetchAccessListFromS3
prepareAccessQueries
grantAccess

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
