#!/bin/bash

filename=users_list.txt
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"
existinguserslist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" cn | grep -e '^cn:' | cut -d':' -f2`

echo "Users list is $existinguserslist"
while read line; do
  username=$line
  if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else

    isuserexistsinldap=`echo $existinguserslist | grep -Fx $username | wc -l`

    echo "Creating user for $username"

  fi

done < $filename
