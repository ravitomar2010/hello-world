#!/bin/bash

filename=batch_users_list.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage
temp_pass=""

checkConnection(){
  conn_status=`echo "$(timeout 5 telnet $hostname 5439)" | grep 'Escape' | wc -l`
  if [[ $conn_status -eq 1 ]]; then
    #statements
    echo "Connection is working fine "
  else
    echo "Not able to make connection to server $hostname"
    exit 0
  fi
}

getUserList(){
  echo "Getting users list"
  sql="select usename from pg_user;"
  psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql" > temp_batch_users_list.txt
  cat temp_batch_users_list.txt | grep 'batch' > temp_batch_users_list2.txt
  sort temp_batch_users_list2.txt > batch_users_list.txt
}

updatePasswords(){
  echo "Updating passwords"
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Working on user "$line
        temp_entry_count=`aws ssm get-parameter --name "$line" --with-decryption --profile prod --output text --query Parameter.Value | wc -l`
        if [[ $temp_entry_count -eq 1 ]]; then
          #echo "Double entry exists for $line"
          updatePasswordsForDoubleEntry $line
        else
          updatePasswordsForSingleEntry $line
        fi
        echo "Done with user "$line
    fi
  done < $filename

}

updatePasswordsForSingleEntry(){
  echo "Single entry exists"
  local_uname=$1
  echo "Updating password for $local_uname"
  echo "Creating random password"
  generateRandomPassword
  #echo "Creating entry in SSM"
  #echo "Modifying SSM to include the new user "
  new_pass=$temp_pass
  echo "new_pass is $new_pass"

  aws ssm put-parameter --name "/a2i/prod/redshift/users/$local_uname" --value "$new_pass" --type SecureString --overwrite --profile prod
  ## Updating user in redshift
  sql="ALTER USER $local_uname PASSWORD '$temp_pass' "
  echo "sql is $sql"
  psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
}

updatePasswordsForDoubleEntry(){
  echo "Double entry exists"
  local_uname=$1
  echo "Updating password for $local_uname"
  echo "Creating random password"
  generateRandomPassword
  #echo "Creating entry in SSM"
  #echo "Modifying SSM to include the new user "
  new_pass=$temp_pass
  echo "new_pass is $new_pass"
  aws ssm put-parameter --name "/a2i/prod/redshift/users/$local_uname" --value "$new_pass" --type SecureString --overwrite --profile prod
  aws ssm put-parameter --name "$local_uname" --value "$new_pass" --type SecureString --overwrite --profile prod

  ## Updating user in redshift
  sql="ALTER USER $local_uname PASSWORD '$temp_pass' "
  echo "sql is $sql"
  psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"

}

choose() {
  echo ${1:RANDOM%${#1}:1} $RANDOM;
}

generateRandomPassword(){
  pass="$({
  choose '!@#$%&'
  choose '0123456789'
  choose 'abcdefghijklmnopqrstuvwxyz'
  choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  for i in $( seq 1 $(( 4 + RANDOM % 12 )) )
     do
        choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
     done
  } | sort -R | awk '{printf "%s",$1}')"

  pass=`echo $pass | cut -c -8`
  p1='@Rp'
  p2=`date +%S`
  pass="${pass}${p1}${p2}"
  temp_pass=$pass
  #echo "Password is $pass"
  #return "$pass"
}

###############################################################################
################################## Initiation ################################
###############################################################################


checkConnection
getUserList
updatePasswords


## Cleanup

echo "Working on clean up"
rm -rf temp_batch_users_list.txt
rm -rf temp_batch_users_list2.txt
rm -rf batch_users_list.txt
