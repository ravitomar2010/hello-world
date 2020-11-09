#!/bin/bash


filename=groups_list.txt
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"
existinggrouplist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixgroup)" cn | grep -e '^cn:' | cut -d':' -f2`

while read line; do
	if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
			echo "Working I found group name $line"
      group_name=$line;
      #  HIGHEST_UID=$(ldapsearch -x -w "$LDAPPASS" -b "${LDAP_ACCOUNTS_DN}" -D "${LDAP_BIND_DN}" "(objectclass=posixaccount)" uidnumber | grep -e '^uid' | cut -d':' -f2 | sort | tail -1)
      ifgroupexists=`echo $existinggrouplist | grep $group_name | wc -l`
      if [[ $ifgroupexists -gt 0 ]]; then
        #statements
        echo "$group_name group already exists"
      else
          echo "$group_name does not exists Need to create group"
          highest_gid=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixgroup)" gidNumber | grep -e '^gidNumber' | cut -d':' -f2 | tail -1`
          ((highest_gid++))
          #echo "New Gid will be $highest_gid"

          sed "s/ldap_group_name_replace_me/$group_name/g" ./templates/group.ldif > tmp_group1.txt
          sed "s/gid_replace_me/$highest_gid/g" ./tmp_group1.txt > tmp_group2.txt
          sed "s/openldap_server_base_dn_replace_me/$basedn/g" ./tmp_group2.txt > tmp_group3.txt

          cat tmp_group3.txt > $group_name.ldif

          ldapadd -x -c -D "$masterusername" -w $masterpassword -f "./$group_name.ldif" -H $ldapuri
      fi

	fi
done < $filename

##Section to delete groups if not required

echo $existinggrouplist > tmp_existinggrouplist.txt

for word in $(<tmp_existinggrouplist.txt)
do
    entrystillexists=`cat groups_list.txt | grep -Fx $word  | wc -l`
    echo "For $word value is $entrystillexists"

    if [[ $entrystillexists -gt 0 ]]; then
      #statements
      echo "Group is valid"
    else
      echo "Need to delete the group $word"
      ldapdelete -x -D "$masterusername" -w "$masterpassword"  -H $ldapuri "cn=$word,ou=groups,$basedn"
    fi
done


##Cleanup
rm -rf *.ldif
rm -rf tmp*
