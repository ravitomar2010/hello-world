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
#dbClient='axiom'
#schemaNames='bi'
############################################

useremailid='ravi.tomar@intsof.com'
echo '' > schemalist.txt
echo '' > inconsistentschema.txt
echo '' > consistentschema.txt
#todayDate=`date +\%Y-\%m-\%d`

#######################################################################
############################# Generic Code ############################
#######################################################################

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
  #echo "$hostName , $portNo , $dbName , $redshiftPassword, $redshiftUserName "
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -qAt "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
    echo "Query result is :$results"
}


#######################################################################
######################### Feature Function Code #######################
#######################################################################

chkTableCountProd(){

      sql="select count(*) from pg_tables where schemaname = '$schemaName'"
      executeQueryAndGetResults "${sql}"
      prodTableCount=`echo "No of tables in prod is $results"`

}
chkTableCountStage(){

      sql="select count(*) from pg_tables where schemaname = '$schemaName'"
      executeQueryAndGetResults "${sql}"
      stageTableCount=`echo "$results"`

}

executeDropQuery() {
      tableName=$1
      tableDrop="drop table $schemaName.$tableName cascade"
      executeQueryAndGetResults "${tableDrop}"
}


getTabledef(){
     sql="select ddl from admin.v_generate_tbl_ddl where schemaname = '$schemaName'"
     executeQueryAndGetResults "${sql}"
     if [[ `echo "$results"| wc -m` -gt 1 ]]; then
        echo "$schemaName has tables Hence processing"
        tableDefQuery="$results"
        ##################### Set variables for stage #########
        profile="stage"
        echo "Connectiong to $profile profile now"
        getConnectionDetails
        chkTableCountStage
        #echo "dropping all tables in $schemaName of $profile environment"
        ##################### Drooping all tables of each schema on stage #########
        #dropAllTable
        echo "creating all tables in $profile environment"
        ##################### Creating all tables of each schema on stage #########
        createAllTable
        echo ----------------------------------------------
        echo "$schemaName migration completed"
     else
        echo "$schemaName does not have any tables"

     fi
}

createAllTable(){
#echo "Creating all tables in stage of $schemaName"
executeQueryAndGetResults "${tableDefQuery}"
echo "Created Tables"
if [[ $prodTableCount -le $stageTableCount ]]; then
  echo "<b>$schemaName</b> | prod count:<b>$prodTableCount</b> | stage count:<b>$stageTableCount</b><br>" >> consistentschema.txt
else
  echo "<b>$schemaName</b> | prod count:<b>$prodTableCount</b> | stage count:<b>$stageTableCount</b><br>" >> inconsistentschema.txt
fi

}

dropAllTable(){

  sql=" select distinct(t.table_name) from information_schema.tables t where t.table_schema = '$schemaName'"
  #echo "query is $sql"
  executeQueryAndGetResults "${sql}"
  tables=$results
  echo $tables
  for table in ${tables[@]}
  do
    executeDropQuery "$table"
  done
}

###############################PrePare Output #################################

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "Hi All <br><br>This is to inform you that below list of Schema tables attempted to migrate on Stage environment" >> tmpFinalOP.txt

  echo "<br>==========================================================" >> tmpFinalOP.txt

  cat schemalist.txt >> tmpFinalOP.txt
  echo "<br>==========================================================" >> tmpFinalOP.txt
  echo "<br><b>Below Schemas Migrated successfully Report:</b><br>" >> tmpFinalOP.txt
  cat consistentschema.txt >> tmpFinalOP.txt
  echo "<br>==========================================================" >> tmpFinalOP.txt
  echo "<br><b>Below Schemas Report found inconsistent having differences in tables count on PROD/STAGE:</b><br>" >> tmpFinalOP.txt
  cat inconsistentschema.txt >> tmpFinalOP.txt
  echo "==========================================================" >> tmpFinalOP.txt

  echo "<br>Please reach out to devops in case of any concerns <br>Regards<br>DevOps Team" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

############################### Sending Mail Function ###############

sendMail(){

        aws ses send-email \
        --from "$useremailid" \
        --destination "ToAddresses=sandeep.sunkavalli@tothenew.com","CcAddresses=yogesh.patil@axiomtelecom.com,$useremailid,axiomdipoffshoredev@intsof.com,raj.bhalla@intsof.com" \
        --message "Subject={Data=DEV Maintenance Update | DB $dbClient ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
        --profile $profile

}


############################# Main Function ###########################
#######################################################################
for schemaName in $(echo $schemaNames | sed "s/,/ /g")
do
    ################## Set variables for PROD #############
    echo "<b>$schemaName</b><br>" >> schemalist.txt
    echo ---------------------------------------
    echo "i am migrating $schemaName now"
    profile="prod"
    getConnectionDetails
    chkTableCountProd
    ################## Getting def from PROD ##############
    echo "Fetching table definition from $profile"
    getTabledef

done
prepareOutput
#sendMail
