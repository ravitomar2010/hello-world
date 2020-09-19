#!/bin/bash
##Author : Ravi Tomar ###
### Description :used to show list of flow on jenkins ####
#### dated 01/07/2020 #####

getNifiParameter(){
    echo 'fetching nifi parameters from aws'
    echo 'Fetching registry_url'
    registry_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifiregistryurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching cli path'
    cli=`aws ssm get-parameter --name "/a2i/infra/nifi_toolkit/clipath" --with-decryption --profile stage --output text --query Parameter.Value`
}

createBucketflow(){
buckets=$($cli registry list-buckets -u ${registry_url} -ot json)
filename="/data/extralibs/nifi"
bucket_names=$(echo "$buckets" | jq -r '.[].name')
for bucket_name in ${bucket_names[@]}
do
        bucket_id=$(echo "$buckets" | jq -r '.[] | select(.name == '\"$bucket_name\"' ) | .identifier')



        bucket_flows=$($cli registry list-flows -b ${bucket_id} -u $registry_url -ot json)
        echo "$bucket_flows" | jq -r '.[].name' > $filename/$bucket_name.txt
        if [ $? -eq 0 ]
        then
                echo "$bucket_name's file created and populated with flow names"
        fi
done
}

getNifiParameter
createBucketflow
