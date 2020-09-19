#!/bin/bash
env=$1
filename="/data/extralibs/aws/$env/emails_list.txt"

emaillist=`aws iam list-users --profile $env |grep '"UserName": "'| cut -d ':' -f2| sed 's/"//g' | sed  's/,//g'| sed 's/^[[:space:]]*//g'`
#echo $userlist
IFS=" " echo "${emaillist[*]}" > $filename
