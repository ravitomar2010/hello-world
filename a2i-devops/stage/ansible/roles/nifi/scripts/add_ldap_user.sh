#!/bin/bash
#
# add_user.sh: Add user to LDAP
# Author: Nick Sabine
#

# Defaults
LDAP_BASE="dc=a2i,dc=infra"
LDAP_ACCOUNTS_DN="ou=users,${LDAP_BASE}"
LDAP_USER_GROUP="cn=ldap-basic,ou=groups,${LDAP_BASE}"
LDAP_ADMIN_GROUP="cn=admin_group,ou=groups,${LDAP_BASE}"
LDAP_BIND_DN="cn=admin,${LDAP_BASE}"
USER_NAME=
USER_CN=
USER_SN=
USER_ID=
GROUP_ID=1000
IS_ADMIN=
LDAP_OPTIONS=

usage()
{
cat << EOF
usage $0 options

This script creates a user in LDAP

OPTIONS
  -h         Show this message
  -n <name>  Username
  -c <cn>    User CN
  -s <sn>    User SN
  -i <uid>   User ID Number (default: next available number)
  -g <gid>   Primary group ID Number (default: $GROUP_ID)
  -a         Add user to administrator group
  -D         LDAP Bind DN (default: $LDAP_BIND_DN)
  -b         LDAP Base (default: $LDAP_BASE)
  -P         LDAP Accounts DN (default: $LDAP_ACCOUNTS_DN)
  -U         LDAP User Group DN (default: $LDAP_USER_GROUP)
  -A         LDAP Admin Group DN (default: $LDAP_ADMIN_GROUP)
  -t         Test. Show what would be done, but don’t actually modify LDAP.
EOF
}

error_ldap() {
  echo "Error: Error connecting to LDAP or uninitialized user tree"
}

while getopts "hn:c:s:i:g:aD:b:P:U:A:t" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    n)
      USER_NAME=$OPTARG
      ;;
    c)
      USER_CN=$OPTARG
      ;;
    s)
      USER_SN=$OPTARG
      ;;
    i)
      USER_ID=$OPTARG
      ;;
    g)
      GROUP_ID=$OPTARG
      ;;
    a)
      IS_ADMIN=1
      ;;
    D)
     LDAP_BIND_DN=$OPTARG
     ;;
    b)
     LDAP_BASE=$OPTARG
     ;;
    P)
     LDAP_ACCOUNTS_DN=$OPTARG
     ;;
    U)
      LDAP_USER_GROUP=$OPTARG
      ;;
    A)
      LDAP_ADMIN_GROUP=$OPTARG
      ;;
    t)
      LDAP_OPTIONS+=" -n "
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

if [ -z $USER_NAME        ] ||
   [ -z $USER_CN          ] ||
   [ -z $USER_SN          ] ||
   [ -z $GROUP_ID         ] ||
   [ -z $LDAP_BIND_DN     ] ||
   [ -z $LDAP_ACCOUNTS_DN ] ||
   [ -z $LDAP_USER_GROUP  ] ||
   [ -z $LDAP_ADMIN_GROUP ]
then
  usage
  exit 1
fi

read -p "LDAP Manager Password: " -s LDAPPASS
echo


# If USER_ID not supplied, find next using ldap query
if [ -z $USER_ID ]
then
  HIGHEST_UID=$(ldapsearch -H "ldap://ldap.a2i.infra:389" -x -w "$LDAPPASS" -b "${LDAP_ACCOUNTS_DN}" -D "${LDAP_BIND_DN}" "(objectclass=posixaccount)" uidnumber | grep -e '^uid' | cut -d':' -f2 | sort | tail -1)
  if [ -z $HIGHEST_UID ]
  then
    error_ldap
    exit 1
  fi
  let USER_ID=HIGHEST_UID+1
fi

read -p "${USER_NAME} Initial Password: " -s USER_CLEARTEXT_PASS
echo

USER_PASS=$(slappasswd -h {SSHA} -s $USER_CLEARTEXT_PASS)

unset USER_CLEARTEXT_PASS

CHANGE_DATE=$(echo "$(date +%s) / ( 60 * 60 * 24 )" | bc)

LDIF=$(cat<<EOF
dn: cn=${USER_NAME},${LDAP_ACCOUNTS_DN}
changetype: add
uid: ${USER_NAME}
cn: ${USER_CN}
sn: ${USER_SN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
userPassword: ${USER_PASS}
shadowLastChange: ${CHANGE_DATE}
shadowMax: 99999
shadowWarning: 7
loginShell: /bin/bash
uidNumber: ${USER_ID}
gidNumber: ${GROUP_ID}
homeDirectory: /home/${USER_NAME}

dn: ${LDAP_USER_GROUP}
changetype: modify
add: memberuid
memberuid: ${USER_NAME}

EOF
)

if [ $IS_ADMIN ]
then
  LDIF+=$(cat<<EOF


dn: ${LDAP_ADMIN_GROUP}
changetype: modify
add: memberuid
memberuid: ${USER_NAME}

EOF
)
fi

echo "--------------------"
echo "Adding ${LDIF}"
echo "--------------------"
echo "$LDIF" | ldapmodify -H "ldap://ldap.a2i.infra:389" -x -w "$LDAPPASS" -D "${LDAP_BIND_DN}" $LDAP_OPTIONS

unset LDAPPASS
