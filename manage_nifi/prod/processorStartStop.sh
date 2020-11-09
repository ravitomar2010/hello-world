#!/bin/bash

##################################### Initialize variables #####################################
parent_pg_name=$1
#proc_name=("ListDatabaseTables" "UpdateAttribute")
#flow_name=$3
#cli="./nifi-toolkit-1.11.4/bin/cli.sh"
#registry_url="http://nifi-registry.a2i.infra:18080"
#nifi_url="https://nifi-stage-a2i.hyke.ai"
##################################### Get nifi parameter from AWS ########################################

getNifiParameter(){
    echo 'fetching nifi parameters from aws'
    echo 'Fetching registry_url'
    registry_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifiregistryurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi prod url'
    nifi_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifiprodurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi username'
    nifi_username=`aws ssm get-parameter --name "/a2i/stage/nifi/username" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching nifi username'
    nifi_pwd=`aws ssm get-parameter --name "/a2i/stage/nifi/password" --with-decryption --profile stage --output text --query Parameter.Value`

}

##################################### Getting Access Token ########################################

GetAccessToken(){
url="$nifi_url/nifi-api/access/token"
token=$(curl -k -H 'Content-Type:application/x-www-form-urlencoded;charset=UTF-8' -d "username=$nifi_username&password=$nifi_pwd" -X POST ${url} --compressed --insecure )
#token=${token//$'\r'/}
echo $token
}

################################### Get Processor ID #####################################
getProcessorid(){
proc_name=$1
url="$nifi_url/nifi-api/flow/search-results?q=$proc_name"
proc_details=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure)
processorId=$(echo "$proc_details" | jq -r '.searchResultsDTO.processorResults[] | select(.parentGroup.name == '\"$parent_pg_name\"') | .id'  )
echo "fetched processor id of $proc_name is:$processorId"

}

################################### Update Processor status #####################################
updateProcessorstatus(){
statusRequired=$1
url="$nifi_url/nifi-api/processors/$processorId"
proc_revision=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure | jq -r '.revision.version')
echo "Fethed revision number of $proc_name is:$proc_revision"

url="$nifi_url/nifi-api/processors/$processorId/run-status"
cat > data.json <<-EOF
{
        "revision":
        {
                "version":$proc_revision
        },
        "state":"$statusRequired",
        "disconnectedNodeAcknowledged":true
}
EOF
update_proc_status=$(curl --silent -X PUT -d @data.json  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" ${url} --insecure)
current_state=$(echo "$update_proc_status" | jq '.component.state')
echo "Process group $parent_pg_name processor name $proc_name status: $current_state"
}

clearProcessorState(){
#updateProcessorstatus "RUNNING"
url="$nifi_url/nifi-api/processors/$processorId/state/clear-requests"
clear_state=$(curl --silent -X POST -H "Authorization: Bearer $token" ${url} --insecure)
echo "Cleared Processor state of $proc_name: $clear_state"
}

getNifiParameter
GetAccessToken
getProcessorid "ListDatabaseTables"
clearProcessorState
updateProcessorstatus "RUNNING"
getProcessorid "UpdateAttribute"
updateProcessorstatus "RUNNING"
echo waiting for 300 secounds
sleep 300
getProcessorid "ListDatabaseTables"
updateProcessorstatus "STOPPED"
getProcessorid "UpdateAttribute"
updateProcessorstatus "STOPPED"
