#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
env='prod'
profile=${env}
# parameters='i-0bd8e105dcf45dff7 t3.large
# i-01f650827029c6936 t3.medium'
echo "parameters are $parameters"

#######################################################################
############################# Generic Code ############################
#######################################################################

sendMail(){

echo "Fetching instance name from $profile environment"
queryToReplace="Tags[?ResourceId==\`${instanceID}\`].Value"
#secho "Query to replace is $queryToReplace"
instanceName=`aws ec2 describe-tags --filters Name=resource-type,Values=instance Name=key,Values=Name --output text --query $queryToReplace --profile $profile`
echo "Sending email for $instanceName instance inconsistency"

        aws ses send-email \
        --from "a2isupport@axiomtelecom.com" \
        --destination "ToAddresses=yogesh.patil@axiomtelecom","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com" \
        --message "Subject={Data=AWS $profile | $instanceName instance does not have desired instance type $expectedType ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi Team\, <br><br> The $instanceName instance in $profile environment is expected to have <b> $expectedType </b> instance type but currently it is <b> $currentType </b> <br> <br> <b>Please check this on priority ..!! </b><br><br> Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env
        #
        # aws ses send-email \
        # --from "a2isupport@axiomtelecom.com" \
        # --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com,m.naveenkumar@axiomtelecom.com,sandeep.sunkavalli@tothenew.com,shorveer.singh@tothenew.com" \
        # --message "Subject={Data= AWS $environment $serviceName temp Access Provisioned $firstName $lastName $organization ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi All <br><br> AWS temp access on service $serviceName has been provisioned to $username .<br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        # --profile $env
sleep 5

}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

validator(){

  echo 'Inside validator'
	currentType=`aws ec2 describe-instances --instance-ids "$instanceID" --output text --query Reservations[].Instances[].InstanceType --profile $profile`
	echo "current type is $currentType"
      if [[ "$currentType" == "$expectedType" ]]; then
  	  echo "The instance types are matching ... moving ahead ...!"
	else
      echo "The expected instance type is $expectedType and current is $currentType "
  	  echo "The instance types does not match ... need to trigger mail ...!"
      sendMail
	fi

}

#######################################################################
############################# Main Function ###########################
#######################################################################

echo "$parameters" | while read line; do
	instanceID=`echo "$line" | cut -d ' ' -f1`
	expectedType=`echo "$line" | cut -d ' ' -f2`
	echo "the instance is $instanceID and expected type is $expectedType"
  validator
done
