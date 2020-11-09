#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpAccessList.txt

##################### Test Parameters ##############

# dbClient='hyke'
# env='stage'
# batchUser='batch_bi_dbo'
# schemaNames='delivery_dbo'
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
    psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -a -w -e -f $sqlQueryFile
}


getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
	devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

setInputParameters(){
  if [[ $executionMode == 'auto' ]]; then
      echo 'Execution mode is auto'
      # aws s3 cp s3://a2i-devops-${env}/redshift/axiom/accessList.txt ./tmpAccessList.txt --profile $profile
  else
      echo 'Execution mode is local so setting dbClient'
      dbClient=`echo $executionMode | cut -d '@' -f2`
      echo "dbClient is set to $dbClient"
  fi
}

fetchAccessListFromS3(){

      aws s3 cp s3://a2i-devops-${env}/redshift/${dbClient}/accessList.txt ./tmpAccessList.txt --profile $profile

}

setAccessListInS3(){

      echo 'Sorting file'

      sort -o tmpAccessList.txt tmpAccessList.txt

      echo 'Pushing file to s3'
      aws s3 cp ./tmpAccessList.txt s3://a2i-devops-${env}/redshift/${dbClient}/accessList.txt --profile $profile

}

grantAccess(){
    echo '#################################################################'
    echo '##### I am done with correcting access file - Executing it  #####'
    echo '#################################################################'
    ./access.sh "modifyBatch@${batchUser}" ${accessLevel} ${env} ${dbClient}
}

fetchSchemaListFromSSM(){

      echo "Fetching schema list from SSM for $dbClient db in $profile env"
      aws ssm get-parameter --name "/a2i/$profile/redshift/${dbClient}/schema" --with-decryption --profile $profile --output text --query Parameter.Value > tmpSchemaList.txt

}

getCurrentAccessStatus(){
    echo "Checking current READ access status for $batchUser"
    grep  -i -w "mstr_${batchUser} READ" tmpAccessList.txt > tmpREADAccessStatus.txt
    echo "Checking current READWRITE access status for $batchUser"
    grep  -i -w "mstr_${batchUser} READWRITE" tmpAccessList.txt > tmpREADWRITEAccessStatus.txt
    echo "Checking current MASTER access status for $batchUser"
    grep  -i -w "mstr_${batchUser} MASTER" tmpAccessList.txt > tmpMASTERAccessStatus.txt
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

checkGroupEntry(){
  echo '#################################################################'
  echo '### Done with correcting access file - Cheking group entries  ###'
  echo '#################################################################'
  ./modifyGroupMembers.sh "modifyBatch@ADD" "${batchUser}@mstr_${batchUser}" ${env} ${dbClient}
}

sendNotifications(){
  getSSMParameters

  aws ses send-email \
  --from "a2isupport@axiomtelecom.com" \
  --destination "ToAddresses=$devopsMailList","CcAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data=${env} | ${dbClient} | A2i Access Modification Notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All\,<br><br>This is to notify you all that access has been modified in <b>$env</b> environment for <b>$dbClient</b> db for <b>${schemaNames//,/\,} </b> schemas.<br>Batch user <b>$batchUser</b> is now having <b>${accessLevel} </b> on mentioned schemas.<br>Please reach out to devops in case of any issues.<br><br>Thanks and Regards\,<br>DevOps Team,Charset=utf8}}" \
  --profile prod
}

#######################################################################
############################# Main Function ###########################
#######################################################################

echo "Working on modifying batch access for ${batchUser} in env ${env} "
getProfile
getConnectionDetails
fetchAccessListFromS3
getCurrentAccessStatus
checkAccessStatus
setAccessListInS3
checkGroupEntry
grantAccess
# sendNotifications

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
