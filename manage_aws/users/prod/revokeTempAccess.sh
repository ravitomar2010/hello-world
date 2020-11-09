#!/bin/bash
env=$1
groups=("TempCloudWatchMaster" "TempCloudWatchEventsMaster" "TempLambdaMaster" "TempRedshiftMaster" "TempS3Master" "TempStepFucntionMaster" "TempForeCastMaster")
for group in ${groups[@]}
do
    users+=$(aws iam get-group --group-name $group --output text --query Users[*].UserName --profile $env)
    for user in ${users[@]}
    do
        aws iam remove-user-from-group --user-name $user --group-name $group --profile $env
        [[ $? -eq 0 ]] && echo "User $user removed from group $group on $env" || echo "Unable to find user $user in group $group on $env"
    done
    unset users

done
