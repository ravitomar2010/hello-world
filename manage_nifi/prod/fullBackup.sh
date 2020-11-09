#!/bin/bash

node=`hostname | cut -d '.' -f1`
bucket="a2i-prod-backup"
hour=`date +%H`
year=`date +%Y`
month=`date +%b`
day=`date +%d`

echo "hour is $hour day is $day month is $month and year is $year"



aws s3 cp /usr/local/nifi/conf/flow.xml.gz s3://$bucket/nifi/$year/$month/$day/$hour/$node/flow.xml.gz
