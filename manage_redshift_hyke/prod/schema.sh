#!/bin/bash

filename=schema_list.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=hyke
user=axiom_stage

#Get the list of existing schemas
sql="select s.nspname as table_schema from pg_catalog.pg_namespace s join pg_catalog.pg_user u on u.usesysid = s.nspowner order by table_schema;"
existingschemalist=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`

checkIfUserExistsAndMakeEntry(){
  local_schema_name=$1
  #echo "$local_schema_name"

  if [[ $local_schema_name == *"dbo"* ]]; then
    #echo "$local_schema_name contains dbo"
    temp_schema_name=`echo $local_schema_name | rev | cut -c 5- | rev`
    #echo "Temporary group name is mstr_batch_$temp_schema_name"
    #echo "Temporary user name is batch_$temp_schema_name"
    userentryflag=`cat ../../manage_redshift/prod/users_list.txt  | grep "batch_$temp_schema_name" | wc -l`
    groupentryflag=`cat ../../manage_redshift/prod/groups_list.txt  | grep "mstr_batch_$temp_schema_name" | wc -l`
    accessentryflag=`cat access_list.txt | grep "mstr_batch_$temp_schema_name" | wc -l`
    if [[ $userentryflag -eq 0 ]]; then
        echo "User entry doesnt exists"
        echo "batch_$temp_schema_name mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/users_list.txt
    fi
    if [[ $groupentryflag -eq 0 ]]; then
        echo "Group entry doesnt exists"
        echo "mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/groups_list.txt
    fi
    if [[ $accessentryflag -eq 0 ]]; then
        echo "Access entry doesnt exists"
        echo "mstr_batch_$temp_schema_name MASTER audit_sysmgmt, $local_schema_name, ${temp_schema_name}_stage" >> access_list.txt
        #echo "mstr_batch_$temp_schema_name MASTER {$temp_schema_name}_dbo, " >> groups_list.txt
    fi

  elif [[ $local_schema_name == *"stage"* ]]; then
    #echo "$local_schema_name contains dbo"
    temp_schema_name=`echo $local_schema_name | rev | cut -c 7- | rev`
    #echo "Temporary group name is mstr_batch_$temp_schema_name"
    #echo "Temporary user name is batch_$temp_schema_name"
    userentryflag=`cat ../../manage_redshift/prod/users_list.txt  | grep "batch_$temp_schema_name" | wc -l`
    groupentryflag=`cat ../../manage_redshift/prod/groups_list.txt  | grep "mstr_batch_$temp_schema_name" | wc -l`
    accessentryflag=`cat access_list.txt | grep "mstr_batch_$temp_schema_name" | wc -l`

    if [[ $userentryflag -eq 0 ]]; then
        echo "User entry doesnt exists"
        echo "batch_$temp_schema_name mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/users_list.txt
    fi
    if [[ $groupentryflag -eq 0 ]]; then
        echo "Group entry doesnt exists"
        echo "mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/groups_list.txt
    fi
    if [[ $accessentryflag -eq 0 ]]; then
        echo "Access entry doesnt exists"
        echo "mstr_batch_$temp_schema_name MASTER audit_sysmgmt, $local_schema_name, ${temp_schema_name}_dbo" >> access_list.txt
        #echo "mstr_batch_$temp_schema_name MASTER {$temp_schema_name}_dbo, " >> groups_list.txt
    fi
  else
      #echo "$local_schema_name is individual group"
      #echo "$local_schema_name contains dbo"
      temp_schema_name=`echo $local_schema_name`
      #echo "Temporary group name is mstr_batch_$temp_schema_name"
      #echo "Temporary user name is batch_$temp_schema_name"
      userentryflag=`cat ../../manage_redshift/prod/users_list.txt  | grep "batch_$temp_schema_name" | wc -l`
      groupentryflag=`cat ../../manage_redshift/prod/groups_list.txt  | grep "mstr_batch_$temp_schema_name" | wc -l`
      accessentryflag=`cat access_list.txt | grep "mstr_batch_$temp_schema_name" | wc -l`

      if [[ $userentryflag -eq 0 ]]; then
          echo "User entry doesnt exists"
          echo "batch_$temp_schema_name mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/users_list.txt
      fi
      if [[ $groupentryflag -eq 0 ]]; then
          echo "Group entry doesnt exists"
          echo "mstr_batch_$temp_schema_name" >> ../../manage_redshift/prod/groups_list.txt
      fi
      if [[ $accessentryflag -eq 0 ]]; then
          echo "Access entry doesnt exists"
          echo "mstr_batch_$temp_schema_name MASTER audit_sysmgmt, $local_schema_name" >> access_list.txt
          #echo "mstr_batch_$temp_schema_name MASTER {$temp_schema_name}_dbo, " >> groups_list.txt
      fi
  fi

}

while read line; do

  if [[ $line == "" ]]; then #if 1
    echo "Skipping empty line"
  else
      schemaname=$line
      isschemaexists=`echo $existingschemalist | grep $schemaname| wc -l`

      if [[ $isschemaexists -gt 0 ]]; then #if 2
          echo "Schema $schemaname already exists"
          #echo "batch_$schemaname mstr_batch_$schemaname"
          checkIfUserExistsAndMakeEntry $schemaname
          #cat ../../manage_redshift/prod/users_list.txt
      else
          echo "I am creating schema $schemaname"
          sql="create schema if not exists $schemaname;"
          echo "sql is $sql"
          psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
          checkIfUserExistsAndMakeEntry $schemaname
      fi #if 2

  fi #if 1
done < $filename
