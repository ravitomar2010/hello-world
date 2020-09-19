#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

getTimeStamp(){
  #dToDel='1590969600'
  dToDel=`date -d '7 days ago' '+%s'`
  echo $dToDel
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

waitTillResourceIsDeleted(){
  resource=$1
  resource_arn=$2
  delete_count=1;
  timer=0;
    while [[ $delete_count -gt 0 ]]; do
        if [[ $timer -lt 600 ]]; then
            delete_count=`aws forecast list-$resource --profile $profile | grep "$resource_arn" | wc -l`
            #echo "delete count for $resource_arn is $delete_count"
            echo "Still waiting for resource to get deleted $resource_arn since last $timer seconds"
            sleep 5;
            timer=$((timer + 5))
        else
            delete_count=0;
            echo "Timeout error occured while deleting the resource $resource_arn. Please check.. !!"
            return 0
        fi
    done
    echo "Deleted the resource $resource_arn. Moving ahead..."
}


deleteForecastExports(){

  echo 'Listing all eligible forecast export job which can be deleted'
  aws forecast list-forecast-export-jobs --query "ForecastExportJobs[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"ForecastExportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListForecastExports.txt

  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-forecast-export-job --forecast-export-job-arn $line --profile $profile`
        waitTillResourceIsDeleted forecast-export-jobs $line
    fi #if1
  done < tmpListForecastExports.txt
}

deleteForecast(){
  echo 'Listing all eligible forecast jobs which can be deleted'
  aws forecast list-forecasts --query "Forecasts[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"ForecastArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListForecast.txt

  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-forecast --forecast-arn $line --profile $profile`
        waitTillResourceIsDeleted forecasts $line
    fi #if1
  done < tmpListForecast.txt
}

deletePredictor(){
  echo 'Listing all eligible predictor jobs which can be deleted'
  aws forecast list-predictors --query "Predictors[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"PredictorArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListPredictor.txt

  while read line; do
    if [[ $line == "" ]]; then #if1
        echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-predictor --predictor-arn $line --profile $profile`
        waitTillResourceIsDeleted predictors $line
    fi #if1
  done < tmpListPredictor.txt

}

deleteDatasetImport(){
  echo 'Listing all eligible dataset import jobs which can be deleted'
  aws forecast list-dataset-import-jobs --query "DatasetImportJobs[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"DatasetImportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListDatasetImport.txt

  while read line; do
    if [[ $line == "" ]]; then #if1
        echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-dataset-import-job --dataset-import-job-arn $line --profile $profile`
        waitTillResourceIsDeleted dataset-import-jobs $line
    fi #if1
  done < tmpListDatasetImport.txt
}

deleteDataset(){
  echo 'Listing all eligible datasets which can be deleted'
  aws forecast list-datasets --query "Datasets[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListDataset.txt

  while read line; do
    if [[ $line == "" ]]; then #if1
        echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-dataset --dataset-arn $line --profile $profile`
        waitTillResourceIsDeleted datasets $line
    fi #if1
  done < tmpListDataset.txt
}

deleteDatasetGroup(){
  echo 'Listing all eligible datasets which can be deleted'
  aws forecast list-dataset-groups --query "DatasetGroups[?CreationTime<=\`$dToDel\`]" --profile $profile | grep -e '"DatasetGroupArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1 | cut -d '"' -f2 > tmpListDatasetGroup.txt

  while read line; do
    if [[ $line == "" ]]; then #if1
        echo "Skipping empty line"
    else
        echo "Deleting $line"
        response=`aws forecast delete-dataset-group --dataset-group-arn $line --profile $profile`
        waitTillResourceIsDeleted dataset-groups $line
    fi #if1
  done < tmpListDatasetGroup.txt
}
#######################################################################
############################# Main Function ###########################
#######################################################################

 echo "Setting working profile"
 getProfile
 echo "Fetching eligible timestamp"
 getTimeStamp
 echo "Working  on deleteForecastExports"
 deleteForecastExports
 echo "Working  on deleteForecast"
 deleteForecast
 echo "Working  on deletePredictor"
 deletePredictor
 echo "Working  on deleteDatasetImport"
 deleteDatasetImport
 echo "Working  on deleteDataset"
 deleteDataset
 echo "Working  on deleteDatasetGroup"
 deleteDatasetGroup

 #############################
 ########## CleanUp ##########
 #############################

 echo "Working on CleanUp"
 rm -rf ./tmp*

echo "Completed !!"
