#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# profile=''
# dbClient='axiom'
# schemaName='shipment_dbo'
# tableNames='activation_nokia_huawei'

##############Test Parameters ##############
# profile='prod'
# dbClient='axiom'
# schemaName='bi'
# tableNames='cust_temp'
############################################

useremailid='a2isupport@axiomtelecom.com'
todayDate=`date +\%Y-\%m-\%d`
s3FolderName=''
prodNoOfCol=''
stageNoOfCol=''
curr_dir=`pwd`
isDateParameterExists='0'

echo "current working directory is $curr_dir"

#######################################################################
############################# Generic Code ############################
#######################################################################

#getProfile(){
# curr_dir=`pwd`
# profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
# echo "profile is $profile"
#}

getConnectionDetails(){
  echo 'Fetching connection parameters from AWS '
  echo 'Fetching hostname '
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching portNo '
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching db name '
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$dbClient" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching redshift master password'
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching accountID'
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Setting redshift username'
  if [[ $profile == "stage" ]]; then
    #statements
    redshiftUserName="axiom_rnd"
  else
    redshiftUserName="axiom_stage"
  fi
 # echo "$hostName , $portNo , $dbName , $redshiftPassword, $redshiftUserName "
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -qAt "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
   # echo $results
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query to execute is $sqlQuery"
    echo "outputFile is ${curr_dir}/${outputFile}"
    #results=`psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
   # echo $2
}

executeQueryFile(){
    echo "Executing queries from file "
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################
getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}
executeUnloadQuery(){

  sql="unload ('select * from $schemaName.$tableName') to 's3://a2i-devops-prod/$s3FolderName' iam_role 'arn:aws:iam::530328198985:role/Redshift-S3-Role' delimiter '~' parallel off HEADER  ALLOWOVERWRITE ADDQUOTES ESCAPE ;"
  executeQueryAndGetResults "${sql}"
}

executelimitedUnloadQuery(){

  unloadlimited=$1
  sql="unload ('$unloadlimited') to 's3://a2i-devops-prod/$s3FolderName' iam_role 'arn:aws:iam::530328198985:role/Redshift-S3-Role' delimiter '~' parallel off HEADER  ALLOWOVERWRITE ADDQUOTES ESCAPE"
  executeQueryAndGetResults "${sql}"

}


executeAwsS3CopyQuery(){

aws s3 cp s3://a2i-devops-prod/$s3FolderName s3://a2i-devops-stage/$s3FolderName  --profile stage --recursive

}

executeTruncateQuery() {
      tableTruncate="truncate table $schemaName.$tableName"
      executeQueryAndGetResults "${tableTruncate}"
}

executeDropQuery() {
      tableDrop="drop table $schemaName.$tableName"
      executeQueryAndGetResults "${tableDrop}"
}

executeStageS3toRedShift(){

  s3ToRedShift="copy $schemaName.$tableName FROM 's3://a2i-devops-stage/$s3FolderName' iam_role 'arn:aws:iam::403475184785:role/Redshift-S3-Role' delimiter '~' EXPLICIT_IDS REMOVEQUOTES ACCEPTINVCHARS ESCAPE IGNOREHEADER 1 ;"
  echo "uploading data on Staging DB....."
  executeQueryAndGetResults "${s3ToRedShift}"

}

s3CleanUp(){

aws s3 rm s3://a2i-devops-prod/temp-space/ --profile prod --recursive
aws s3 rm s3://a2i-devops-stage/temp-space/ --profile stage --recursive

}

checkIfTableExists(){
  sql="select count(*) from pg_tables where schemaname = '$schemaName' and tablename = '$tableName'"
  executeQueryAndGetResults "${sql}"
  isTableExists=`echo $results`
  echo "table record count $isTableExists"

  if [ $isTableExists -eq 0 ];then
      echo "$tableName does not exist on stage. Hence creating Table"
      executeQueryAndGetResults "${tableDefQuery}"
  else
      echo "$tableName found proceesing further"
      checkTableStructure
  fi

}

checkTableStructure(){
  echo "Checking for table structure"

  echo "Number of Columns in $profile is $countProdColumn"

  getTableStructureStage

  echo "Number of Columns in $profile is $countStageColumn"

  if [[ $countProdColumn -eq $countStageColumn ]]; then ##prodNoOfCol -eq stageNoOfCol
    echo "$countStageColumn is equal to $countStageColumn Hence truncating"
    executeTruncateQuery
  else
    echo "Table structure does not match - droping table on $profile"
    executeDropQuery
    echo "recreating table in stage with new strcuture"
    executeCreateTable
    subject="Redshift prod to stage | Table structure inconsistent exception"
    message="$schemaName.$tableName have inconsistent table structure on production and stage. still, we have modified the strcuture on stage to match it with production."
    sendMail
  fi
}

getTableStructureStage(){
     sql="SELECT count(*) FROM information_schema.columns WHERE table_schema = '$schemaName' and table_name = '$tableName';"
     executeQueryAndGetResults "${sql}"
     countStageColumn=`echo "$results"`
     echo Stage column count is $countStageColumn
}

getTableStructureProd(){
     sql="SELECT count(*) FROM information_schema.columns WHERE table_schema = '$schemaName' and table_name = '$tableName';"
     executeQueryAndGetResults "${sql}"
     countProdColumn=`echo "$results"`
     echo prod column count is $countProdColumn
}


getTabledef(){

     sql="select ddl from admin.v_generate_tbl_ddl where schemaname = '$schemaName' and tablename= '$tableName' order by seq asc"
     executeQueryAndGetResults "${sql}"
     echo "results are $results"
     tableDefQuery=`echo "$results"`
}

###############checking Table Size#######

CheckTableDataSize(){

  sql="select size from SVV_TABLE_INFO where \"table\" = '$tableName' and schema = '$schemaName';"
  echo $sql

  executeQueryAndGetResults "${sql}"
  tablesizeresult=`echo $results`
  echo "Size of table is $tablesizeresult"
  findDateColumn

    if [[ $tablesizeresult -le 500 ]]; then
        echo "$tableName size is less than 500"
        echo Hence proceeding further
        executeUnloadQuery
    elif [[ $isDateParameterExists -eq '1' ]]; then
         echo "$tableName size is more than 500 and it has date parameter"
         dateColumn=`echo "$tableDefQuery" | grep -ie ".*_date" | cut -d ',' -f2 | head -n 1 | cut -d ' ' -f1`
         sql="SELECT * FROM $schemaName.$tableName WHERE $dateColumn >= DATEADD(MONTH, -6, GETDATE())"
         echo "sql to execute is $sql"
         executelimitedUnloadQuery "${sql}"
    else
         echo "$tableName size is more than 500 and it doesn't have date parameter - Not allowed greater than 500 MB"
         echo sending mail
         subject="Redshift prod to stage | Oversize Exception "
         useremailid="${BUILD_USER_EMAIL}"
         user=`echo ${BUILD_USER} | cut -d '.' -f1`
         echo "useremailid is $useremailid"
         message="Hi ${user^} <br><br> This request can not be processed as <b> $tableName table size is greater than 500 MB </b> <br> Please reach out to devops if this needs to be processed exceptionally.  <br><br> Regards <br> DevOps Team"
         sendMail
         exit 1
    fi

}

findDateColumn(){
    echo 'Checking if any date column is present in table'
    dateParameter=`echo "$tableDefQuery" | grep -i -e "creat.*date" | awk '{print $1}' | sed 's/,//g'`
    echo "dateParameter is $dateParameter"

    if [[ `echo "$dateParameter" | wc -m` -gt 5 ]]; then
        echo "Found date parameter $dateParameter"
        isDateParameterExists=1;
    else
        echo 'No date parameter exists'
        isDateParameterExists=0;
    fi
}

############################### Sending Mail Function ###############

sendMail(){
        profile="prod"
        getSSMParameters
        aws ses send-email \
        --from "$fromEmail" \
        --destination "ToAddresses=$useremailid","CcAddresses=$leadsMailList" \
        --message "Subject={Data=$subject,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$message ,Charset=utf8}}" \
        --profile $profile

}

#############Create Table Feature ########

executeCreateTable(){
    sql="$tableDefQuery"
    echo checking query create table $sql
    executeQueryAndGetResults "${sql}"
}


############################# Main Function ###########################
#######################################################################

for tableName in $(echo $tableNames | sed "s/,/ /g")
do
    ################## Set variables for PROD #########

    profile="prod"

    getConnectionDetails

    s3FolderName="temp-space/$dbName/$schemaName/$tableName/$todayDate/"

    echo "s3 folder name is $s3FolderName"

    ################## Getting def from PROD #########

    echo "Fetching metadata of table"

    getTabledef

    getTableStructureProd

    echo "Checking size of table"

    CheckTableDataSize

    echo "Copying data from PROD S3 to Stage S3..."

    executeAwsS3CopyQuery

    ######Switching to AWS Stage ######

    profile="stage"

    ### Connection to AWS Stage ###

    getConnectionDetails

    checkIfTableExists

    ### Copy to RedShift #####

    echo "Loading data into stage redshift"
    executeStageS3toRedShift

done

######## Cleanup

echo "Working on cleanup"

s3CleanUp

rm -rf ./tmp*
