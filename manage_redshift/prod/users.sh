#!/bin/bash

filename=users_list.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage

existinguserlistssm=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value`


	##Get all the existing user list
	usersql="select usename from pg_user;"
	userlistdb=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$usersql"`
	echo "$userlistdb"

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else


			echo "I am creating user for $line"
			username=`echo $line | cut -d ' ' -f1`
		  echo "Username is $username"
			default_group=`echo $line | cut -d ' ' -f2`
		  echo "default_group is $default_group"
			userexistflagssm=`echo $existinguserlistssm | grep -e $username | wc -l`
			isuserexistsindb=`echo $userlistdb | grep -e $username | wc -l`
			if [[ $isuserexistsindb -gt 0 ]]; then #if 2
							#statements
							echo "User $username already exists in db"
							#break;
			else #else 2

					isbatchuser=`echo $username | grep -e batch | wc -l`
					if [[ $isbatchuser -gt 0  ]]; then #if3
								#statements
								echo "User is batch user "
								isbatchuserexistsssm=`aws ssm get-parameter --name "/a2i/prod/redshift/users/$username" --with-decryption --profile prod --output text --query Parameter.Value | wc -l`
								if [[ $isbatchuserexistsssm -gt 0 ]]; then #if4
											#statements
											echo "SSM entry for $username already exists"
											password=`aws ssm get-parameter --name "/a2i/prod/redshift/users/$username" --with-decryption --profile prod --output text --query Parameter.Value`
											echo "Password for batch user is $password"
											## Creating user in redshift
											sql="create user $username with password '"$password"' in group $default_group"
											echo "sql is $sql"
											psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
								else #else 4
											echo "Creating entry in SSM "
											echo "Modifying SSM to include the new user "
														{
																	echo "Generating random password for user $username"
																	##Generate Passowrd for user
																	p1=`echo $username | cut -d "_" -f1`
																	#echo "$p1"
																	p1+="@R"
																	p2=`date +%M%S`
																	#echo "$p2"
																	password="${p1}${p2}"
																	echo "Passowrd is $password"
														 }

											  aws ssm put-parameter --name "/a2i/prod/redshift/users/$username" --value "$password" --type SecureString --profile prod
												## Creating user in redshift
												sql="create user $username with password '"$password"' in group $default_group"
												echo "sql is $sql"
												psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
									fi #if4

					else #else 3
								if [[ $userexistflagssm -gt 0 ]]; then #if5
										#statements
										echo "User already exists in SSM"
										password=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value | grep -e $username`
										password=`echo $password | cut -d " " -f2-`
										#echo "Passowrd for $username is $password"
										## Creating user in redshift
										sql="create user $username with password '"$password"' in group $default_group"
										echo "sql is $sql"
										psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
								else #else 5
											echo "Modifying SSM to include the new user "
											{
														echo "Generating random password for user $username"
														##Generate Passowrd for user
														p1=`echo $username | cut -d "_" -f1`
														#echo "$p1"
														p1+="@R"
														p2=`date +%M%S`
														#echo "$p2"
														password="${p1}${p2}"
														echo "Passowrd is $password"
											 }

											existinguserlistssmssm=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value`

											newuserlist="${existinguserlistssmssm}"
											newuserlist+="\n"
											newuserlist+="$username $password"

											newuserlist=`echo -e "$newuserlist"`
											echo "New users list is $newuserlist"

											##Updating parameter in SSM
											aws ssm put-parameter --name "/a2i/infra/redshift_prod/users" --value "$newuserlist" --overwrite --type SecureString --profile prod

											## Creating user in redshift
											sql="create user $username with password '"$password"' in group $default_group"
											echo "sql is $sql"
											psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
								fi #if 5
				fi  #if 3
	fi # if 2
	fi #if1
done < $filename
