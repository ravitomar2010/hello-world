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

/usr/bin/sqoop import --connect jdbc:oracle:thin:@axiom-db.cffm1swmuki3.eu-west-1.rds.amazonaws.com:1521/AXIOM --username INTF --password intf2018 --query "SELECT *  FROM ORA_OPEN_INVOICE_R12  where \$CONDITIONS" --delete-target-dir --target-dir s3a://axiom-stage-data/a2i/stage1/CF/ONE_DUMP/ORA_OPEN_INVOICE_R12/ --fields-terminated-by '|' --split-by ORA_CUSTOMER_ID -m 1 --hive-drop-import-delims --enclosed-by '"' --null-string '\\N' --null-non-string '\\N' -m 10

echo "Done with the execution"
