filename=groups_list.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage

existinggrouplist=``;

#Get the list of existing schemas
sql="select groname from pg_group;"
existinggrouplist=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`

while read line; do
	if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
			group_name=$line
			isgroupexists=`echo $existinggrouplist | grep -e $group_name| wc -l`

					if [[ $isgroupexists -gt 0 ]]; then
						#statements
						 echo "Group $group_name already exists"

					else
							echo "I am creating group $line"
						 # group_name=$line
						  sql="create group $group_name"
						  echo "sql is $sql"
							psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
					fi
	fi
done < $filename
