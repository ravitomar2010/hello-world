#!/bin/bash
##################################### Initialize variables #####################################

processor_id=$1
#nifi_url="https://nifi-1.a2i.stage"
parents=""

##################################### Get nifi parameter from AWS ########################################

getNifiParameter(){
    echo 'fetching nifi parameters from aws'
    echo 'Fetching registry_url'
    registry_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifiregistryurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi staging url'
    nifi_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifistageurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi username'
    nifi_username=`aws ssm get-parameter --name "/a2i/stage/nifi/username" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi username'
    nifi_pwd=`aws ssm get-parameter --name "/a2i/stage/nifi/password" --with-decryption --profile stage --output text --query Parameter.Value`

}

#################################### Access Token #############################################

GetAccessToken(){
url="$nifi_url/nifi-api/access/token"
token=$(curl -k -H 'Content-Type:application/x-www-form-urlencoded;charset=UTF-8' -d "username=$nifi_username&password=$nifi_pwd" -X POST ${url} --compressed --insecure )
#token=${token//$'\r'/}
echo $token
}
##################################### Fetch Processor Details #####################################
getNifiParameter
GetAccessToken
url="${nifi_url}/nifi-api/processors/$processor_id"
processor_details=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure)
processor_name=$(echo "$processor_details" | jq -r '.component.name')
parent_id=$(echo "$processor_details" | jq -r '.component.parentGroupId')

##################################### Loop to fetch and append parent pg name to array ##########

while [ "$parent_id" != "null" ]
do
        url="${nifi_url}/nifi-api/process-groups/$parent_id"
        process_group=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure)
        parent_id=$(echo "$process_group" | jq -r '.component.parentGroupId')
        pg_name=$(echo "$process_group" | jq -r '.component.name')
        parents="$pg_name -> $parents"
done
parents=$(echo $parents | sed 's/->$//')
echo "Path to processor $processor_name is: $parents"
