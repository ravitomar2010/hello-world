#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

#env='prod'
#purpose='This is test purpose'
#profile='stage'
##client='axiom'
#username='batch_active'
#emailid='yogesh.patil@axiomtelecom.com'
#filename='tmpLambdaListNames.txt'
#workingLambdaName=''
#schemaName='demand_forecast_dbo'

#######################################################################
############################# Generic Code ############################
#######################################################################


#######################################################################
######################### Feature Function Code #######################
#######################################################################

mailDetails(){
  echo 'Sending details to user'

  userToMail=`echo $BUILD_USER | cut -d '.' -f1`
  userToMail=`echo "${userToMail^}"`

  aws ses send-email \
  --from "a2isupport@axiomtelecom.com" \
  --destination "ToAddresses=${BUILD_USER_EMAIL}","CcAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data= $env | $username password extraction ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi ${userToMail} <br> Please find below details extracted from AWS. <br><br> Username: $username<br>Password: $password<br><br>Regards<br>Devops Team ,Charset=utf8}}" \
  --profile $profile

  sleep 10

  aws ses send-email \
  --from "a2isupport@axiomtelecom.com" \
  --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com" \
  --message "Subject={Data= $env | $username password extraction ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> This is to inform you that ${BUILD_USER} has extracted a password for $username from $env account. <br>The specified purpose by user is - <b> $purpose </b> <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
  --profile $profile

}


failureEmail(){

  aws ses send-email \
  --from "a2isupport@axiomtelecom.com" \
  --destination "ToAddresses=${BUILD_USER_EMAIL}","CcAddresses=yogesh.patil@axiomtelecom.com" \
  --message "Subject={Data= $env | $username password extraction - Failure notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi ${userToMail} <br><br> This seems that you are not specifying proper reason for extracting the batch password - <b> please specify the proper reason and rerun the job. </b> <br><br>Regards<br>Devops Team ,Charset=utf8}}" \
  --profile $profile

}

fetchPassword(){
  echo "Fetching pasword for $username from $env account"
  password=`aws ssm get-parameter --name /a2i/$env/redshift/users/$username --with-decryption --output text --query Parameter.Value --profile $profile`
}

setUserName(){
  echo 'calculating username'
  if [[ $schemaName =~ '_dbo' ]]; then
    echo 'This is standard schemaName with _dbo suffix'
    username=batch_$(echo $schemaName | rev | cut -c5- | rev)
    echo "username is $username"
  elif [[ $schemaName =~ '_stage' ]];then
    echo 'This is standard schemaName with _stage suffix'
    username=batch_$(echo $schemaName | rev | cut -c7- | rev )
    echo "username is $username"
  else
    echo 'This is not standard schemaName'
    username=batch_$(echo $schemaName)
    echo "username is $username"
  fi
}

checkRawExtraction(){
  username="batch_$schemaName"
  echo "Fetching password for $username from $env account"
  password=`aws ssm get-parameter --name /a2i/$env/redshift/users/$username --with-decryption --output text --query Parameter.Value --profile $profile`

  if [[ $password == '' ]]; then
      echo 'The parameter doesnt exists - I will follow the regular execution'
  else
      echo "I found the password for $schemaName - I am mailing the details"
      mailDetails
      exit 1
  fi
}

#######################################################################
############################# Main Function ###########################
#######################################################################

profile=$env

if [[ "$purpose" == '' ]]; then
  echo 'purpose is missing need to trigger failure mail'
  failureEmail
else
  checkRawExtraction
  setUserName
  fetchPassword
  mailDetails
fi


#############################
########## CleanUp ##########
#############################

echo "Working on clean-up"
#rm -rf ./tmp*
