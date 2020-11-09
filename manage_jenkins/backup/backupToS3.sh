#!/bin/bash

node=`hostname | cut -d '.' -f1`
bucket="a2i-stage-backup"
hour=`date +%H`
year=`date +%Y`
month=`date +%b`
day=`date +%d`
profile='stage'

echo "hour is $hour day is $day month is $month and year is $year"

zip -r /data/jenkins_backup/fullBackup.zip /data/home/jenkins/

aws s3 mv /data/jenkins_backup/fullBackup.zip s3://$bucket/jenkins/${year}/${month}/${day}/${hour}/fullBackup.zip --profile $profile

zip -r /data/jenkins_backup/thinBackup.zip /data/jenkins_backup/

aws s3 mv /data/jenkins_backup/thinBackup.zip s3://$bucket/jenkins/${year}/${month}/${day}/${hour}/thinBackup.zip --profile $profile

rm -rf /data/jenkins_backup/*
