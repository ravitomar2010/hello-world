#!/bin/bash

export HADOOP_HOME=/home/hadoop/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native -Djava.security.egd=file:/dev/../dev/urandom"
export SQOOP_HOME=/usr/lib/sqoop export PATH=$PATH:$SQOOP_HOME/bin
export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HADOOP_HOME/share/hadoop/tools/lib/*

sqlQuery=$1

prepareEnv(){
    echo "Preparing environment "
    START_DATE=$(date)
    echo $HOSTNAME
    echo $IS_SNAP_DT;
    SNAP_DT=`date  -d "-7 days" +%m-%d-%Y`
    profile='prod'
    cnt=1
    QRY=`echo "$sqlQuery" | sed 's+WHERE+WHERE \$CONDITIONS+g'`
    echo start "$QRY" end
    if [ "$IS_SNAP_DT" != "NO" ]; then
    echo SNAP_DT=`date +%m-%d-%Y`;
    TGT_DIR_PATH="$TGT_DIR$SNAP_DT";
    echo $TGT_DIR_PATH
    else
    echo "False";
    TGT_DIR_PATH="$TGT_DIR";
    echo $TGT_DIR_PATH;
    fi
    echo -n "Start Execution.."
}

getConnectionDetails(){
  echo "Fetching connection parameter"
  cfConnection=`aws ssm get-parameter --name "/a2i/$profile/cf/connection" --with-decryption --profile $profile --output text --query Parameter.Value`
}

#######################################################################
############################# Main Function ###########################
#######################################################################

prepareEnv
getConnectionDetails


# Need to export the source table on remote cluster to export directory
# # echo -e "The received sql query is \n\n $sqlQuery"
echo -e "I am working on query \n\n $QRY"
echo "Initiating sqoop job"
echo
sqoop import $cfConnection --query "$QRY" --target-dir "s3a://$target_bucket/$TGT_DIR" --fields-terminated-by '\001' --hive-drop-import-delims --optionally-enclosed-by '\' --split-by "$SPLT_BY" --null-non-string '0'
echo
echo "done with sqoop job"

RESULT=$?

END_DATE=$(date)
if [ $RESULT -ne 0 ]; then
  echo "=X="
  echo "Error: SQOOP IMPORT FAILED - $START_DATE to $END_DATE Call to recon_test has returned an error on import $TAB_NAME to $TGT_DIR using. Stopping."
  exit 1
else
  echo -n "SQOOP IMPORT SUCCESSFUL..."
fi
