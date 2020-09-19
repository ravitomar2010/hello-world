#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

# source_bucket=a2i-demand-forecast
# source_folder='KSA/Mobile'
# destination_bucket=a2i-stage-demand-forecast

#######################################################################
############################# Generic Code ############################
#######################################################################

checkIfArgumentsAreNull(){

  if [[ $source_folder == '' ]]; then
    echo "You can not run operation for entire bucket"
    exit 1
  fi

  #if [[ "$source_folder" =~ '/'$ ]]; then string/
  if [[ "$source_folder" =~ '/'$ ]]; then
    echo "Folder name ends with '/' looks cool"
  else
    echo "Folder name doesn't ends with '/' changing"
    source_folder="${source_folder}/"
  fi

  if [[ "$source_folder" =~ ^/ ]]; then
    echo "Folder name starts with '/' changing"
    source_folder=`echo $source_folder | cut -c 2-`
  else
    echo "Folder name doesn't starts with '/' looks cool"
  fi

  echo "final folder name is $source_folder"

}

checkIfFolderExistsInBucket(){

 files_count=`aws s3 ls s3://$source_bucket/$source_folder --profile prod | wc -l`

    if [[ $files_count -eq 0 ]]; then
      #statements
      echo "The specifies folder does not exists in $source_bucket"
      exit 1
    fi

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

checkIfFilesIsGreaterThan25GB(){
        size_info=`aws s3 ls --summarize --human-readable --recursive s3://$source_bucket/$source_folder --profile prod | grep 'Total Size:' | cut -d ':' -f2-`
        echo "size is $size_info"
        size_no=`echo $size_info | cut -d " " -f1`
        size_bytes=`echo $size_info | cut -d " " -f2`
        echo "size in no is $size_no and in bytes is $size_bytes"
        if [[ $size_bytes == 'GiB' ]]; then
                echo "Size of $source_folder is in GiB ... Cheking ahead .."
                base_size=`echo $size_no | cut -d '.' -f1`
                echo "base size is $base_size"
                if [[ $base_size -gt 25 ]]; then
                        echo "Size of $source_folder is more than 25 GB .. Not affordable to copy"
                        exit 1
                else
                        echo "Size of $source_folder is affordable to copy"
                fi
        else
                echo "Size of $source_folder is affordable to copy"
        fi
}

##########

copyFiles(){
      echo "Working on copy";
      if [[ $source_bucket == @(axiom-stage-data|a2i-hyke-dwh|a2i-demand-forecast) ]]; then
              echo "This is amongs 3 buckets"
              checkIfFilesIsGreaterThan25GB
              echo "I am copying data"
              aws s3 sync s3://$source_bucket/$source_folder s3://$destination_bucket/$source_folder --profile stage
      else
              echo "This is unique bucket"
              mkdir -p /data/temp_s3_copy_area
              aws s3 cp s3://$source_bucket/$source_folder /data/temp_s3_copy_area --recursive --profile prod
              aws s3 cp /data/temp_s3_copy_area s3://$destination_bucket/$source_folder --recursive --profile stage
      fi
}

#######################################################################
############################# Main Function ###########################
#######################################################################

checkIfArgumentsAreNull
checkIfFolderExistsInBucket
copyFiles


##############################
########## cleanup ###########
##############################

echo "Working on cleanup "
sudo rm -rf /data/temp_s3_copy_area
