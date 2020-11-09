#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile='stage'
client='axiom'
# bucketName=$1
# folderName=$2

# echo "Bucket name is $bucketName"
# echo "Folder name is $folderName"


#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}



#######################################################################
######################### Feature Function Code #######################
#######################################################################

checkIfFolderExists(){

  file_list_count=`aws s3 ls "s3://$bucketName/$folderName" --profile $profile | wc -l`
  #echo "$file_list_count"
  if [[ $file_list_count -lt 1 ]]; then
    #statements
    echo "Folder does not exists in source.. Exiting..!!"
    exit 0
  fi

}

checkIfPolicyExistsAndCreate(){

    policy_details=`aws iam list-policies --scope Local --profile $profile | grep "$policyName"`
    is_policy_exists=`echo "$policy_details" | wc -l`
    policy_arn=`echo $policy_details | cut -d "," -f2 | cut -d ":" -f2- | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev `


    echo "$is_policy_exists"

    if [[ $is_policy_exists -gt 0 ]]; then
        echo "Policy already exists - will modify the same"
        #echo "$policy_arn"
        modifyPolicy
    else
       echo "Policy doesn't exists - will create the same"
       createPolicy
    fi
}

generatePolicyName(){

  lastFolder=`echo $folderName | rev | cut -d '/' -f1 | rev`
  policyName="a2i_s3_read-write_folder-level_${bucketName}_${lastFolder}"
  echo "$policyName"
  policyDescription=" This policy allows read-write access to $folderName folder of bucket $bucketName to groups and users"

}

generateDraftPolicy(){

       python3 draft_policy_generator.py $bucketName $folderName

}

createPolicy(){

    tmp_policy_document=`cat tmp_policy.txt | python -m json.tool`
    echo -e "\n\n Creating policy $policyName"
    response=`aws iam create-policy --policy-name $policyName --policy-document "$tmp_policy_document" --description "$policyDescription" --profile $profile`

}

modifyPolicy(){

  tmp_policy_document=`cat tmp_policy.txt | python -m json.tool`
  echo -e "\n\n Modifying policy $policyName"
  response=`aws iam create-policy-version --policy-arn "$policy_arn" --policy-document "$tmp_policy_document" --set-as-default --profile $profile`

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
generatePolicyName
checkIfFolderExists
generateDraftPolicy
checkIfPolicyExistsAndCreate

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
rm -rf ./tmp_*
