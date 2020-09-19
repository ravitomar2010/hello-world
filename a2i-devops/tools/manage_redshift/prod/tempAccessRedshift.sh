#!/bin/bash
###Author Ravi Tomar###
###Dated 28 june 2020 #####
#### Description : used to give temp access to redshift users #########

######################## Variable Declaration ###############
DatabaseName=$databasename
groupname="mstr_$DatabaseName"
username=$redshiftUserName

################################# Get Connection ################
GetConnection(){
masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
hostname=axiom-prod-dwh.hyke.ai
dbname=axiom_stage
user=axiom_stage
existinguserlistssm=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value`
}

################################# send email and Add user function ##############
sendingMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=ravi.tomar@intsof.com","CcAddresses=ravi.tomar@intsof.com,yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=Redshift Temp Access Provisioned $username ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi <br> <br> Temp Redshift access on database $groupname has been provisioned to $username.<br><br>Please check<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile stage

}

addUser(){
          GetConnection
          echo "Adding user for temp access"
          echo "I am adding user $username in group $groupname"
          sql="alter group $groupname add user $username"
          echo "sql is $sql"
          result=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`
          echo $result
          if [ $? -eq 0 ]
          then
              echo sendingEmail
              sendingMail
          fi

}
################################### Main Code #####################

addUser
