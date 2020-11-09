#!/bin/bash

####################################################### VARIABLE DECLARATION #############################################

repo_list=${repository}
branch=${branch}
connection_module="connection"

####################################################### SETTING SESSION VARIABLE #############################################

#if branch is production then profile is prod else stage
if [ ${branch} == "production" ]
then
    session="session = boto3.Session(profile_name='prod',region_name='eu-west-1')"
else
    session="session = boto3.Session(profile_name='stage',region_name='eu-west-1')"
fi

####################################################### GIT CLONE REPO #############################################

cloneRepo(){
    if [ ! -d /data/lambdaPipeline ]; then sudo mkdir lambdaPipeline; fi
    
    if [ -d /data/lambdaPipeline/${repo} ]
    then
        echo "Repo ${repo} already exists. Deleting!"
        sudo rm -rf /data/lambdaPipeline/${repo}
        echo "/data/lambdaPipeline/${repo} deleted."
    fi
    echo "Cloning repo: ${repo} in /data/lambdaPipeline/"
    pwd
    sudo git clone git@github.com:axiom-telecom/${repo}.git /data/lambdaPipeline/${repo}/
    if [ ${?} == 0 ]
    then
        echo "Repo cloned successfully"
    else
        echo "Some error ocurred"
        echo "Exiting..."
        exit
    fi
}

####################################################### REPLACING CLIENT WITH SESSION #############################################

replaceClientWithSession(){
    file=$1
    #replace boto3.resource with session.resource
    sudo sed -i 's/boto3.resource/session.resource/g' ${file}

    #replace boto3.client with session.client
    sudo sed -i 's/boto3.client/session.client/g' ${file}

    #removing the line 'session = boto3.Session()'
    session_line=$(cat ${file} | grep 'boto3.Session()')
    if [ ${#session_line} -ne 0 ]; then sudo sed -i "s/${session_line}//g" ${file}; fi
}

####################################################### CREATING SESSION FOR PROFILE #############################################

addSession(){
    file=$1
    #grep import lines
    import_lines=$(cat ${file} | grep ^'import ')
    last_import_line=$(echo "${import_lines}" | tail -1)

    #if file contains import boto3 line then create session for the profile
    if [[ ${import_lines} == *"import boto3"* ]]
    then
        replace_with=$"${last_import_line}\n\n${session}"
        sudo sed -i "s/${last_import_line}/$replace_with/g" ${file}
    fi
}

####################################################### UPDATING BRANCH NAME #############################################

updateBranchName(){
    file=$1
    #Changing branch name
    replace_with="'${branch}'"
    sudo sed -i "s|os.environ\['environment'\]|${replace_with}|g" ${file}
}

####################################################### ADD CONNECTION MODULE #############################################
       
addConnectionModule(){
    conn=$(cat $lambda/${lambda_name}.py | grep 'connection.redshift')

    # add connection module to the lambda if connection.redshift string found in lambda handler
    if [ ${#conn} -ne 0 ]
    then
        echo -e "\nAdding connection module in ${lambda}"
        sudo cp -r ${connection_module} ${lambda}

        replaceClientWithSession ${lambda}/connection/redshift.py
        addSession ${lambda}/connection/redshift.py
        updateBranchName ${lambda}/connection/redshift.py
    fi
}

####################################################### APPENDING LAMBDA HANDLER CALL #############################################

appendLambdaHandlerCall(){

    # lambda_name=$(echo "${lambda}" | rev | cut -d '/' -f1 |rev)
    # method_def_line=$(cat $lambda/${lambda_name}.py | grep -m1 "^def.*(event.*context.*):" )
    # method_call=$(echo "${method_def_line}" | awk '{print $2}' | cut -d '(' -f1 )
    # echo -e "\ns3tords(event=None,context=None)" >> ${lambda}/${lambda_name}.py
    echo -e "\ns3tords(event=None,context=None)" | sudo tee -a /data/lambdaPipeline/${repo}/lambda/${lambda_name}/${lambda_name}.py >> /dev/null
}

####################################################### MAIN CODE #############################################

repo_list="${repo_list},"

######## FOR EACH REPO IN LIST ########
while [ ${#repo_list} -ne 0 ]
do
        repo=$(echo "${repo_list}" | xargs | cut -d ',' -f1)
        repo_list=$(echo "${repo_list}" | xargs | cut -d ',' -f2-)
        echo "Deploying repo ${repo} on branch ${branch}"

        cloneRepo

        ################### FOR EACH LAMBDA ###################
        for lambda in "/data/lambdaPipeline/${repo}/lambda"/*
        do  
            lambda_name=$(echo "$lambda" | rev | cut -d '/' -f1 |rev)
            echo -e "\n--------- Executing for Lambda ${lambda_name} ---------\n"

            ################### FOR EACH PYTHON FILE IN LAMBDA ###################
            for file in "${lambda}"/*.py
            do      
                echo "Updating file ${file}"
                replaceClientWithSession ${file}
                addSession ${file}
                updateBranchName ${file}
                    
            done

            appendLambdaHandlerCall
            #Adding connection module
            addConnectionModule
        done
done