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

echo "Starting with the execution"

/usr/bin/sqoop import --connect jdbc:oracle:thin:@172.27.55.56:1521/ACTIVE --username XXSELDATA --password S3ju2019 \
--query "SELECT * FROM CRM.VW_TMS_CASE_DETAIL_REPORT WHERE \$CONDITIONS" \
--delete-target-dir --target-dir s3a://axiom-stage-data/a2i/stage1/ACTIVE/MASTER/VW_TMS_CASE_DETAIL_REPORT/ \
--fields-terminated-by '~' --split-by CCMR_CASE_NUMBER -m 1 \
--hive-drop-import-delims --enclosed-by '"' --null-string '\\N' --null-non-string '\\N' \
--map-column-java CCMR_CASE_DESCRIPTION=String -m 10

echo "Done with the execution"
