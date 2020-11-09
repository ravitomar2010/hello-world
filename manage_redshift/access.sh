#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpAccessList.txt
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
    # echo "psql --echo-all host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword -a -w -e -f $sqlQueryFile"
    psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -e -f $sqlQueryFile
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

fetchAccessListFromS3(){

  if [[ ${executionMode} == *'auto'* || ${executionMode} == *'modifyBatch'* || ${executionMode} == *'modifyIndividual'*  ]]; then
      echo "Execution mode is $executionMode"
      aws s3 cp s3://a2i-devops-${env}/redshift/${dbClient}/accessList.txt ./tmpAccessList.txt --profile $profile
  else
      echo "Execution mode is $executionMode so skipping loading of file"
  fi

}

prepareAccessQueries(){
  echo '#################################################################'
  echo "######### Creating supporting files and Access Queries ##########"
  echo '#################################################################'

  echo '' > tmpAccessQueries.txt

  filename=tmpAccessList.txt
  while read line; do
    if [[ $line == "" ]]; then ##if1
        echo "Skipping empty line"
    else
          groupName=`echo $line | cut -d ' ' -f1`
          echo "I am cheking on group $groupName"
          groupFlag=`echo group_list.txt | grep -e $groupName | wc -l`
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
  echo "All schema access modules for groupName $groupName and permissions are $permissions"

        if [[ $permissions == "READ" ]]; then

            while read schema; do
            #do
                sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupName;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
                sqlQuery="${sql1}${sql2}${sql3}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < tmpSchemaList.txt
            echo '#################################################################'
        elif [[ $permissions == "READWRITE"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupName;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
                sqlQuery="${sql1}${sql2}${sql3}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < tmpSchemaList.txt
            echo '#################################################################'
        elif [[ $permissions == "MASTER"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupName;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
                sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupName;"
                sqlQuery="${sql1}${sql2}${sql3}${sql4}"
                echo "Final sql is $sqlQuery"
                # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
                echo "$sqlQuery" >> tmpAccessQueries.txt
            done < tmpSchemaList.txt
            echo '#################################################################'
        else
            echo "Wrong Permission levels for $groupName"
       fi
    #fi
}

provideAccessToSpecificSchemas(){
  echo "Specific schema access modules"
   if [[ $permissions == "READ" ]]; then

       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupName;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
           sqlQuery="${sql1}${sql2}${sql3}"
           echo "Final sql is $sqlQuery"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;
       echo '#################################################################'
   elif [[ $permissions == "READWRITE"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupName;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
           sqlQuery="${sql1}${sql2}${sql3}"
           echo "Final sql is $sqlQuery"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;
       echo '#################################################################'
   elif [[ $permissions == "MASTER"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupName;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupName;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupName;"
           sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupName;"
           sqlQuery="${sql1}${sql2}${sql3}${sql4}"
           echo "Final sql is $sqlQuery"
           # psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
           echo "$sqlQuery" >> tmpAccessQueries.txt
       done;
       echo '#################################################################'
   else
       echo "Wrong Permission levels for $groupName"
  fi
}

grantAccess(){
    echo '#################################################################'
    echo '##### I am done with preparing queries - Executing the same #####'
    echo '#################################################################'

    executeQueryFile "tmpAccessQueries.txt"
}

fetchSchemaListFromSSM(){

      echo "Fetching schema list from SSM for $dbClient db in $profile env"
      aws ssm get-parameter --name "/a2i/$profile/redshift/${dbClient}/schema" --with-decryption --profile $profile --output text --query Parameter.Value > tmpSchemaList.txt

}

getCurrentAccessStatus(){
  if [[ ${executionMode} == *'modifyBatch'*  ]]; then
    echo "Checking current READ access status for $batchUser"
    grep  -i -w "mstr_${batchUser} READ" tmpAccessList.txt > tmpREADAccessStatus.txt
    echo "Checking current READWRITE access status for $batchUser"
    grep  -i -w "mstr_${batchUser} READWRITE" tmpAccessList.txt > tmpREADWRITEAccessStatus.txt
    echo "Checking current MASTER access status for $batchUser"
    grep  -i -w "mstr_${batchUser} MASTER" tmpAccessList.txt > tmpMASTERAccessStatus.txt
  elif [[ ${executionMode} == *'modifyIndividual'*  ]]; then
      if [[ ${groupName} -eq 'READ' ]]; then
        echo "Checking current READ access status for $groupName"
        grep  -i "$groupName READ" tmpAccessList.txt > tmpREADAccessStatus.txt
      elif [[ ${groupName} -eq 'READWRITE' ]]; then
        echo "Checking current READWRITE access status for $groupName"
        grep  -i "$groupName READWRITE" tmpAccessList.txt > tmpREADWRITEAccessStatus.txt
      elif [[ ${groupName} -eq 'MASTER' ]]; then
        echo "Checking current MASTER access status for $groupName"
        grep  -i "$groupName MASTER" tmpAccessList.txt > tmpMASTERAccessStatus.txt
      fi
  fi

}

checkAccessStatus(){

    if [[ $accessLevel == 'MASTER' ]]; then
        echo 'Request access level is MASTER'
        setMASTERAccess
    elif [[ $accessLevel == 'READWRITE' ]]; then
        echo 'Request access level is READWRITE'
        setREADWRITEAccess
    else
        echo 'Request access level is READ'
        setREADAccess
    fi

}
setMASTERAccess(){
  masterAccessList=''
  oldMasterAccessList=$(cat tmpMASTERAccessStatus.txt | tr -d '\n')
  # echo "old list is $oldMasterAccessList"
  for schemaName in $(echo $schemaNames | sed "s/,/ /g")
  do
      if [[ $schemaName == '' ]]; then
          echo 'No schemaName is provided as argument - Will break this execution'
      else
          echo "Working on $schemaName"
          tmpMaster=$(grep -i "$schemaName" tmpMASTERAccessStatus.txt | wc -l | tr -d ' ')
          # echo "tmpMaster is $tmpMaster"
          if [[ $tmpMaster -gt 0 ]]; then
              echo "Master entry already exists for $schemaName"
          else
              echo "Master entry does not exists for $schemaName - creating the same"
              if [[ $masterAccessList == '' ]]; then
                  if [[ $oldMasterAccessList == '' ]]; then
                      masterAccessList="mstr_${batchUser} MASTER ${schemaName}"
                  else
                      masterAccessList="$(cat tmpMASTERAccessStatus.txt), $schemaName"
                  fi
              else
                  masterAccessList="$masterAccessList, $schemaName"
              fi
          fi
      fi
  done

  echo "old list is $oldMasterAccessList"
  echo "Final master access list is $masterAccessList"
  echo "Appending this list to tmp file"
  # echo "$masterAccessList" >> tmpMASTERAccessStatus.txt
  if [[ $masterAccessList == '' ]]; then
      echo 'No new entries to modify - Master entries already qualified'
  elif [[ $oldMasterAccessList == '' ]]; then
      echo "$masterAccessList" >> tmpAccessList.txt
  else
      sed -i -e "s|${oldMasterAccessList}|${masterAccessList}|g" tmpAccessList.txt
  fi

}

setREADWRITEAccess(){
  readWriteAccessList=''
  oldReadWriteAccessList=$(cat tmpREADWRITEAccessStatus.txt | tr -d '\n')
  # echo "old list is $oldMasterAccessList"
  for schemaName in $(echo $schemaNames | sed "s/,/ /g")
  do
      if [[ $schemaName == '' ]]; then
          echo 'No schemaName is provided as argument - Will break this execution'
      else
          echo "Working on $schemaName"
          tmpReadWrite=$(grep -i "$schemaName" tmpREADWRITEAccessStatus.txt | wc -l | tr -d ' ')
          tmpMaster=$(grep -i "$schemaName" tmpMASTERAccessStatus.txt | wc -l | tr -d ' ')
          # echo "tmpReadWrite is $tmpReadWrite"
          # echo "tmpMaster is $tmpMaster"
          if [[ ($tmpReadWrite -gt 0) || ($tmpMaster -gt 0) ]]; then
              echo "ReadWrite entry already exists for $schemaName"
          else
              echo "ReadWrite entry does not exists for $schemaName - creating the same"
              if [[ $readWriteAccessList == '' ]]; then
                  if [[ $oldReadWriteAccessList == '' ]]; then
                      readWriteAccessList="mstr_${batchUser} READWRITE ${schemaName}"
                  else
                      readWriteAccessList="$(cat tmpREADWRITEAccessStatus.txt), $schemaName"
                  fi
              else
                  readWriteAccessList="$readWriteAccessList, $schemaName"
              fi
          fi
      fi
  done

  echo "old list is $oldReadWriteAccessList"
  echo "Final readwrite access list is $readWriteAccessList"
  echo "Appending this list to tmp file"
  # echo "$masterAccessList" >> tmpMASTERAccessStatus.txt
  if [[ $readWriteAccessList == '' ]]; then
      echo 'No new entries to modify - ReadWrite entries already qualified'
  elif [[ $oldReadWriteAccessList == '' ]]; then
      echo 'Creating new entries as READWRITE is empty'
      echo "$readWriteAccessList" >> tmpAccessList.txt
  else
      echo 'Replacing READWRITE entries'
      sed -i -e "s|${oldReadWriteAccessList}|${readWriteAccessList}|g" tmpAccessList.txt
  fi

}

setREADAccess(){
  readAccessList=''
  oldReadAccessList=$(cat tmpREADAccessStatus.txt | tr -d '\n')
  # echo "old list is $oldMasterAccessList"
  for schemaName in $(echo $schemaNames | sed "s/,/ /g")
  do
      if [[ $schemaName == '' ]]; then
          echo 'No schemaName is provided as argument - Will break this execution'
      else
          echo "Working on $schemaName"
          tmpRead=$(grep -i "$schemaName" tmpREADAccessStatus.txt | wc -l | tr -d ' ')
          tmpReadWrite=$(grep -i "$schemaName" tmpREADWRITEAccessStatus.txt | wc -l | tr -d ' ')
          tmpMaster=$(grep -i "$schemaName" tmpMASTERAccessStatus.txt | wc -l | tr -d ' ')
          echo "tmpRead is $tmpRead"
          echo "tmpReadWrite is $tmpReadWrite"
          echo "tmpMaster is $tmpMaster"
          if [[ ($tmpReadWrite -gt 0) || ($tmpMaster -gt 0) || ($tmpRead -gt 0) ]]; then
              echo "Read entry already exists for $schemaName"
          else
              echo "Read entry does not exists for $schemaName - creating the same"
              if [[ $readAccessList == '' ]]; then
                  if [[ $oldReadAccessList == '' ]]; then
                      readAccessList="mstr_${batchUser} READ ${schemaName}"
                  else
                      readAccessList="$(cat tmpREADAccessStatus.txt), $schemaName"
                  fi
              else
                  readAccessList="$readAccessList, $schemaName"
              fi
          fi
      fi
  done

  echo "old list is $oldReadAccessList"
  echo "Final read access list is $readAccessList"
  echo "Appending this list to tmp file"
  # echo "$masterAccessList" >> tmpMASTERAccessStatus.txt

  if [[ $readAccessList == '' ]]; then
      echo 'No new entries to modify - Read entries already qualified'
  elif [[ $oldReadAccessList == '' ]]; then
      echo 'Creating new entries as READ is empty'
      echo "$readAccessList" >> tmpAccessList.txt
  else
      echo 'Replacing READ entries'
      sed -i -e "s|${oldReadAccessList}|${readAccessList}|g" tmpAccessList.txt
  fi

}


setAccessListInS3(){

      echo 'Sorting file'

      sort -o tmpAccessList.txt tmpAccessList.txt

      echo 'Pushing file to s3'
      aws s3 cp ./tmpAccessList.txt s3://a2i-devops-${env}/redshift/${dbClient}/accessList.txt --profile ${profile}

}

prepareTempAccessQueries(){

  if [[ ${executionMode} == *'modifyBatch'* ]]; then
      echo "Preparing temp access queries for $batchUser"
      cat tmpAccessList.txt >> tmpOldAccessList.txt
      grep -i -w "mstr_${batchUser}" tmpOldAccessList.txt > tmpAccessList.txt
  elif [[ ${executionMode} == *'modifyIndividual'* ]]; then
      echo "Preparing temp access queries for $groupName"
      echo "${groupName} ${accessLevel} ${schemaNames}" > tmpAccessList.txt
  fi

}

checkGroupEntry(){
  echo '#################################################################'
  echo '### Done with correcting access file - Cheking group entries  ###'
  echo '#################################################################'
  ./modifyGroupMembers.sh "modifyBatch@ADD" "${batchUser}@mstr_${batchUser}" ${env} ${dbClient}
}


#######################################################################
############################# Main Function ###########################
#######################################################################

if [[ ${executionMode} == *'auto'* ]]; then
    #### mode for rebuilding access
    echo "I am working on $executionMode execution mode"
    dbClient=$2
    env=$3
    getProfile
    getConnectionDetails
    fetchAccessListFromS3
    fetchSchemaListFromSSM
    prepareAccessQueries
    grantAccess
elif [[ ${executionMode} == *'local'* ]]; then
    #### mode for modifying access for newly created schemas
    dbClient=`echo $executionMode | cut -d '@' -f2`
    echo "dbClient is set to $dbClient"
    getProfile
    getConnectionDetails
    fetchAccessListFromS3
    fetchSchemaListFromSSM
    prepareAccessQueries
    grantAccess
elif [[ ${executionMode} == *'modifyBatch'*  ]]; then
      #### mode for modifying batch users access
      # echo "I am working on $executionMode execution mode"
      # batchUser=`echo $1 | cut -d '@' -f2`
      # accessLevel=$2
      # env=$3
      # dbClient=$4
      # echo "batchUser is $batchUser , AccessLevel is $accessLevel , env is $env and dbClient is $dbClient"
      # getProfile
      # getConnectionDetails
      # fetchAccessListFromS3
      # ### getCurrentAccessStatus
      # ### checkAccessStatus
      # ### setAccessListInS3
      # prepareTempAccessQueries
      # prepareAccessQueries
      # grantAccess

      getProfile
      getConnectionDetails
      fetchAccessListFromS3
      getCurrentAccessStatus
      checkAccessStatus
      setAccessListInS3
      checkGroupEntry
      prepareTempAccessQueries
      prepareAccessQueries
      grantAccess

elif [[ ${executionMode} == *'modifyIndividual'*  ]]; then
      #### mode for modifying individual users access
      echo "I am working on $executionMode execution mode"
      groupName=`echo $2 | cut -d '@' -f1`
      accessLevel=`echo $2 | cut -d '@' -f2`
      env=$3
      dbClient=`echo $1 | cut -d '@' -f2`
      schemaNames=$4
      echo "GroupName is $groupName , AccessLevel is $accessLevel, dbClient is $dbClient, schemaNames is $schemaNames and env is $env"
      getProfile
      getConnectionDetails
      ### fetchAccessListFromS3
      ### getCurrentAccessStatus
      ### checkAccessStatus
      ### setAccessListInS3
      prepareTempAccessQueries
      prepareAccessQueries
      grantAccess
else
    echo "I dont have execution mode - exiting"
    exit 1;
fi


#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
