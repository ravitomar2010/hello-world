#!/bin/bash

filename=modify_groups.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage

echo "Started modify_groups script"

while read line; do
  if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
    groupname=`echo $line | cut -d ' ' -f1`
    echo "I am modifying group $groupname"

    usermembers=`echo $line | cut -d ' ' -f2-`
    echo "List of users are $usermembers"

    sql="alter group $groupname add user $usermembers"
    echo "sql is $sql"

    psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"

  fi
done < $filename
