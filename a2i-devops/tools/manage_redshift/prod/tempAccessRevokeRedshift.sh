#!/bin/bash
########################## Get Conncetion ###################
getconnection(){
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage
existinguserlistssm=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value`
}

############################# Get list of isers in group ###############
getgroupuserlist(){
  groupname=$1
  getconnection
  sql="select usename from pg_user , pg_group  where pg_user.usesysid = ANY(pg_group.grolist) and pg_group.groname='$groupname'"
  echo "sql is $sql"
  userlist=`psql -qAt "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`
  echo $userlist
}

################################## Remove users ##########################

removeuser(){

    user=$1
    group=$2
    echo removing $user from $group
    echo "I am removing $user  in group $group"
    sql="alter group $group DROP user $user"
    echo "query is $sql"
    getconnection
    result=`psql -qAt "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`
    echo $result
}

addUser(){
          GetConnection
          username=$1
          groupname=$2
          echo "Adding nifi user access"
          echo "I am adding user $username in group $groupname"
          sql="alter group $groupname add user $username"
          echo "sql is $sql"
          result=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`
          echo $result
}

################################ Main Code ################################

groups=("mstr_axiom" "mstr_hyke")
for group in ${groups[@]}
do
getgroupuserlist $group
        for user in ${userlist[@]}
        do
        removeuser $user $group
        done
        unset userlist
done

addUser nifi_hyke mstr_axiom
addUser nifi_axiom mstr_axiom
addUser nifi_hyke mstr_hyke
addUser nifi_axiom mstr_hyke



############################## Listing users post removal ###################
getgroupuserlist mstr_axiom
getgroupuserlist mstr_hyke
