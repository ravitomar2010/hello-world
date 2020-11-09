#############################################################
######## THE SCRIPTS LISTS THE UNUSED TABLES OF LAST ########
######## 7 DAYS FROM BOTH DATABASES FOR BOTH ENVS ###########
####################### TEAM DEVOPS #########################
#############################################################

#!/bin/bash

####################################### Variable Declaration #########################################

profile=''
dbClient=$1
# starttime=`date -d '7 days ago' +"%Y-%m-%d %T"`
tmpLogs="$(date +%s)_tmpLogs.txt"
schemaList=()
tableList=()

echo '<pre>' > tmpMail.txt
echo '<h4>Hi All, </h4>' >> tmpMail.txt
echo '' > tmpTableList.txt
echo '' > tmpLogs.txt

####################################### SET PROFILE #########################################

setProfile(){
        echo "Setting profile to work"
        if [[ $profile == '' ]]
        then
                profile=`pwd | rev | cut -d/ -f1 | rev`
        fi
        echo "Profile is ${profile}"
}

#######################################################################
############################# Generic Code ############################
#######################################################################

getSSMParameters(){
        echo "Fetching Parameters from ssm"
        hostName=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/redshift/host" --with-decryption --output text --query Parameter.Value`
        portNo=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/redshift/port" --with-decryption --output text --query Parameter.Value`
        dbName=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/redshift/db/${dbClient}" --with-decryption --output text --query Parameter.Value`
        redshiftPassword=`aws ssm get-parameter --profile ${profile} --name "/a2i/infra/redshift_${profile}/rootpassword" --with-decryption --output text --query Parameter.Value`
        accountID=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/accountid" --with-decryption --output text --query Parameter.Value`
        devopsMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/devopsMailList" --with-decryption --output text --query Parameter.Value`
        leadsMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/leadsMailList" --with-decryption --query Parameter.Value --output text`
        toMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/toAllList" --with-decryption --query Parameter.Value --output text`
        fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`

        if [ ${profile} == 'stage' ]
        then
                redshiftuserName="axiom_rnd"
        else
                redshiftuserName="axiom_stage"
        fi
        # echo "$hostName-$portNo-$dbName-$redshiftPassword-$accountID-$redshiftuserName"
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F , -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    sqlQueryFile=$1
    echo "Executing queries from file $sqlQueryFile"
    results=`psql -atAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

####################################### GET DATABASE TABLES AND Logs #########################################

getTableListAndLogs(){

        ######################################### FETCHING DATABASE TABLES #######################################

        echo "Fetching db tables for ${dbName}"
        sqlQuery="select schemaname +  '.' + tablename as tmpTableList from pg_tables where schemaname != 'pg_catalog' and schemaname != 'information_schema' and schemaname != 'public';"
        # psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > tmpTableList.txt
        executeQueryAndWriteResultsToFile "${sqlQuery}" "tmpTableList.txt"

        ######################################### FETCHING tmpLogs #######################################

        echo "Fetching tmpLogs for ${dbName}"
        sqlQuery="select querytxt from stl_query where database = '${dbName}' and label not like '%maintenance%' and label != 'metrics' and label != 'health'"
        # psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > tmpLogs.txt
        executeQueryAndWriteResultsToFile "${sqlQuery}" "tmpLogs.txt"

        ######################################### STORING tmpLogs IN S3 BUCKET #######################################

        if [[ $dbName == "hyke" ]]
        then
                echo "Uploading tmpLogs to s3://a2i-devops-prod/redshift/hyke/db_tmpLogs/${tmpLogs}"
                upload=`aws s3 cp --profile ${profile} tmpLogs.txt s3://a2i-devops-prod/redshift/hyke/db_tmpLogs/${tmpLogs}`
        
        else
                echo "Uploading tmpLogs to s3://a2i-devops-prod/redshift/axiom/db_tmpLogs/${tmpLogs}"
                upload=`aws s3 cp --profile ${profile} tmpLogs.txt s3://a2i-devops-prod/redshift/axiom/db_tmpLogs/${tmpLogs}`
        fi
        echo "Finding unused tables for ${dbName}"
        findUnusedTables
}

####################################### FINDING UNUSED TABLES #########################################

findUnusedTables(){

        echo "Started comparison of tables for $dbName"
        
        while read line
        do
                echo "Cheking for $line"
                localSchemaName=`echo $line | cut -d '.' -f1`
                localTableName=`echo $line | cut -d '.' -f2`
                # echo "Cheking for localSchemaName $localSchemaName and localTableName $localTableName"
                # echo "Command to run is : grep -i -w -m 1 -E \"${localSchemaName}.{0,3}${localTableName}\" tmpLogs.txt | wc -l"

                res=`grep -i -w -m 1 -E "${localSchemaName}.{0,3}${localTableName}" tmpLogs.txt | wc -l`
                # echo "res is ${res}"
                if [[ $res -eq 0 ]]
                then
                        echo "Adding ${line} into unused table list"
                        schemaList+=(${localSchemaName})
                        tableList+=(${localTableName})
                        # echo "<tr><td>${line}</td></tr>" >> tmpMail.txt
                fi
        done < 'tmpTableList.txt'

}

####################################### SENDING EtmpMail #########################################

sendEMail(){
        echo '<br>In case of any concern kindly reach out to team DevOps.<br><br>' >> tmpMail.txt
        echo '<p>Regards,<br>Team DevOps</p>' >> tmpMail.txt
        echo '</pre>' >> tmpMail.txt

        aws ses send-email \
        --from "${fromEmail}" \
        --destination "ToAddresses=${toMailList}","CcAddresses=${leadsMailList},${devopsMailList},anuj.kaushik@axiomtelecom.com" \
        --message "Subject={Data= $profile | Unused Database Tables | $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data='$(cat tmpMail.txt)',Charset=utf8}}" \
        --profile $profile

        # ##Test Parameters
        # aws ses send-email \
        # --from "$fromEmail" \
        # --destination "ToAddresses=sanchi.bansal@intsof.com, yogesh.patil@axiomtelecom.com" \
        # --message "Subject={Data= $profile | Unused Database Tables | $(date '+%d-%m-%Y') ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data='$(cat tmpMail.txt)',Charset=utf8}}" \
        # --profile $profile
}

getTableSize(){
        schemaList=$(printf "'%s'," "${schemaList[@]}")
        schemaList=$(echo "${schemaList}" | sed 's/,$//g')
        tableList=$(printf "'%s'," "${tableList[@]}")
        tableList=$(echo "${tableList}" | sed 's/,$//g')
        
        query="select \"database\", \"schema\", \"table\", \"size\" from SVV_TABLE_INFO where \"schema\" in (${schemaList}) AND \"table\" in (${tableList});"

        executeQueryAndGetResults "${query}"
        
        echo "Length of result${#results}"

        echo "<h4>Please find below, list of unused tables in $dbName database of $profile account from last 7 days.</h4>" >> tmpMail.txt
        echo '<table BORDER=3 BORDERCOLOR=#0000FF BORDERCOLORLIGHT=#33CCFF BORDERCOLORDARK=#0000CC width= 80%>' >> tmpMail.txt
        echo "<tr><th>Database</th><th>Schema</th><th>Table</th><th>Size</th></tr>" >> tmpMail.txt

        for result in ${results[@]}
        do
                db=$(echo ${result} | cut -d ',' -f1)
                schema=$(echo ${result} | cut -d ',' -f2)
                table=$(echo ${result} | cut -d ',' -f3)
                size=$(echo ${result} | cut -d ',' -f4)
                echo "<tr><td>${db}</td><td>${schema}</td><td>${table}</td><td>${size}</td></tr>" >> tmpMail.txt
        done

        echo '</table>' >> tmpMail.txt
        echo '<span style="color:blue;">==================================================================</span>' >> tmpMail.txt
}

####################################### DELETING OLD LOGS #########################################

deleteOldLogs(){
        #get logs
        bucket_logs=$(aws s3 ls s3://a2i-devops-prod/redshift/${dbClient}/db_tmpLogs/ --profile prod)
        #set the epoch form of 1 month ago date
        log_date_limit=$(date -d '1 month ago' +%s)

        #for each log file
        while IFS= read -r line
        do
                #extract log creation date
                log_creation_date=$(echo "${line}" | rev | cut -d ' ' -f1 | rev | cut -d_ -f1)
                #extract log name
                log_name=$(echo "${line}" | rev | cut -d ' ' -f1 | rev)
    
                #compare log creation date with one month ago date
                if [ ${log_creation_date} -lt ${log_date_limit} ]
                then
                        #delete the log if it was created a month ago
                        echo "delete ${log_name}"
                        # aws s3 rm s3://a2i-devops-prod/redshift/${dbClient}/db_tmpLogs/${log_name} --profile prod
                fi
        done <<< "${bucket_logs}"
}

####################################### DELETING FILES CREATED #########################################

cleanUp(){
        rm tmp*
}

####################################### MAIN CODE #########################################

setProfile
getSSMParameters
getTableListAndLogs
getTableSize
sendEMail
deleteOldLogs
cleanUp