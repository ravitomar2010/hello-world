#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile='stage'
##client='axiom'
filename='tmpLambdaListNames.txt'
workingLambdaName=''

#######################################################################
############################# Generic Code ############################
#######################################################################


#######################################################################
######################### Feature Function Code #######################
#######################################################################
getListOfLambdas(){
  echo "Fetching list of lambdas for $profile"
  aws lambda list-functions --profile $profile | grep '"FunctionName":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListNames.txt
  #aws lambda list-functions --max-items 1 --profile $profile | grep '"FunctionName":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListNames.txt
  #aws lambda list-functions --max-items 2 --function-version ALL --profile $profile | grep '"FunctionArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListARNs.txt
}

getDeleteEligibleFunctionARNs(){

  aws lambda list-versions-by-function --function-name $workingLambdaName --profile $profile | grep '"FunctionArn":' | cut -d ':' -f2- | cut -d ',' -f1 | cut -d '"' -f2 > tmpLambdaListARNs.txt
  tail -n +2 tmpLambdaListARNs.txt > tmpLambdaListARNs-1.txt
  sed '$d' tmpLambdaListARNs-1.txt | sed '$d' |  sed '$d' > tmpLambdaEligibleToDel.txt
}


listAndDeleteLambdas(){
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "I am working on lambda $line"
        workingLambdaName=$line
        getDeleteEligibleFunctionARNs
        deleteLambdaPreviousVersions
        #aws lambda delete-function --function-name $line --profile $profile
    fi
    done < $filename

}

deleteLambdaPreviousVersions(){
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        echo "I am deleting lambda version $line"
        aws lambda delete-function --function-name $line --profile $profile
    fi
    done < tmpLambdaEligibleToDel.txt
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getListOfLambdas
listAndDeleteLambdas
# deleteLambdaPreviousVersions

#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
rm -rf ./tmp*
