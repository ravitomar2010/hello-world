#!/bin/bash
filename="/data/extralibs/ldap/users_list.txt"
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"
userlist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixAccount)" cn | grep -e '^cn:' | cut -d' ' -f2`
#echo $userlist
IFS=" " echo "${userlist[*]}" > $filename
