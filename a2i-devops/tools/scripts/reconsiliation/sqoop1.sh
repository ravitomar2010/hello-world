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

echo "Starting with the execution for OM_SALES_ORDER"

/usr/bin/sqoop import --connect \
jdbc:oracle:thin:@axiom-db.cffm1swmuki3.eu-west-1.rds.amazonaws.com:1521/AXIOM \
--username ro_user --password M3VKnGv \
--query "SELECT * FROM (SELECT a.*,extract(MONTH from CREATED_DATE) \
create_month, EXTRACT(YEAR FROM CREATED_DATE) create_year FROM \
(SELECT * FROM OM.OM_SALES_ORDER WHERE \$CONDITIONS and EXTRACT \
(YEAR FROM CREATED_DATE) = '2020' \
and EXTRACT(MONTH FROM CREATED_DATE) >= EXTRACT(MONTH FROM SYSDATE)-1 \
and sor_delivered_status in ('D','R') \
and ORT_SEQ IN (1,2)) a WHERE \$CONDITIONS ) WHERE \$CONDITIONS" \
--delete-target-dir --target-dir s3a://S3_BUCKET_TO_REPLACE/S3_FOLDER_TO_REPLACE \
--fields-terminated-by '\001' --hive-drop-import-delims --optionally-enclosed-by '\' \
--split-by SOR_ID_SEQ --null-non-string '0'

echo "Done with the execution for OM_SALES_ORDER"
