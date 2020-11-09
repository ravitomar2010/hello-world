#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################


##############################Test Parameter ##########################

# env='stage'
# dbClient='axiom'
# schemaName='demand_forecast_dbo'
# viewName='devopsTestViewNew'
# repoName='a2i-data-views'
# usercase='usecase2'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
    echo "Source profile is ${env}"
    sourceProfile="$env"
    if [[ ${sourceProfile} == 'stage' ]]; then
        destProfile='prod'
    else
        destProfile='stage'
    fi
}

getConnectionDetails(){
  echo 'Fetching connection parameters from AWS '
  echo 'Fetching hostname '
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching portNo '
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching db name '
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$dbClient" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching redshift master password'
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Fetching accountID'
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  echo 'Setting redshift username'
  if [[ $profile == "stage" ]]; then
    redshiftUserName="axiom_rnd"
  else
    redshiftUserName="axiom_stage"
  fi
 # echo "$hostName , $portNo , $dbName , $redshiftPassword, $redshiftUserName "
}

getConnectionBatchuser(){

  echo 'Fetching batch master password'
  userForSchema=`echo ${schemaName} | rev | cut -d '_' -f2- | rev`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/${destProfile}/redshift/users/batch_$userForSchema" --with-decryption --profile ${destProfile} --output text --query Parameter.Value`
  echo 'Setting redshift username'
  redshiftUserName="batch_$userForSchema"
  echo "details for batch user is : $hostName , $portNo , $dbName , $redshiftPassword, $redshiftUserName "
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -qAt "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
   # echo $results
}

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}
#######################################################################
######################### Feature Function Code #######################
#######################################################################

executeVersioning(){

    echo "Checking versioning and creating if required"
    if [[ -f "./${repoName}/${usercase}/${viewName}/def5.txt" ]]; then
        echo "def5 definition found !!"
        cd ${repoName}/${usercase}/${viewName}/
        rm def5.txt
        mv -f -v def4.txt def5.txt
        mv -f -v def3.txt def4.txt
        mv -f -v def2.txt def3.txt
        mv -f -v def1.txt def2.txt
        mv -f -v def.txt def1.txt
        cd -

    elif [[ -f "./${repoName}/${usercase}/${viewName}/def4.txt" ]]; then
        echo "def4 definition found !!"
        cd ${repoName}/${usercase}/${viewName}/
        mv -f -v def4.txt def5.txt
        mv -f -v def3.txt def4.txt
        mv -f -v def2.txt def3.txt
        mv -f -v def1.txt def2.txt
        mv -f -v def.txt def1.txt
        cd -

    elif [[ -f "./${repoName}/${usercase}/${viewName}/def3.txt" ]]; then
        echo "def3 definition found !!"
        cd ${repoName}/${usercase}/${viewName}/
        mv -f -v def3.txt def4.txt
        mv -f -v def2.txt def3.txt
        mv -f -v def1.txt def2.txt
        mv -f -v def.txt def1.txt
        cd -

    elif [[ -f "./${repoName}/${usercase}/${viewName}/def2.txt" ]]; then
        echo "def2 definition found !!"
        cd ${repoName}/${usercase}/${viewName}/
        mv -f -v def2.txt def3.txt
        mv -f -v def1.txt def2.txt
        mv -f -v def.txt def1.txt
        cd -
    elif [[ -f "./${repoName}/${usercase}/${viewName}/def1.txt" ]]; then
        echo "def1 definition found !!"
        cd ${repoName}/${usercase}/${viewName}/
        mv -f -v def1.txt def2.txt
        mv -f -v def.txt def1.txt
        cd -
    elif [[ -f "./${repoName}/${usercase}/${viewName}/def.txt" ]]; then
        echo "def file found !!"
        cd ${repoName}/${usercase}/${viewName}/
        mv -f -v def.txt def1.txt
        cd -
    else
        echo "No previous versions exists for $viewName"
    fi

}

getViewDef(){

     sql="select definition from pg_views where viewname = LOWER('$viewName') and schemaname = LOWER('$schemaName')"
     executeQueryAndGetResults "${sql}"
     # echo "results are $results"
     echo "$results" > def.txt
     defQuery=`echo "$results" | sed 's/ *$//g'`
     viewDefQuery="CREATE OR REPlACE VIEW $schemaName.$viewName as $defQuery"
     echo -----------------------------------
     echo ${viewDefQuery}
     echo +++++++++++++++++++++++++++++++++++
}

moveViewDefToGit(){

    echo 'Removing orphan directory'
    [ -d "./${repoName}/${usercase}/${viewName}" ] && rm -rf ./${repoName}

    echo 'Cloning git repository'
    git clone -b developer git@github.com:axiom-telecom/a2i-data-views.git
    checkForViewDiff

    echo 'Creating supporting directories'
    [ ! -d "./${repoName}/${usercase}/${viewName}" ] && mkdir -p ./${repoName}/${usercase}/${viewName}


    executeVersioning

    cd ${repoName}/${usercase}/${viewName}/
    git checkout developer

    echo 'Adding content to repository devloper branch'
    cp -rf ../../../def.txt .

    echo "git add ."
    git add .
    echo "git commit "
    git commit -m "added ${viewName} on developer branch"
    echo "git push code on devloper branch"
    git push origin developer

    ######## Master branch code ###################
    cd ../../
    echo "switching to master branch"
    git checkout master
    echo "Pulling master data from origin"
    sleep 10

    git pull origin master
    echo "merging to devloper branch"
    git merge developer -m "Merging to master for view ${viewName}"
    echo "doing git add on master branch"
    git add .
    echo "doing commit on master branch"
    git commit -m "added ${viewName} on master branch"
    echo "pushing to master branch"
    git push origin master

  }

checkForViewDiff(){

    if [[ ! -f "./${repoName}/${usercase}/${viewName}/def.txt" ]]; then
         echo "This will act as first level definition for $viewName"
    else
         echo "Checking for md hash for files"
         mdHashNew=`md5 def.txt`
         cd ./${repoName}/${usercase}/${viewName}/
         mdHashOld=`md5 def.txt`
         cd -

         echo "md hash for new file is ${mdHashNew} and for old is ${mdHashOld}"
         if [[ "${mdHashNew}" == "${mdHashOld}" ]]; then
           echo "Files have the same content - nothing to commit - exiting"
           sendSameContentMail
           exit 0
         else
           echo "Files does not have the same content - moving ahead"
         fi
    fi

}

sendSameContentMail(){

    echo "I have observed no change in the view definition for $viewName - notifying the same"
    getSSMParameters
    aws ses send-email \
    --from "$fromEmail" \
    --destination "ToAddresses=$devopsMailList","CcAddresses=$devopsMailList" \
    --message "Subject={Data= ${sourceProfile} - ${destProfile} | View migration notification - Empty Definition notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All, <br> <br> This is to notify you that migation reuest for ${viewName} from ${schemaName} schema in ${destProfile} environment does not have any modifications in ${sourceProfile}. <br> Please reach out to devops in case of any concerns. <br><br> Regards\, <br> DevOps Team ,Charset=utf8}}" \
    --profile $profile

}

sendNotification(){

    echo "Sending success notification"
    getSSMParameters
    aws ses send-email \
    --from "$fromEmail" \
    --destination "ToAddresses=$toMail","CcAddresses=$devopsMailList" \
    --message "Subject={Data= ${sourceProfile} - ${destProfile} | View migration notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All, <br> <br> This is to notify you that new version for ${viewName} from ${schemaName} schema is published to ${destProfile} environment. <br> Please reach out to devops in case of any concerns. <br><br> Regards\, <br> DevOps Team ,Charset=utf8}}" \
    --profile $profile
}

#######################################################################
############################# Main Function ###########################
#######################################################################

if [[ ${viewName} == '' ]]; then
    echo 'View name not provided as argument - Exiting'
    exit 1
fi

getProfile
##### Stage #####
profile=${sourceProfile}
getConnectionDetails
getViewDef
moveViewDefToGit

##### Prod #####
profile=${destProfile}
getConnectionDetails
getConnectionBatchuser
executeQueryAndGetResults "${viewDefQuery}"
sendNotification

#############################
########## CleanUp ##########
#############################
# rm -rf ./tmp*
