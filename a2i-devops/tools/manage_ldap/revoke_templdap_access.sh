#!/bin/bash
#Dated 21 june 2020
#Author: Ravi tomar
#Description: used to remove users from temp LDAP existinggrouplist

############################### Variable Declaration ##############################
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"

############################# Creating lidif file of provided group ####################

createFile(){
cat <<EOF > group.ldif
dn: cn=$group,ou=groups,$basedn
changetype: modify
delete: memberuid
memberuid: $user
EOF
}

############################## Main Function #######################################

groups=("temp-nifi-admin" "temp-jenkins-admin" "temp-hadoop-admin" "temp-grafana-admin")
for group in ${groups[@]}
do
    users+=$(ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL -s sub "(&(objectClass=posixGroup)(cn=$group))" memberUid | grep -e '^memberUid:' | cut -d':' -f2)
    for user in ${users[@]}
    do
        createFile
        deleteuser=`ldapmodify -x -c -D "$masterusername" -w "$masterpassword" -f "./group.ldif" -H $ldapuri`
        [[ $? -eq 0 ]] && echo "User $user removed from group $group" || echo "Unable to find user $user in group $group"
    done
    unset users

done
