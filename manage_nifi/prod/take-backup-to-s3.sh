#!/bin/bash

node="node-to-replace"
bucket="a2i-stage-backup"
hour=`date +%H`
year=`date +%Y`
month=`date +%b`
day=`date +%d`

echo "hour is $hour day is $day month is $month and year is $year"

aws s3 cp /usr/local/nifi/conf/flow.xml.gz s3://$bucket/nifi/$year/$month/$day/$hour/$node/flow.xml.gz
aws s3 cp /usr/local/nifi/authorizations.xml s3://$bucket/nifi/$year/$month/$day/$hour/$node/authorizations.xml
aws s3 cp /usr/local/nifi/users.xml s3://$bucket/nifi/$year/$month/$day/$hour/$node/users.xml
aws s3 cp /usr/local/nifi/conf/nifi.properties s3://$bucket/nifi/$year/$month/$day/$hour/$node/nifi.properties
aws s3 cp /usr/local/nifi/conf/authorizers.xml s3://$bucket/nifi/$year/$month/$day/$hour/$node/authorizers.xml
