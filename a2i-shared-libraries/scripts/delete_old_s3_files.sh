#!/bin/bash
date_today=$(date +%Y-%m-%d)
threshold=158
date_to_process=$(date +%Y-%m-%d -d "$threshold day ago")
echo "Date To Process is" $date_to_process
echo "Todays date is" $date_today

aws s3 ls --recursive axiom-terraform/ | while read -r line;
       do
        echo $line;
        file_date=`echo $line|awk {'print $1'}`
        file_name=`echo $line|awk {'print $4'}`
        echo $file_date
        if [[ $file_date -gt $date_to_process ]]
           then
            echo "File ko mar do "$file_name
        fi

       done;
