#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

repoName=$1

############################# Test Parameters #########################

# repoName='devops-test'
# description='This repository hosts the code for devops test code'

#######################################################################
############################# Generic Code ############################
#######################################################################

##### Generic code block

#######################################################################
######################### Feature Function Code #######################
#######################################################################

createSupportingDirectories(){
    if [[ ${repoName} == *a2i-data* ]]; then
        echo 'RepoName already contains a2i-data prefix'
    else
        echo 'Appending a2i-data to RepoName'
        repoName="a2i-data-${repoName}"
    fi

    mkdir -p /data/tempRepos/${repoName}
    mkdir -p /data/tempRepos/${repoName}/lambda
    touch /data/tempRepos/${repoName}/lambda/.gitkeep
    mkdir -p /data/tempRepos/${repoName}/scripts
    touch /data/tempRepos/${repoName}/scripts/.gitkeep
}

createReadmeFile(){
  readme="${repoName} \n

      This project has following generic A2i code structure.
           Repo
              |
              |-lambda
              |-scripts
              |-Jenkinsfile
              |-README.md

      To create lambda please create subdirectory with lambda_name in lambda folder.

           Repo
              |-lambda
              |    |
              |    |-lambda_name1
              |    |-lambda_name2
              |    |-lambda_name3
              |
              |-scripts
              |-Jenkinsfile
              |-README.md

      To create manual scripts which needs to be hosted on jenkins please create script_file in scripts folder.

           Repo
              |-lambda
              |    |
              |    |-lambda_name1
              |    |-lambda_name2
              |    |-lambda_name3
              |
              |-scripts
              |    |
              |    |-script_file1
              |    |-script_file2
              |    |-script_file3
              |
              |-Jenkinsfile
              |-README.md

      The Jenkinsfile contains the library name to be refered by devops pipelines.
      README.md file contains all the necessary project structure."

  echo -e "$readme" > README.md
}

createJenkinsFile(){
  Jenkinsfile_content="@Library('hyke-devops-libs') _ \nlambdaPipeline()"
  echo -e "$Jenkinsfile_content" > Jenkinsfile
}

createRepo(){

    if [[ ${repoName} == '' ]]; then
        echo 'No repository provided - exiting'
        exit 1;
    fi

    echo 'Creating support directories'
    createSupportingDirectories

    cd /data/tempRepos/${repoName}

    echo 'Creating repository in github'
    gh repo create axiom-telecom/${repoName} --private -y

    echo 'Initiating the repository'
    git init /data/tempRepos/${repoName}/

    createReadmeFile
    createJenkinsFile

    echo 'Adding content to repository'
    git add /data/tempRepos/${repoName}/

    echo 'Adding comment for first commit'
    git commit -m 'Initial commit'

    git remote add origin git@github.com:axiom-telecom/${repoName}.git

    echo 'Pushing code to remote'
    git push -u origin master
}

#######################################################################
############################# Main Function ###########################
#######################################################################

createRepo

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
sudo rm -rf /data/tempRepo/*
