#!/bin/bash
LAMBDA=`~/assume-role.sh aws lambda list-functions --region eu-west-1 | jq -r ".Functions[].FunctionName" | grep 'axiom-telecom-a2i'`
for name in $LAMBDA
do
	echo '=============================================================================================================='
	echo "Fetching for $name for last 1 day"
	echo '=============================================================================================================='
	~/assume-role.sh ~/lambda-metrics.sh $name 1
done
