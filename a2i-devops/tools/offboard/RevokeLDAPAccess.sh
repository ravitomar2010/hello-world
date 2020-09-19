#!/bin/bash
#Description: used to remove users from LDAP existinggrouplist

useremail='sameer.panda@intsof.com'

# useremail=$emailid
username=`echo $useremail | cut -d '@' -f1`
user=$username
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"
existinggrouplist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(&(objectClass=posixGroup)(memberUid=$user))" dn | cut -d'=' -f2 | cut -d ',' -f1`
#echo $existinggrouplist
createuserFile(){
cat <<EOF > user.ldif
dn: cn=$user,ou=users,$basedn
changetype: delete
EOF
}

################################################ Deleting user ###################################################

createuserFile
deleteuser=`ldapmodify -x -c -D "$masterusername" -w "$masterpassword" -f "./user.ldif" -H $ldapuri`
echo $deleteuser

############################################### Deleting user from groups ########################################

createFile(){
cat <<EOF > group.ldif
dn: cn=$group,ou=groups,$basedn
changetype: modify
delete: memberuid
memberuid: $user
EOF
}

for group in $existinggrouplist
do
        echo "Removing $user from $group"
        createFile
        deleteuser=`ldapmodify -x -c -D "$masterusername" -w "$masterpassword" -f "./group.ldif" -H $ldapuri`

done
