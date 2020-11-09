#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

if [ "$1" ]; then
    echo 'Argument is not empty - will consider the same'
    userMail="$1"
    env='stage'
    userName=`echo $userMail | cut -d '@' -f1`
    echo "Username is $userName and mail is $userMail"
elif [[ "$userName" ]]; then
    echo 'Argument is empty - will consider default parameter'
else
    echo 'No userName is provided - exiting'
    exit 1;
fi

    baseDN='dc=a2i,dc=infra'
    echo 'Pulling master passowrd for LDAP'
    masterPassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
    masterUserName="cn=admin,$baseDN"
    echo 'Pulling bind passowrd for LDAP'
    bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
    binduser="uid=ldap,$baseDN"
    ldapuri="ldap://ldap.hyke.ae:389"
    ldapUserGroup="cn=ldap-basic,ou=groups,${baseDN}"

#######################################################################
############################# Generic Code ############################
#######################################################################

getSSMParameters(){

    echo "Pulling parameters from SSM for $profile environment"
    fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
    toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
    leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  	devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

createUser(){

    localUserName="$userName"
    existinguserlist=`ldapsearch -x -w "$bindpassword" -b "$baseDN" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" cn | grep -e '^cn:' | cut -d':' -f2`
    #echo "$existinguserlist"
    HIGHEST_UID=$(ldapsearch -x -w "$bindpassword" -b "$baseDN" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" uidnumber | grep -e '^uid' | cut -d':' -f2 | sort | tail -1)
    let userID=HIGHEST_UID+1
    echo "Highest UID is $HIGHEST_UID"

    ldapPassword=`perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..9'`
    #ldapPassword=`"echo $ldapPassword"`
    ldapPassword=`echo "${ldapPassword}"`

        groupID=519;
        localGivenName=`echo $localUserName | cut -d '.' -f1`
        userCN="$localUserName"
        userSN=`echo $localUserName | cut -d '.' -f2`
        echo "userCN is $userCN and userSN is $userSN";

LDIF=$(cat<<EOF
dn: cn=${localUserName},ou=users,${baseDN}
changetype: add
uid: ${localUserName}
cn: ${userCN}
sn: ${userSN}
givenName: ${localGivenName}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
userPassword: ${ldapPassword}
loginShell: /bin/bash
uidNumber: ${userID}
gidNumber: ${groupID}
homeDirectory: /home/users/${localUserName}
mail: ${userMail}

dn: ${ldapUserGroup}
changetype: modify
add: memberuid
memberuid: ${localUserName}

EOF
)
        echo "Adding LDAP entries for $localUserName with password "
        echo "$LDIF" | ldapmodify -x -c -D "$masterUserName" -w $masterPassword  -H $ldapuri

        echo "Setting SSM LDAP parameter for $localUserName in infra account"
        aws ssm put-parameter \
              --name /tmp/infra/ldap/${localUserName} \
              --description "This is tempporary ldap password entry for ${localUserName}" \
              --value "${ldapPassword}" \
              --type SecureString \
              --overwrite \
              --profile stage
}

#######################################################################
############################# Main Function ###########################
#######################################################################

createUser

#############################
########## CleanUp ##########
#############################
