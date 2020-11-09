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

/usr/bin/sqoop import --connect jdbc:oracle:thin:@172.27.55.33:1531/axms --username XXSELDATA --password S3ju2019 \
--query "select a.*, To_Date(To_Char(Sysdate, 'MM/DD/YYYY HH24:MI:SS'), 'MM/DD/YYYY HH24:MI:SS') ingestion_tsp from apps.xla_trial_balances a WHERE \$CONDITIONS" \
--delete-target-dir --target-dir s3a://axiom-stage-data/a2i/stage1/ERP/FINANCE/MASTER/XLA_TRIAL_BALANCES/ \
--fields-terminated-by '|' --split-by SOURCE_ENTITY_ID -m 1 \
--hive-drop-import-delims --enclosed-by '"' --null-string '\\N' --null-non-string '\\N' -m 10
#--map-column-java CCMR_CASE_DESCRIPTION=String -m 10

echo "Done with the execution"
