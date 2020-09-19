#!/bin/sh
date_today=$(date +%Y-%m-%d)
source_bucket=$1
destination_bucket=$2
echo "Date Today is "$date_today

aws s3 ls --recursive $source_bucket/ --profile stage | while read -r line;
       do
	#echo $line;
	#file_name=`echo $line|awk {'print $1'}`
	#echo $file_name
	file_date=`echo $line|awk {'print $1'}`
        file_name=`echo $line| awk {'print $4$5$6'}`
	if [[ ${file_date} == ${date_today} ]]; then
            echo "Copying "$file_name
	    aws s3 cp s3://$source_bucket/$file_name s3://$destination_bucket/$file_name --profile stage
  fi
done;
