#!/bin/bash

isValidToDelete(){

    dnow=`date '+%d%m%Y'`;
    ts_to_delete=$1
    ts_to_delete=`date -r $ts_to_delete '+%d%m%Y'`
    #arn_to_delete=$2
    #echo "Inside isValidToDelete"
    #echo "timestamp is $ts_to_delete"
    #echo "dnow is $dnow"
    #diff_ts=`($dnow-$ts_to_delete)`
    #diff_ts=$(($dnow - $ts_to_delete))
    if [[  ${dnow#0} -eq ${ts_to_delete#0} ]]; then
      #statements
      #deleteDataset $arn_to_delete
      return 1
    else
      return 0
    fi
}

waitTillResourceIsDeleted(){

  resource=$1
  resource_arn=$2
  delete_count=1;
  timer=0;
    while [[ $delete_count -gt 0 ]]; do
        if [[ $timer -lt 600 ]]; then
            delete_count=`aws forecast list-$resource --profile $profile_name | grep "$resource_arn" | wc -l`
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

deleteForecastExports() {
##################################################################
########## Starting of deleteForecastExports function ############
##################################################################

is_first_fce=1
is_fcee_last=1
next_token=''
length_of_initial_fce=`aws forecast list-forecast-export-jobs --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"ForecastExportJobArn":' | wc -l`
#length_of_initial_fce=${#initial_fce}
#echo "initial ds is $initial_fce and length is $length_of_initial_fce"
dnow=`date '+%s'`

if [[ $length_of_initial_fce -eq 0 ]]; then
    echo "No forecasts export jobs exists... exiting !!"
    return 0
fi

while [[ $is_fcee_last -gt 0 ]]; do
        ## Check first forecast if it can be deleted
        if [[ $is_first_fce -eq 1 ]]; then
          ts_fce=`aws forecast list-forecast-export-jobs --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          fce_arn=`aws forecast list-forecast-export-jobs --max-items 1 --profile $profile_name | grep -e '"ForecastExportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_fcee_last=`aws forecast list-forecast-export-jobs --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-forecast-export-jobs --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
          is_first_fce=0;
          #echo "This is first ARN $fce_arn and next token is $next_token and timestamp is $ts_fce"
        else
          ts_fce=`aws forecast list-forecast-export-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          fce_arn=`aws forecast list-forecast-export-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"ForecastExportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_fcee_last=`aws forecast list-forecast-export-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-forecast-export-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
          #echo "This is not first ARN $fce_arn and next token is $next_token and timestamp is $ts_fce"
        fi
        #ts_for_first_item=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #fce_arn=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #is_fcee_last=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
        #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
        #echo "fce_arn is $fce_arn"
        isValidToDelete $ts_fce
        deleteflag=$?
        #echo "deleteflag is $deleteflag"
        if [[ $deleteflag -eq 1 ]]; then
            #deleteDataset $fce_arn
            echo "Deleting Forecast export job $fce_arn"
            fce_arn=`echo "$fce_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
            response=`aws forecast delete-forecast-export-job --forecast-export-job-arn $fce_arn --profile $profile_name`
            waitTillResourceIsDeleted forecast-export-jobs $fce_arn
        fi
done
}

deleteForecast() {
##################################################################
############# Starting of deleteForecast function ################
##################################################################

is_first_fc=1
is_fc_last=1
next_token=''
length_of_initial_fc=`aws forecast list-forecasts --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"ForecastArn":' | wc -l`
#length_of_initial_fc=${#initial_fc}
#echo "initial ds is $initial_fc and length is $length_of_initial_fc"
dnow=`date '+%s'`

if [[ $length_of_initial_fc -eq 0 ]]; then
    echo "No forecasts exists... exiting !!"
    return 0
fi

while [[ $is_fc_last -gt 0 ]]; do
        ## Check first forecast if it can be deleted
        if [[ $is_first_fc -eq 1 ]]; then
          ts_fc=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          fc_arn=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"ForecastArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_fc_last=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
          is_first_fc=0;
          #echo "This is first ARN $fc_arn and next token is $next_token and timestamp is $ts_fc"
        else
          ts_fc=`aws forecast list-forecasts --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          fc_arn=`aws forecast list-forecasts --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"ForecastArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_fc_last=`aws forecast list-forecasts --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-forecasts --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
          #echo "This is not first ARN $fc_arn and next token is $next_token and timestamp is $ts_fc"
        fi
        #ts_for_first_item=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #fc_arn=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #is_fc_last=`aws forecast list-forecasts --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
        #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
        #echo "fc_arn is $fc_arn"
        isValidToDelete $ts_fc
        deleteflag=$?
        #echo "deleteflag is $deleteflag"
        if [[ $deleteflag -eq 1 ]]; then
            #deleteDataset $fc_arn
            echo "Deleting Forecast $fc_arn"
            fc_arn=`echo "$fc_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
            response=`aws forecast delete-forecast --forecast-arn $fc_arn --profile $profile_name`
            waitTillResourceIsDeleted forecasts $fc_arn
        fi
done
}

deletePredictor() {
##################################################################
############# Starting of deletePredictor function ################
##################################################################

is_first_pd=1
is_pd_last=1
next_token=''
length_of_initial_pd=`aws forecast list-predictors --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"PredictorArn":' | wc -l`
#length_of_initial_pd=${#initial_pd}
#echo "initial ds is $initial_pd and length is $length_of_initial_pd"
dnow=`date '+%s'`

if [[ $length_of_initial_pd -eq 0 ]]; then
    echo "No predictors exists... exiting !!"
    return 0
fi

while [[ $is_pd_last -gt 0 ]]; do
        ## Check first forecast if it can be deleted
        if [[ $is_first_pd -eq 1 ]]; then
          ts_pd=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          pd_arn=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep -e '"PredictorArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_pd_last=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
          is_first_pd=0;
         #echo "This is first ARN $pd_arn and next token is $next_token and timestamp is $ts_pd"
        else
          ts_pd=`aws forecast list-predictors --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          pd_arn=`aws forecast list-predictors --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"PredictorArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          is_pd_last=`aws forecast list-predictors --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
          next_token=`aws forecast list-predictors --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
         #echo "This is not first ARN $pd_arn and next token is $next_token and timestamp is $ts_pd"
        fi
        #ts_for_first_item=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #pd_arn=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
        #is_pd_last=`aws forecast list-predictors --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
        #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
        #echo "pd_arn is $pd_arn"
        isValidToDelete $ts_pd
        deleteflag=$?
        #echo "deleteflag is $deleteflag"
        if [[ $deleteflag -eq 1 ]]; then
            #deleteDataset $pd_arn
            echo "Deleting Predictor $pd_arn"
            pd_arn=`echo "$pd_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
            response=`aws forecast delete-predictor --predictor-arn $pd_arn --profile $profile_name`
            waitTillResourceIsDeleted predictors $pd_arn
        fi
done
}

deleteDatasetImport() {

##################################################################
############ Starting of deleteDatasetImport function ############
##################################################################

is_first_dsi=1
is_dsii_last=1
next_token=''
length_of_initial_dsi=`aws forecast list-dataset-import-jobs --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"DatasetImportJobArn":' | wc -l`
#length_of_initial_dsi=${#initial_dsi}
#echo "initial ds is $initial_dsi and length is $length_of_initial_dsi"
dnow=`date '+%s'`

if [[ $length_of_initial_dsi -eq 0 ]]; then
  #statements
  echo "No Dataset Import exists... exiting !!"
  return 0
fi

while [[ $is_dsii_last -gt 0 ]]; do
          ## Check first forecast if it can be deleted
          if [[ $is_first_dsi -eq 1 ]]; then
            ts_dsi=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            dsi_arn=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep -e '"DatasetImportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            is_dsii_last=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
            next_token=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
            is_first_dsi=0;
           #echo "This is first ARN $dsi_arn and next token is $next_token and timestamp is $ts_dsi"
          else
            ts_dsi=`aws forecast list-dataset-import-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            dsi_arn=`aws forecast list-dataset-import-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"DatasetImportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            is_dsii_last=`aws forecast list-dataset-import-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
            next_token=`aws forecast list-dataset-import-jobs --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
           #echo "This is not first ARN $dsi_arn and next token is $next_token and timestamp is $ts_dsi"
          fi

          #ts_for_first_item=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #dsi_arn=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep -e '"DatasetImportJobArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #is_dsii_last=`aws forecast list-dataset-import-jobs --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
          #echo "dsi_arn is $dsi_arn"
          isValidToDelete $ts_dsi
          deleteflag=$?

          #echo "deleteflag is $deleteflag"
          if [[ $deleteflag -eq 1 ]]; then
              #deleteDataset $dsi_arn
              echo "Deleting datasets import $dsi_arn"
              dsi_arn=`echo "$dsi_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
              response=`aws forecast delete-dataset-import-job --dataset-import-job-arn $dsi_arn --profile $profile_name`
              waitTillResourceIsDeleted dataset-import-jobs $dsi_arn
          fi
done
}

deleteDataset() {

##################################################################
################### Starting of deleteDataset function #########################
##################################################################

is_first_ds=1
is_ds_last=1
next_token=''
length_of_initial_ds=`aws forecast list-datasets --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"DatasetArn":' | wc -l`
#length_of_initial_ds=${#initial_ds}
#echo "initial ds is $initial_ds and length is $length_of_initial_ds"
dnow=`date '+%s'`

if [[ $length_of_initial_ds -eq 0 ]]; then
  #statements
  echo "No dataset exists... exiting !!"
  return 0
fi

while [[ $is_ds_last -gt 0 ]]; do
          ## Check first forecast if it can be deleted
          if [[ $is_first_ds -eq 1 ]]; then
            ts_ds=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            ds_arn=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            is_ds_last=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
            next_token=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
            is_first_ds=0;
            #echo "This is first ARN $ds_arn and next token is $next_token and timestamp is $ts_ds"
          else
            ts_ds=`aws forecast list-datasets --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            ds_arn=`aws forecast list-datasets --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
            is_ds_last=`aws forecast list-datasets --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
            next_token=`aws forecast list-datasets --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
            #echo "This is not first ARN $ds_arn and next token is $next_token and timestamp is $ts_ds"
          fi

          #ts_for_first_item=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #ds_arn=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #is_ds_last=`aws forecast list-datasets --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
          #echo "ds_arn is $ds_arn"
          isValidToDelete $ts_ds
          deleteflag=$?

          #echo "deleteflag is $deleteflag"
          if [[ $deleteflag -eq 1 ]]; then
              #deleteDataset $ds_arn
              echo "Deleting dataset $ds_arn"
              ds_arn=`echo "$ds_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
              response=`aws forecast delete-dataset --dataset-arn $ds_arn --profile $profile_name`
              waitTillResourceIsDeleted datasets $ds_arn
          fi
done
}

deleteDatasetGroup(){

##################################################################
################### Starting of deleteDatasetGroup function #########################
##################################################################

is_first_dsg=1
is_dsg_last=1
next_token=''
length_of_initial_dsg=`aws forecast list-dataset-groups --max-items 1 --region eu-west-1 --profile $profile_name | grep -e '"DatasetGroupArn":' | wc -l`
#length_of_initial_dsg=${#initial_dsg}
#echo "initial ds is $initial_dsg and length is $length_of_initial_dsg"
dnow=`date '+%s'`

if [[ $length_of_initial_dsg -eq 0 ]]; then
  #statements
  echo "No forecasts dataset group exists... exiting !!"
  return 0
fi

while [[ $is_dsg_last -gt 0 ]]; do
          ## Check first forecast if it can be deleted
          if [[ $is_first_dsg -eq 1 ]]; then
              ts_dsg=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
              dsg_arn=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep -e '"DatasetGroupArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
              is_dsg_last=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
              next_token=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
              is_first_dsg=0;
              #echo "This is first ARN $dsg_arn and next token is $next_token and timestamp is $ts_dsg"
          else
              ts_dsg=`aws forecast list-dataset-groups --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
              dsg_arn=`aws forecast list-dataset-groups --max-items 1 --starting-token $next_token --profile $profile_name | grep -e '"DatasetGroupArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
              is_dsg_last=`aws forecast list-dataset-groups --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | wc -l`
              next_token=`aws forecast list-dataset-groups --max-items 1 --starting-token $next_token --profile $profile_name | grep '"NextToken":' | cut -d ':' -f2-`
              #echo "This is not first ARN $dsg_arn and next token is $next_token and timestamp is $ts_dsg"
          fi
          #ts_for_first_item=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep -e '"CreationTime":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #ds_arn=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep -e '"DatasetArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '.' -f1`
          #is_dsg_last=`aws forecast list-dataset-groups --max-items 1 --profile $profile_name | grep '"NextToken":' | wc -l`
          #ts_for_first_item=`date -r $epoc_for_first_item '+%d%m%Y'`
          echo "dsg_arn is $dsg_arn"
          isValidToDelete $ts_dsg
          deleteflag=$?
          echo "deleteflag is $deleteflag"
          if [[ $deleteflag -eq 1 ]]; then
              #deleteDataset $ds_arn
              dsg_arn=`echo "$dsg_arn" | cut -d '"' -f2- | rev | cut -d '"' -f2- | rev`
              #echo "Deleting datasets groups $dsg_arn"
              aws forecast delete-dataset-group --dataset-group-arn $dsg_arn --profile $profile_name
              waitTillResourceIsDeleted dataset-groups $dsg_arn
          fi
done
}

###################################################################################
################################ Initiation #######################################
###################################################################################
profile_name='prod'

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

echo "Completed !!"
