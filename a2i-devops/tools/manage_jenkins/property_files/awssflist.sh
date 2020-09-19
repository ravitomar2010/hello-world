#!/bin/bash
env=$1
filename="/data/extralibs/aws/stepfunctions/$env/sf_list.txt"
sflist=`aws stepfunctions list-state-machines --profile $env --query stateMachines[*].name --output text |tr -s '[:space:]' '\n'`
#echo $userlist
IFS=" " echo "${sflist[*]}" > $filename
