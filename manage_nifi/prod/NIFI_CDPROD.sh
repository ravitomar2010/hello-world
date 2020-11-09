#!/bin/bash
##Author Ravi Tomar ##
## dated 01 july 2020 ##
## Description nifi CD used for flow deployments ####
#### Team Devops ####


##################################### Initialize variables #####################################
bucket_name="axiom-data-production"
flow_name=$sourceFlowName
update_to_version=$flowversion
echo '' > flowstatus.txt
echo "flow: $flow_name is being deploy from bucket: $bucket_name to Production root"
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
        token=$(curl -k -d "username=$nifi_username&password=$nifi_pwd" -X POST ${url})
        echo $token
}

##################################### Getting Bucket id ########################################

GetBucketID(){
        url="$registry_url/nifi-registry-api/buckets"
        bucket_id=$(curl --silent ${url} | jq -r '.[] | select(.name == '\"$bucket_name\"') | .identifier')
        if [ -z "$bucket_id" ]; then
                echo -e "Invalid bucket name \nExiting ..."
                exit
        fi
}

##################################### Get Flows from bucket ####################################

GetBucketFlows(){
        url="$registry_url/nifi-registry-api/buckets/$bucket_id/flows"
        bucket_flows=$(curl --silent ${url})
}

##################################### Fetch flow id from flows #################################

GetFlowId(){
        flow_id=$(echo "$bucket_flows" | jq -r '.[] | select(.name == '\"$flow_name\"' ) | .identifier')
        if [ -z "$flow_id" ]; then
                echo -e "Invalid flow name \nExiting ..."
                exit
        fi
}

##################################### Fetching nifi root pg list ######################################

GetrootPGlist(){
        url="$nifi_url/nifi-api/process-groups/root/process-groups"
        root_pg_list=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure)

}

##################################### Get registry Id #################################

GetRegistryId(){
        url="$nifi_url/nifi-api/controller/registry-clients"
        echo $url
        registry_id=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure | jq -r ".registries[0].id")
        echo "registry id: $registry_id"
}

##################################### Fetch flow id from flows #################################

GetLatestFlowVersion(){
        latest_flow_version=$(echo "$bucket_flows" | jq -r '.[] | select(.name == '\"$flow_name\"' ) | .versionCount')
        echo "latest flow version : $latest_flow_version"

        if [ -z "$update_to_version" ]; then
                update_to_version=$latest_flow_version
        elif [ "$update_to_version" -gt "$latest_flow_version" -o "$update_to_version" -le 0 ]; then
                echo "This version doesn't exist"
                exit
        fi
}

##################################### Extract Nifi Flow id and current version ###################

GetNifiFlowId_Version(){
        nifi_flow_id=$( echo "$root_pg_list" | jq -r '.processGroups[].component.versionControlInformation | select(.flowId == '\"$flow_id\"') | .groupId')
        nifi_current_version=$( echo "$root_pg_list" | jq '.processGroups[].component.versionControlInformation | select(.flowId == '\"$flow_id\"') | .version')
        if [ ! -z "$nifi_flow_id" ]
        then
                echo -e "Flow already exist"
                echo "Flow id: $nifi_flow_id"
                echo "Current Version of flow: $nifi_current_version"
                if [ "$nifi_current_version" -eq "$update_to_version" ]
                then
                        echo "Flow <b>$flow_name</b> is already up to date" >> flowstatus.txt
                        sendStatusMail
                        exit
                fi
        fi
}

##################################### Check and create flow in nifi ######################################

CreateNifiFlow(){

if [ ${#nifi_flow_id} -eq 0 ]
then
        echo "Creating flow"
cat > data.json <<-EOF
{
    "revision":
    {
        "version":0
    },
    "disconnectedNodeAcknowledged":false,
    "component":
    {
        "versionControlInformation":
        {
            "registryId":"$registry_id",
            "bucketId":"$bucket_id",
            "flowId":"$flow_id",
            "version": $update_to_version
        }
    }
}
EOF
url="$nifi_url/nifi-api/process-groups/root/process-groups"
import_flow=$(curl --silent -X POST -d @data.json  -H 'Content-Type: application/json; charset=UTF-8' -H "Authorization: Bearer $token" ${url} --insecure)
new_pg_flow_id=$(echo "$import_flow" | jq -r '.id')

if [ ! -z "$new_pg_flow_id" ]
then
        echo "Flow <b>$flow_name</b> created on <b>Nifi PROD</b> with id $new_pg_flow_id<br>" >> flowstatus.txt
        nifi_current_version=$update_to_version
fi

fi
}

##################################### Check and update flow in nifi ######################################

UpdateNifiFlow(){

if [[ ! "$nifi_current_version" -eq "$update_to_version" ]]
then
        echo "Updating flow..."
        url="$nifi_url/nifi-api/versions/process-groups/$nifi_flow_id"
        revision_no=$(curl --silent -H "Authorization: Bearer $token" ${url} --insecure | jq '.processGroupRevision.version')

cat > data.json <<-EOF
{
        "processGroupRevision":
        {
                "version":$revision_no
        },
        "disconnectedNodeAcknowledged":false,
        "versionControlInformation":
        {
                "groupId":"$nifi_flow_id",
                "registryId":"$registry_id",
                "bucketId":"$bucket_id",
                "flowId":"$flow_id",
                "version":$update_to_version
        }
}
EOF
        url="$nifi_url/nifi-api/versions/update-requests/process-groups/$nifi_flow_id"
        update_flow_request=$(curl --silent -X POST -d @data.json  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" ${url} --insecure)
        request_id=$(echo "$update_flow_request" | jq -r '.request.requestId')

        url="$nifi_url/nifi-api/versions/update-requests/$request_id"
        delete_update_request=$(curl --silent -X DELETE -H "Authorization: Bearer $token" ${url} --insecure)

        echo "Nifi Flow <b>$flow_name</b> updated with latest version <b>$latest_flow_version</b> on PROD environment<br>" >> flowstatus.txt

fi
}
######################################## Sending Email ########################################

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

sendStatusMail(){
  profile='prod'
  getSSMParameters
  echo "sending email"

  aws ses send-email \
  --from "$fromEmail" \
  --destination "ToAddresses=ravi.tomar@intsof.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data=PROD | CI-CD | NIFI Flow $flow_name Migration Notification,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style="color:black"> Hi Team <br><br>This is to notify that new version of NIFI Flow entitled as <b>$sourceFlowName</b> is attempted to migrate on <b>PROD</b> Environment.Please find below details:</p><p style="color:black">$(cat flowstatus.txt)</p><p style="color:black">Please reach out to DevOps team in case of any issue or concerns.<br><br>Thanks and Regards <br> DevOps Team.</p> ,Charset=utf8}}" \
  --profile $profile

}

################################## MAIN CODE ##################################################
getNifiParameter
GetAccessToken
GetBucketID
GetBucketFlows
GetFlowId
GetRegistryId
GetrootPGlist
GetLatestFlowVersion
GetNifiFlowId_Version
CreateNifiFlow
UpdateNifiFlow
sendStatusMail
