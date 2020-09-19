#!/bin/bash

# user=$emailid
# profile=$env
user='sameer.panda@intsof.com'
profile='stage'

echo "User: $user Environment: $profile"

########################### Detecting user policies ##########################################

user_policies=$(aws iam list-user-policies --user-name $user --query 'PolicyNames[*]' --profile $profile --output text)

############################# Deleting user policies ##########################################

echo "Deleting user policies: $user_policies"
for policy in $user_policies ;
do
  echo "aws iam delete-user-policy --user-name $user --profile $profile --policy-name $policy"
  aws iam delete-user-policy --user-name $user --profile $profile --policy-name $policy
done

############################# Detecting user attached policies ##########################################

user_attached_policies=$(aws iam list-attached-user-policies --user-name $user --query 'AttachedPolicies[*].PolicyArn' --profile $profile --output text)

############################# Deleting user attached policies ##########################################

echo "Detaching user attached policies: $user_attached_policies"
for policy_arn in $user_attached_policies ;
do
  echo "aws iam detach-user-policy --user-name $user --profile $profile --policy-arn $policy_arn"
  aws iam detach-user-policy --user-name $user --profile $profile --policy-arn $policy_arn
done

############################ Detecting user attached groups ##############################################

user_groups=$(aws iam list-groups-for-user --user-name $user --query 'Groups[*].GroupName' --profile $profile --output text)

############################ Deattching user attached groups ##############################################

echo "Detaching user attached group: $user_groups"
for group in $user_groups ;
do
  echo "aws iam remove-user-from-group --user-name $user --profile $profile --group-name $group"
  aws iam remove-user-from-group --user-name $user --profile $profile --group-name $group
done

############################ Detecting user access keys ##############################################

user_access_keys=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[*].AccessKeyId' --profile $profile --output text)

############################ Deleting user access keys ##############################################

echo "Deleting user access keys: $user_accces_keys"
for key in $user_access_keys ;
do
  echo "aws iam delete-access-key --user-name $user --profile $profile --access-key-id $key"
  aws iam delete-access-key --user-name $user --profile $profile --access-key-id $key
done

############################ Deleting user login profile ##############################################

echo "Deleting user login profile"
echo "aws iam delete-login-profile --profile $profile --user-name $user"
aws iam delete-login-profile --profile $profile --user-name $user

############################ Deleting user ############################################################

echo "Deleting user: $user"
echo "aws iam delete-user --profile $profile --user-name $user"
aws iam delete-user --profile $profile --user-name $user
