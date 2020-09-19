#!/bin/bash
#dated 18june 2020 ####
#Script to add user in temp LDAP group ####
#Author : Ravi Tomar ####

###################### Variable Declaration ############################
#toolName='jenkins'
#emailid='ravi.tomar@intsof.com'
groupname=`echo temp-${toolName}-admin`
username=`echo $emailid | cut -d '@' -f1`
organization=`echo $emailid | cut -d '@' -f2 | cut -d '.' -f1 | tr [a-z] [A-Z]`
firstName=`echo $emailid | cut -d '.' -f1 | tr [a-z] [A-Z]`
environment=`echo $env | tr [a-z] [A-Z]`
lastName=`echo $emailid | cut -d '@' -f1 | cut -d '.' -f2 | tr [a-z] [A-Z]`
basedn='dc=a2i,dc=infra'
masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
masterusername="cn=admin,$basedn"
bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
binduser="uid=ldap,$basedn"
ldapuri="ldap://ldap.a2i.infra:389"

############################### Checking Provided Group Exists or not ###############

ldapgroupcheck(){
existinggrouplist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixgroup)" cn|grep -e '^cn:' | cut -d':' -f2| grep $groupname`
}

############################# Creating lidif file of provided group ####################
createFile(){
cat <<EOF > group.ldif
dn: cn=$groupname,ou=groups,$basedn
changetype: modify
add: memberuid
memberuid:$username
EOF
}

############################# Sending Email ############################################

sendingMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=$emailid","CcAddresses=ravi.tomar@intsof.com,yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data= LDAP $toolName Acess Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi $firstName <br> <br> LDAP $toolName access has been provisioned to you.<br><br>Please check<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile stage

}

##########################   Main Function ###############################################

ldapgroupcheck
createFile
if [[ $existinggrouplist -eq $groupname ]]; then

        echo "$group_name group exists Hence Proceeding"
        #cat group.txt > $group.ldif
        adduser=`ldapmodify -x -c -D "$masterusername" -w "$masterpassword" -f "./group.ldif" -H $ldapuri`
        if [[ $? == 0 ]]; then
             echo "LDAP Access provisioned to $firstName on $groupname"
             sendingMail
        else
             echo "$firstName on $groupname already added"
        fi
else
        echo "$group_name group does not exists Hence Exiting"
        exit 1
fi
