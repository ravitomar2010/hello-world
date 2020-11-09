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

echo "Starting with the execution for OM_SALES_SERIAL"

/usr/bin/sqoop import --connect \
jdbc:oracle:thin:@axiom-db.cffm1swmuki3.eu-west-1.rds.amazonaws.com:1521/AXIOM \
--username ro_user --password M3VKnGv \
--query "SELECT a.*,extract(MONTH from a.CREATED_DATE) create_month, \
EXTRACT(YEAR FROM a.CREATED_DATE) create_year, \
(a.SOR_ID_SEQ||a.SOD_ID_SEQ||a.SLS_SERAIL) as primary_key_om_sales_serial \
FROM OM.OM_SALES_SERIAL a where EXTRACT(YEAR FROM a.CREATED_DATE) = '2020' \
and sor_id_seq in (select sor_id_seq from OM.OM_SALES_ORDER \
WHERE \$CONDITIONS and EXTRACT(YEAR FROM a.CREATED_DATE) = '2020' \
and EXTRACT(MONTH FROM a.CREATED_DATE) >= EXTRACT(MONTH FROM SYSDATE)-1 \
and sor_delivered_status = 'D' and ORT_SEQ IN (1,2))" \
--delete-target-dir --target-dir s3a://S3_BUCKET_TO_REPLACE/S3_FOLDER_TO_REPLACE \
--fields-terminated-by '\001' --hive-drop-import-delims  \
--optionally-enclosed-by '\' --split-by a.SOR_ID_SEQ||a.SOD_ID_SEQ||a.SLS_SERAIL \
--null-non-string '0'

echo "Done with the execution for OM_SALES_SERIAL"
