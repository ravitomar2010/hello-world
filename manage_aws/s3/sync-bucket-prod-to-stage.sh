#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#date_today=$(date +%Y-%m-%d)
date_today=$(date -d "1 day ago" +%Y-%m-%d)
#source_bucket=axiom-stage-data
#destination_bucket=axiom-stage-dwh
#echo "Date Today is "$date_today
file_counter=1;

#######################################################################
############################# Main Function ###########################
#######################################################################

aws s3 ls $source_bucket --recursive --profile stage > file_list.txt

no_of_items=`cat file_list.txt | grep $date_today | wc -l`

echo "I will copy $no_of_items items"

cat file_list.txt | grep $date_today | while read -r line;

do
        file_date=`echo $line|awk {'print $1'}`
        file_name=`echo $line | awk '{out=""; for(i=4;i<=NF;i++){out=out" "$i}; print out}'`
        #echo "file namee is"$file_name
        file_name=`echo $file_name | cut -f2-`
        if [[ ${file_date} == ${date_today} ]]; then
           echo "Copying file number "$file_counter
           echo "Copying s3://$source_bucket/$file_name"
           aws s3 cp "s3://$source_bucket/$file_name" "s3://$destination_bucket/$file_name" --profile stage
        	((file_counter++))
        fi
done

##############################
########## cleanup ###########
##############################

sudo rm -rf file_list.txt
