#!/bin/bash
##Author Ravi Tomar ##
## dated 01 july 2020 ##
## Description nifi CI used for bucket to bucket flow transfer##
#### Team Devops ####

########################### Variable declaration ##########################
source_bucket=$sourceBucket
dest_bucket=$destBucket
source_flow_name=$sourceFlowName
echo $sourceBucket $destBucket $sourceFlowName

###########################  Getting Nifi parametrs ####################
getNifiParameter(){
    echo 'fetching nifi parameters from aws'
    echo 'Fetching registry_url'
    registry_url=`aws ssm get-parameter --name "/a2i/stage/nifi/nifiregistryurl" --with-decryption --profile stage --output text --query Parameter.Value`
    echo 'Fetching cli path'
    cli=`aws ssm get-parameter --name "/a2i/infra/nifi_toolkit/clipath" --with-decryption --profile stage --output text --query Parameter.Value`
}

###########################  List all registry buckets ####################

listRegBucket(){
      buckets=$($cli registry list-buckets -u ${registry_url} -ot json)
}

########################### Getting Bucket Ids of specified src/dest buckets #######################

fetchBucketids(){
####################### Source Bucket ID Fetching  ##########################################

        source_bucket_id=$(echo "$buckets" | jq -r '.[] | select(.name == '\"$source_bucket\"' ) | .identifier')
        echo "$source_bucket bucket id: $source_bucket_id"

####################### Destination  Bucket ID Fetching  ##########################################

        dest_bucket_id=$(echo "$buckets" | jq -r '.[] | select(.name == '\"$dest_bucket\"' ) | .identifier')
        echo "$dest_bucket bucket id: $dest_bucket_id"
}

############################### List all source bucket flows ######################################

listSourceflow(){
        source_flows=$($cli registry list-flows -b ${source_bucket_id} -u $registry_url -ot json)
        total_source_flows=$(echo "$source_flows" | jq '. | length')
        echo "source flows: $total_source_flows"
}

############################### List all Destination bucket flows ######################################

listDestinationflow(){
        dest_flows=$($cli registry list-flows -b ${dest_bucket_id} -u $registry_url -ot json)
        total_dest_flows=$(echo "$dest_flows" | jq '. | length')
        echo "destination flows: $total_dest_flows"
}

flowIdsource(){
        source_flow_id=$(echo "$source_flows" |  jq -r '.[] | select(.name == '\"$source_flow_name\"' ) | .identifier')
        echo "source flow name: $source_flow_name"
        echo "source flow id: $source_flow_id"
}

flowIddestination(){
        dest_flow_id=$(echo $dest_flows | jq -r '.[] | select(.name == '\"$source_flow_name\"' ) | .identifier')
        len=${#dest_flow_id}
        echo "length of id: $len"
}

check_CreateFlow(){
         if [ $len -eq 0 ]
        then
                ############### flow does not exist #############################

                echo flow does not exist hence creating
                new_flow_id_dest=$($cli registry create-flow -b ${dest_bucket_id} -fn ${source_flow_name} -u $registry_url)
                echo "New created flow id of destination : ${new_flow_id_dest}"
                transfer_flow_source_dest=$($cli registry transfer-flow-version -f ${new_flow_id_dest} -sf ${source_flow_id} -u $registry_url)
                echo "${transfer_flow_source_dest}"
        else
                ################# flow exists  ##################################

                echo flow already exists on destination ,Hence updating
                result=$($cli registry sync-flow-versions -f ${dest_flow_id} -sf ${source_flow_id} -u $registry_url)
                echo "${result}"
        fi
}

##############################  Main Function #################################################
getNifiParameter
listRegBucket
fetchBucketids
listSourceflow
listDestinationflow
flowIdsource
flowIddestination
check_CreateFlow
