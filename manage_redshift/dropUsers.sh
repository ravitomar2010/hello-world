#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#profile="$env"
dbClient='axiom'
#dbClient=$1
#sqlQuery=$1
#fileName=$2
#bucketName=''
#folderPath
# users='shorveer'
# BUILD_USER='yogesh.patil'
if [[ $1 != '' ]]; then
    echo 'Inside dropUsers script - Received some custom arguments - parsing it '
    users=$1
    profile=$2
    mailFlag='false'
    echo "Received delete redshift user request for $users in $profile env"
else
    echo 'Working with default env - No argument provided'
fi

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  curr_dir=`pwd`
  profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "profile is $profile"
}

getConnectionDetails(){
  echo 'Fetching required parameters from SSM'
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$dbClient" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    redshiftUserName="axiom_rnd"
  else
    redshiftUserName="axiom_stage"
  fi
  #echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftUserName,$accountID"
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    sqlQueryFile=$1
    echo "Executing queries from file $sqlQueryFile"
    results=`psql -atAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftUserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

getSchemaList(){

  sqlQuery="select nspname from pg_namespace where nspname not like '%pg_temp%' AND nspname not like '%pg_internal%' AND nspname not like '%admin%' order by 1"
  outputFile="tmpSchemaList$dbClient.txt"
  executeQueryAndWriteResultsToFile "${sqlQuery}" "${outputFile}"

}

getSSMParameters(){

  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/leadsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  devopsMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

checkIfUserExists(){
    sqlQuery="select count(*) from pg_user where usename like '${user}'"
    executeQueryAndGetResults "${sqlQuery}"
    # echo "The obtained user count is ${results}"
    if [[ ${results} -gt 0 ]]; then
        echo "User $user exists in redshift ${profile} and is eligible to delete"
    else
        echo "User $user doesn't exists in redshift ${profile} - exiting code"
        exit 0
    fi
}

getDependencyList(){
  ### sqlQuery="select schemaname+'.'+objectname as results from admin.v_get_obj_priv_by_user where usename='${user}' ;"
  sqlQuery="select ddl from admin.v_generate_user_grant_revoke_ddl where ( objowner = '${user}' or grantee = '${user}' ) and ddltype = 'revoke'"
  outputFile="tmpDependencyList$user.txt"
  executeQueryAndWriteResultsToFile "${sqlQuery}" "${outputFile}"
}

revokeAllAccessOnTables(){

  echo "Revoking all available access for $user user in $dbName db"
  filename="tmpDependencyList$user.txt"
  ### echo '' > tmpExecutionOrderTables.sql
  ### while read line; do
  ### 	if [[ $line == "" ]]; then #if1
  ### 	    echo "Skipping empty line"
  ###   else
  ###       # echo "Schema to process is $line"
  ###       echo "revoke all on table $line from $user;" >> tmpExecutionOrderTables.sql
  ###       #echo "revoke usage on schema $line from $user;" >> tmpExecutionOrderSchemas.sql
  ###
  ###   fi #if1
  ###   done < $filename
  ###   #echo "revoke all on database $dbName from $user;" >> tmpExecutionOrderSchemas.sql
  cat "tmpDependencyList$user.txt" > tmpExecutionOrderTables.sql
  executeQueryFile tmpExecutionOrderTables.sql

}

revokeAllAccessOnSchemasAndDB(){

  echo "Revoking all available access for $user user in $dbName db"
  filename="tmpSchemaList$dbClient.txt"
  echo '' > tmpExecutionOrderSchemas.sql
  while read line; do
  	if [[ $line == "" ]]; then #if1
  	    echo "Skipping empty line"
    else
        # echo "Schema to process is $line"
        echo "revoke all on all tables in schema $line from $user;" >> tmpExecutionOrderSchemas.sql
        echo "revoke usage on schema $line from $user;" >> tmpExecutionOrderSchemas.sql

    fi #if1
    done < $filename
    echo "revoke all on database $dbName from $user;" >> tmpExecutionOrderSchemas.sql

    executeQueryFile tmpExecutionOrderSchemas.sql

}

prepareOutput(){
    echo "Preparing output file for mail"
    echo '<pre>' > tmpDeletedUsersList.txt
    echo "Hi All <br> Please make a note that following redshift users are deleted from $profile account by ${BUILD_USER} ">> tmpDeletedUsersList.txt
    echo '==========================+++++++++++++++++++==========================' >> tmpDeletedUsersList.txt
    for user in $(echo $users | sed "s/,/ /g")
    do
        echo "$user <br>" >> tmpDeletedUsersList.txt
    done
    echo '==========================+++++++++++++++++++==========================' >> tmpDeletedUsersList.txt
    echo '<br>Regards<br>DevOps Team' >> tmpDeletedUsersList.txt
    echo "</pre>" >> tmpDeletedUsersList.txt
    echo "    $user <br>" >> tmpDeletedUsersList.txt

}

sendMail(){

    if [[ ${mailFlag} == 'false' ]]; then
        echo 'Mail flag set to false - will ignore sending notification'
    else
        getSSMParameters
        prepareOutput
        echo 'Sending email to concerned individuals'
        aws ses send-email \
        --from "$fromEmail" \
        --destination "ToAddresses=$toMail","CcAddresses=$leadsMailList,$devopsMailList" \
        --message "Subject={Data= $profile | redshift | user-delete alert ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
        --profile $profile
    fi
}

createSupportViews(){

  sqlQuery="  CREATE OR REPLACE VIEW admin.v_find_dropuser_objs as
              SELECT owner.objtype,
                     owner.objowner,
                     owner.userid,
                     owner.schemaname,
                     owner.objname,
                     owner.ddl
              FROM (
              -- Functions owned by the user
                   SELECT 'Function',pgu.usename,pgu.usesysid,nc.nspname,textin (regprocedureout (pproc.oid::regprocedure)),
                   'alter function ' || QUOTE_IDENT(nc.nspname) || '.' ||textin (regprocedureout (pproc.oid::regprocedure)) || ' owner to '
                   FROM pg_proc pproc,pg_user pgu,pg_namespace nc
              WHERE pproc.pronamespace = nc.oid
              AND   pproc.proowner = pgu.usesysid
              UNION ALL
              -- Databases owned by the user
              SELECT 'Database',
                     pgu.usename,
                     pgu.usesysid,
                     NULL,
                     pgd.datname,
                     'alter database ' || QUOTE_IDENT(pgd.datname) || ' owner to '
              FROM pg_database pgd,
                   pg_user pgu
              WHERE pgd.datdba = pgu.usesysid
              UNION ALL
              -- Schemas owned by the user
              SELECT 'Schema',
                     pgu.usename,
                     pgu.usesysid,
                     NULL,
                     pgn.nspname,
                     'alter schema '|| QUOTE_IDENT(pgn.nspname) ||' owner to '
              FROM pg_namespace pgn,
                   pg_user pgu
              WHERE pgn.nspowner = pgu.usesysid
              UNION ALL
              -- Tables or Views owned by the user
              SELECT decode(pgc.relkind,
                           'r','Table',
                           'v','View'
                     ) ,
                     pgu.usename,
                     pgu.usesysid,
                     nc.nspname,
                     pgc.relname,
                     'alter table ' || QUOTE_IDENT(nc.nspname) || '.' || QUOTE_IDENT(pgc.relname) || ' owner to '
              FROM pg_class pgc,
                   pg_user pgu,
                   pg_namespace nc
              WHERE pgc.relnamespace = nc.oid
              AND   pgc.relkind IN ('r','v')
              AND   pgu.usesysid = pgc.relowner
              AND   nc.nspname NOT ILIKE 'pg\_temp\_%'
              UNION ALL
              -- Python libraries owned by the user
              SELECT 'Library',
                     pgu.usename,
                     pgu.usesysid,
                     '',
                     pgl.name,
                     'No DDL available for Python Library. You should DROP OR REPLACE the Python Library'
              FROM  pg_library pgl,
                    pg_user pgu
              WHERE pgl.owner = pgu.usesysid) OWNER (\"objtype\",\"objowner\",\"userid\",\"schemaname\",\"objname\",\"ddl\")
              WHERE owner.userid > 1;"

    executeQueryAndGetResults "${sqlQuery}"

}

#######################################################################
############################# Main Function ###########################
#######################################################################

for user in $(echo $users | sed "s/,/ /g")
do
    echo "current user is $user"

    dbClient='axiom'

    getConnectionDetails

    checkIfUserExists

    createSupportViews

    getDependencyList

    revokeAllAccessOnTables

    getSchemaList

    revokeAllAccessOnSchemasAndDB

    echo "Working on $dbClient db client"

    dbClient='hyke'

    getConnectionDetails

    ### getDependencyList

    revokeAllAccessOnTables

    getSchemaList

    revokeAllAccessOnSchemasAndDB

    echo 'Executing drop user query'

    sqlQuery="drop user $user"

    executeQueryAndGetResults "${sqlQuery}"

done

sendMail

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
sudo rm -rf ./tmp*
