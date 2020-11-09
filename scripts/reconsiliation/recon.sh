#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

date_today=$(date +%d%b%Y)
echo "date is $date_today"
profile='prod'
client='axiom'
s3Bucket=''
s3Folder1="a2i/stage1/OM/RECON/OM_SALES_ORDER"
s3Folder2="a2i/stage1/OM/RECON/OM_SALES_DETAIL"
s3Folder3="a2i/stage1/OM/RECON/OM_SALES_SERIAL"
curr_dir=`pwd`
#echo "$curr_dir"
copyCommand1=''
copyCommand2=''
copyCommand3=''
tempTableQuery="CREATE TABLE om_stage.om_sales_orders_recon_temp as select distinct sor_id_seq,sor_order_no,sor_order_date,sor_delivered_status,created_date,updated_date from om_stage.OM_SALES_ORDER_RECON rec_ord where updated_date < trunc(sysdate)  and  sor_id_seq not in (select sor_id_seq from om_dbo.OM_SALES_ORDER ord where ord.active_flag = 'A');"
unloadQuery=''
diffRecordQuery="update om_stage.OM_SALES_ORDER_recon set updated_date = (select max(updated_date) +interval '1 minute' from om_dbo.OM_SALES_ORDER) where sor_order_no in(select distinct sor_order_no from om_stage.OM_SALES_ORDER_RECON rec_ord where updated_date < trunc(sysdate)  and  sor_id_seq not in (select sor_id_seq from om_dbo.OM_SALES_ORDER ord where ord.active_flag = 'A'))"

#######################################################################
############################# Generic Code ############################
#######################################################################

# getProfile(){
#
#   curr_dir=`pwd`;
#   profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`;
#   echo "profile is $profile";
# }

getConnectionDetails(){
  echo "Fetching connectin details from SSM"
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$client" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    #statements
    redshiftUserName="axiom_rnd"
    s3Bucket='axiom-stage-dwh'
  else
    redshiftUserName="axiom_stage"
    s3Bucket='axiom-stage-data'
  fi
  echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftUserName,$s3Bucket"
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

createS3folder(){
  echo "Creating s3 folders"
  aws s3 cp './emptyfile.txt'  "s3://$s3Bucket/$s3Folder1/" --profile $profile
  aws s3 cp './emptyfile.txt'  "s3://$s3Bucket/$s3Folder2" --profile $profile
  aws s3 cp './emptyfile.txt'  "s3://$s3Bucket/$s3Folder3/" --profile $profile
}

removeTempFileFromS3(){
  echo "Removing temp files"
  aws s3 rm "s3://$s3Bucket/$s3Folder1/emptyfile.txt" --profile $profile
  aws s3 rm "s3://$s3Bucket/$s3Folder2/emptyfile.txt" --profile $profile
  aws s3 rm "s3://$s3Bucket/$s3Folder3/emptyfile.txt" --profile $profile
}

sendNotificationsToDevelopersMail(){
  echo "Sending notification"
  #`aws sns publish --topic-arn "arn:aws:sns:eu-west-1:$accountID:stage-devops-notifications-to-developers"  --message "$final_results" --profile $profile`;
  #python3 ./sendEmailTop100.py
}

prepareSqoopQueryFiles(){

  cp $curr_dir/sqoop1.sh $curr_dir/tmp_sqoop1.sh
  sed -i -e "s/S3_BUCKET_TO_REPLACE/$s3Bucket/g" $curr_dir/tmp_sqoop1.sh
  sleep 2
  sed -i -e "s|S3_FOLDER_TO_REPLACE|${s3Folder1}|g" $curr_dir/tmp_sqoop1.sh

  cp $curr_dir/sqoop2.sh $curr_dir/tmp_sqoop2.sh
  sed -i -e "s/S3_BUCKET_TO_REPLACE/$s3Bucket/g" $curr_dir/tmp_sqoop2.sh
  sleep 2
  sed -i -e "s|S3_FOLDER_TO_REPLACE|${s3Folder2}|g" $curr_dir/tmp_sqoop2.sh

  cp $curr_dir/sqoop3.sh $curr_dir/tmp_sqoop3.sh
  sed -i -e "s/S3_BUCKET_TO_REPLACE/$s3Bucket/g" ./tmp_sqoop3.sh
  sleep 2
  sed -i -e "s|S3_FOLDER_TO_REPLACE|${s3Folder3}|g" ./tmp_sqoop3.sh

}

executeSqoopJobs(){
  echo "Executing sqoop for OM_SALES_ORDER"
  /bin/bash $curr_dir/tmp_sqoop1.sh

  echo "Executing sqoop for OM_SALES_DETAILS"
  /bin/bash $curr_dir/tmp_sqoop2.sh

  echo "Executing sqoop for OM_SALES_SERIAL"
  /bin/bash $curr_dir/tmp_sqoop3.sh

}

prepareCopyCommands(){

  copyCommand1="copy om_stage.OM_SALES_ORDER_RECON from 's3://$s3Bucket/$s3Folder1/' iam_role 'arn:aws:iam::$accountID:role/Redshift-S3-Role' delimiter '\001'"
  copyCommand2="copy om_stage.OM_SALES_DETAIL_RECON from 's3://$s3Bucket/$s3Folder2/' iam_role 'arn:aws:iam::$accountID:role/Redshift-S3-Role' delimiter '\001'"
  copyCommand3="copy om_stage.OM_SALES_SERIAL_RECON from 's3://$s3Bucket/$s3Folder3/' iam_role 'arn:aws:iam::$accountID:role/Redshift-S3-Role' delimiter '\001'"
}

prepareUnloadQuery(){

  unloadQuery="unload ('select * from om_stage.om_sales_orders_recon_temp') to 's3://$s3Bucket/a2i/stage1/OM/RECON/OM_SALES_ORDER_temp_${date_today}_UNLOAD/om_sales_orders_recon' iam_role 'arn:aws:iam::$accountID:role/Redshift-S3-Role' ALLOWOVERWRITE"
  aws s3 rm s3://$s3Bucket/a2i/stage1/OM/RECON/OM_SALES_ORDER_temp_${date_today}_UNLOAD/om_sales_orders_recon/ --recursive --profile $profile
}

#######################################################################
############################# Main Function ###########################
#######################################################################

#Step 1:
getConnectionDetails
#createS3folder
prepareSqoopQueryFiles
executeSqoopJobs

##Step 2:
#### truncate tables
# executeQueryAndGetResults 'truncate table om_stage.OM_SALES_ORDER_RECON;'
# executeQueryAndGetResults 'truncate table om_stage.OM_SALES_DETAIL_RECON;'
# executeQueryAndGetResults 'truncate table om_stage.OM_SALES_SERIAL_RECON;'

##Step 3:
# prepareCopyCommands
# executeQueryAndGetResults "${copyCommand1}"
# executeQueryAndGetResults "${copyCommand2}"
# executeQueryAndGetResults "${copyCommand3}"

# ##Step 4:
# echo "Dropping temporary table"
# executeQueryAndGetResults "drop table IF EXISTS om_stage.om_sales_orders_recon_temp"
# executeQueryAndGetResults "${tempTableQuery}"

##Step 5:
# prepareUnloadQuery
# executeQueryAndGetResults "${unloadQuery}"

##Step 6:
# executeQueryAndGetResults "${diffRecordQuery}"
#
# executeQueryFile "${curr_dir}/insert1.sql"
# executeQueryFile "${curr_dir}/insert2.sql"
# executeQueryFile "${curr_dir}/insert3.sql"

# removeTempFileFromS3

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
echo "Dropping temporary table"
executeQueryAndGetResults "drop table IF EXISTS om_stage.om_sales_orders_recon_temp"
rm -rf ${curr_dir}/tmp*
