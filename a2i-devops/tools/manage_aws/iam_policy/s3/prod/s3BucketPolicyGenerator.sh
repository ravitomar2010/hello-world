#!/bin/bash
#####################################Creating READ Policy S3 ########################################
CreateReadPolicy() {
cat <<EOF > readPolicy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUsersToListAllTheBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:ListBucket",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowReadAccessToUsersOnSpecificBucket",
            "Effect": "Allow",
            "Action": [
                    "s3:GetObjectAcl",
                    "s3:GetObject",
                    "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$2",
                "arn:aws:s3:::$2/*"
            ]
        }
    ]
}
EOF
read_policy_output=$(aws iam create-policy --policy-name $1 --policy-document file://readPolicy.json --profile $env)
echo "$read_policy_output"
}

#######################################Creating READ-WRITE Policy S3 ##########################################

CreateReadWritePolicy() {
cat <<EOF > readWritePolicy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUsersToListAllTheBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:ListBucket",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowReadWriteAccessToUsersOnSpecificBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ReplicateObject",
                "s3:PutObject",
                "s3:GetObject",
                "s3:RestoreObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::$2",
                "arn:aws:s3:::$2/*"
            ]
        }
    ]
}

EOF
read_write_policy_output=$(aws iam create-policy --policy-name $1 --policy-document file://readWritePolicy.json --profile $env)
echo "$read_write_policy_output"
}

############################################ MAIN CODE Started ###################################################
env=$1
all_s3_buckets+=$(aws s3api list-buckets --output text --query "Buckets[].Name" --profile $env )
echo "${all_s3_buckets[@]}"

result=$(aws iam list-policies --output text --query "Policies[?starts_with(PolicyName, \`a2i-s3\`) == \`true\`].PolicyName" --profile $env)

for bucket in ${all_s3_buckets[@]}
do
    read_policy_name=a2i-s3-read-"$bucket"
    read_write_policy_name=a2i-s3-read-write-"$bucket"

    if [[ ! "${result}" =~ "$read_policy_name" ]]
    then
        CreateReadPolicy $read_policy_name $bucket
    else
        echo "$read_policy_name exists"
    fi

    if [[ ! "${result}" =~ "$read_write_policy_name" ]]
    then
        CreateReadWritePolicy $read_write_policy_name $bucket
    else
        echo "$read_write_policy_name exists"
    fi

done
