#!/bin/bash

node=`hostname | cut -d '.' -f1`
bucket="a2i-stage-backup"
hour=`date +%H`
year=`date +%Y`
month=`date +%b`
day=`date +%d`

echo "hour is $hour day is $day month is $month and year is $year"

aws s3 cp /usr/local/nifi/conf/ s3://$bucket/nifi/$year/$month/$day/$hour/$node/conf/ --recursive
aws s3 cp /usr/local/nifi/authorizations.xml s3://$bucket/nifi/$year/$month/$day/$hour/$node/authorizations.xml
aws s3 cp /usr/local/nifi/users.xml s3://$bucket/nifi/$year/$month/$day/$hour/$node/users.xml
