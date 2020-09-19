#!/bin/bash

filename=access_list.txt
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_stage/rootpassword" --with-decryption --profile  stage --output text --query Parameter.Value`
hostname=axiom-rnd-dwh.hyke.ai
dbname=hyke
user=axiom_rnd

provideAccessToAllSchemas(){
  echo "All schema access modules for groupname $local_groupname and permissions are $local_permissions"

        if [[ $permissions == "READ" ]]; then

            while read schema; do
            #do
                sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sql="${sql1}${sql2}${sql3}"
                echo "Final sql is $sql"
                psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
            done < schema_list.txt
        elif [[ $permissions == "READWRITE"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sql="${sql1}${sql2}${sql3}"
                echo "Final sql is $sql"
                psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
            done < schema_list.txt
        elif [[ $permissions == "MASTER"  ]]; then
            #statements
            while read schema; do
                sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
                sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
                sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
                sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupname;"
                sql="${sql1}${sql2}${sql3}${sql4}"
                echo "Final sql is $sql"
                psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
            done < schema_list.txt
        else
            echo "Wrong Permission levels for $groupname"
       fi
    #fi
}

provideAccessToSpecificSchemas(){
  echo "Specific schema access modules"
   if [[ $permissions == "READ" ]]; then

       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT SELECT ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sql="${sql1}${sql2}${sql3}"
           echo "Final sql is $sql"
           psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
       done;

   elif [[ $permissions == "READWRITE"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sql="${sql1}${sql2}${sql3}"
           echo "Final sql is $sql"
           psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
       done;
   elif [[ $permissions == "MASTER"  ]]; then
       #statements
       echo $schemas | tr "," "\n" | while read -r schema;
       do
           sql1="GRANT ALL PRIVILEGES  ON ALL TABLES IN SCHEMA $schema TO GROUP $groupname;"
           sql2="ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO GROUP $groupname;"
           sql3="GRANT USAGE ON SCHEMA $schema TO GROUP $groupname;"
           sql4="GRANT ALL PRIVILEGES ON SCHEMA $schema TO GROUP $groupname;"
           sql="${sql1}${sql2}${sql3}${sql4}"
           echo "Final sql is $sql"
           psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
       done;
   else
       echo "Wrong Permission levels for $groupname"
  fi
}

while read line; do
  if [[ $line == "" ]]; then ##if1
      echo "Skipping empty line"
  else
        groupname=`echo $line | cut -d ' ' -f1`
        echo "I am modifying group $groupname"
        groupflag=`echo group_list.txt | grep -e $groupname | wc -l`
        # if [[ $groupflag -lt 1 ]]; then
        #   #statements
        #   echo ""
        # fi
        permissions=`echo $line | cut -d ' ' -f2`
        echo "Permission levels are $permissions"
        schemas=`echo $line | cut -d ' ' -f3-`
        echo "List of groups are $schemas"

        if [[ $schemas == 'ALL' ]]; then
          #statements
          echo "Permissions are for ALL the schemas"
          provideAccessToAllSchemas
        else
          echo "Permissions are for Specific schemas"
          provideAccessToSpecificSchemas
        fi
  fi
done < $filename
