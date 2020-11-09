#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpUsersList.txt
awsPassword='Password@A2i'
rsUsername=''
rsPasswordProd=''
rsPasswordStage=''
ldapPassword=''
profile='prod'

############################# Test Parameters #########################

# users='raveen.sharma@intsof.com'

#######################################################################
############################# Generic Code ############################
#######################################################################

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

removeAWSEntries(){
	localUserName=$1
	localOrg=$2
	localEmail=$3
  groupname="base$localOrg"
	echo "Removing AWS user entries for $localUserName for $localOrg with email $localEmail in group $groupname in env ${profile}"
  # echo "User: ${localUserName} and Environment: ${profile}"
  userExistsFlag=`aws iam list-users --profile ${profile} | grep ${localUserName} | wc -l`
  if [[ ${userExistsFlag} -gt 1 ]]; then
     echo "User ${localUserName} exists in AWS - Eligible to delete"

     echo 'Fetching exact userName from AWS'
     localUserName=`aws iam list-users --profile ${profile} --query Users[*].UserName | grep ${localUserName} | tr -d ',' | tr -d '"' | tr -d ' '`
     echo "Fetched user name is ${localUserName}"
      ########################### Detecting user policies ##########################################

      userPolicies=$(aws iam list-user-policies --user-name ${localUserName} --query 'PolicyNames[*]' --profile ${profile} --output text)

      ############################# Deleting user policies ##########################################

      echo "Deleting user policies: ${userPolicies}"
      for policy in ${userPolicies} ;
      do
        echo "aws iam delete-user-policy --user-name ${localUserName} --profile ${profile} --policy-name $policy"
        aws iam delete-user-policy --user-name ${localUserName} --profile ${profile} --policy-name $policy
      done

      ############################# Detecting user attached policies ##########################################

      userAttachedPolicies=$(aws iam list-attached-user-policies --user-name ${localUserName} --query 'AttachedPolicies[*].PolicyArn' --profile ${profile} --output text)

      ############################# Deleting user attached policies ##########################################

      echo "Detaching user attached policies: ${userAttachedPolicies}"
      for policyARN in ${userAttachedPolicies} ;
      do
        aws iam detach-user-policy --user-name ${localUserName} --profile ${profile} --policy-arn $policyARN
      done

      ############################ Detecting user attached groups ##############################################

      userGroups=$(aws iam list-groups-for-user --user-name ${localUserName} --query 'Groups[*].GroupName' --profile ${profile} --output text)

      ############################ Detaching user attached groups ##############################################

      echo "Detaching user attached group: $userGroups"
      for group in $userGroups ;
      do
        aws iam remove-user-from-group --user-name ${localUserName} --profile ${profile} --group-name $group
      done

      ############################ Detecting user access keys ##############################################

      userAccessKeys=$(aws iam list-access-keys --user-name ${localUserName} --query 'AccessKeyMetadata[*].AccessKeyId' --profile ${profile} --output text)

      ############################ Deleting user access keys ##############################################

      echo "Deleting user access keys: $userAccessKeys"
      for key in $userAccessKeys ;
      do
        aws iam delete-access-key --user-name ${localUserName} --profile ${profile} --access-key-id $key
      done

      ############################ Deleting user login profile ##############################################

      echo "Deleting user login profile"
      aws iam delete-login-profile --profile ${profile} --user-name ${localUserName}

      ############################ Deleting user ############################################################

      echo "Deleting user: $user"
      aws iam delete-user --profile ${profile} --user-name ${localUserName}
  else
      echo "Skipping user deletion for ${localUserName} as it doesn't exists in ${profile} account."
  fi
}

removeRedshiftEntries(){
	localUserName=$1
	localOrg=$2
	localEmail=$3
	firstname=`echo $localUserName | cut -d '.' -f1`
	lastname=`echo $localUserName | cut -d '.' -f2`
	# echo "Firstname is $firstname and lastname is $lastname and organization is $localOrg"
	localUserName=`echo "${firstname}_${lastname}"`
	rsUsername=`echo "${firstname}_${lastname}"`

  # groupname="base$localOrg"
			echo "Removing Redshift user entries for $localUserName for $localOrg"
			if [[ $localOrg == *"tothenew"* ]]; then
					groupname="read_ttn"
			elif [[ $localOrg == *"intsof"* ]]; then
					groupname="read_intsoft"
			elif [[ $localOrg == *"axiomtelecom"* ]]; then
					groupname="read_axiom"
			else
					echo "Organization $localOrg not found !!"
			fi
	echo "Group name is $groupname"
  cd ../manage_redshift && ./dropUsers.sh "$localUserName" 'prod' && cd -
  cd ../manage_redshift && ./dropUsers.sh "$localUserName" 'stage' && cd -
}

removeLDAPEntries() {
	localUserName=$1
	localOrg=$2
	localEmail=$3

	basedn='dc=a2i,dc=infra'
  masterusername="cn=admin,$basedn"
	masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
  # echo "MasterUsername is ${masterusername} and MasterPassword is ${masterpassword}"
  binduser="uid=ldap,$basedn"
	bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
  # echo "BindUserName is ${binduser} and BindPassword is ${bindpassword}"
	ldapuri="ldap://ldap.hyke.ae:389"
	LDAP_USER_GROUP="cn=ldap-basic,ou=groups,${basedn}"

	existinguserlist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" cn | grep -e '^cn:' | cut -d':' -f2`
	# echo "$existinguserlist"
  ldapUserExistsFlag=`echo ${existinguserlist} | grep ${localUserName} | wc -l`
  # ldapUserExistsFlag=1
  if [[ ${ldapUserExistsFlag} -gt 0 ]]; then
      echo "User $localUserName exists and is eligible to delete"
      # echo "ldapdelete -v -D \"$binduser\" -w \"$bindpassword\" -H $ldapuri -W \"uid=${localUserName},ou=people,${basedn}\""
      ldapdelete -v -D "${masterusername}" -w "${masterpassword}" -H $ldapuri "cn=${localUserName},ou=users,${basedn}"
  else
      echo "User $localUserName doesn't exists hence exiting"
  fi
}

sendMail(){
	localUserName=$1
	localEmail=$2
	local_vpnURL=$3
	local_vpnPin=$4
  profile='prod'
	getSSMParameters
  prepareOutput

	### # Code to send mail using local smtp
	### (echo "To: $localEmail" && echo "Subject: A2i platform credentials" && echo -e "\n Welcome to A2i Family \n\n Please use below credentials to login to A2i platform" &&
	### echo -e "\n - Production Credentials \n\n A. AWS \n URL: https://hyke-admin.signin.aws.amazon.com/console \n Username: $localEmail \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUsername \n Passowrd: $rsPasswordProd \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$localUserName \n Passowrd: $ldapPassword" &&
	### echo -e "\n - Stage Credentials \n\n A. AWS \n URL: https://a2i-stage.signin.aws.amazon.com/console \n Username: $localEmail \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUsername \n Passowrd: $rsPasswordStage \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$localUserName \n Passowrd: $ldapPassword " &&
	### echo -e "\n - VPN \n\n Profile URL: $local_vpnURL \n Pin: $local_vpnPin " &&
	### #echo -e "\n Please use following credentials to login to A2i tools(Jenkins, Grafana etc.) \n URL: http://grafana.hyke.ae:3000/ \n Username:$localUserName \n Passowrd: $ldapPassword" &&
	### echo -e "\n Please reach out to devops team in case of any issues \n\n") | msmtp $localEmail

  ### # # Code to send mail to local user
	### aws ses send-email \
	### --from "a2isupport@axiomtelecom.com" \
	### --destination "ToAddresses=$localEmail","CcAddresses=yogesh.patil@axiomtelecom.com" \
	### --message "Subject={Data=A2i credentials | $username ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
	### --profile prod

  # # Code to send mail to leads
	aws ses send-email \
	--from "a2isupport@axiomtelecom.com" \
	--destination "ToAddresses=$leadsMailList","CcAddresses=$devopsMailList,anuj.kaushik@axiomtelecom.com" \
	--message "Subject={Data=A2i-Offboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>offboarding for $username is completed</b> and all the available credentials (AWS\, Redshift\, LDAP and VPN) has been disabled/ deleted. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
	--profile prod

  ### Code to send mail to devops for testing
  #
  # aws ses send-email \
  # --from "a2isupport@axiomtelecom.com" \
  # --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=${devopsMailList}" \
  # --message "Subject={Data=A2i-Offboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>offboarding for $username is completed</b> and all the available credentials (AWS\, Redshift\, LDAP and VPN) has been disabled/ deleted. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
  # --profile prod

}

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "<p style=font-size:15px;>Hi $firstname\, <br>Welcome to A2i Family ...!! <br>Please use below credentials to login to A2i platform</p>" >> tmpFinalOP.txt


	# echo "<b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++</b><br>" >> tmpFinalOP.txt
	echo '<table BORDER=2;BORDERCOLOR=#0000FF;BORDERCOLORLIGHT=#33CCFF;BORDERCOLORDARK=#0000CC; >' >> tmpFinalOP.txt
	# echo '<table>' >> tmpFinalOP.txt

	# echo "<tr><td colspan=3><b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++----------++++++++++</b></td></tr>" >> tmpFinalOP.txt

	echo "<tr><td colspan=3><b style=font-size:15px;color:#339CFF;>Production Credentials:</b></td></tr>" >> tmpFinalOP.txt

	### AWS
	echo "<tr><td width=15px;><b>A</b></td> <td colspan=3><b>AWS</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b></b>https://hyke-admin.signin.aws.amazon.com/console</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$localEmail</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$awsPassword</b></td> </tr>" >> tmpFinalOP.txt
	# echo "<tr><td colspan=3;>     ----------------------------------     </td> </tr>" >> tmpFinalOP.txt

	### Redshift
	echo "<tr><td width=15px;><b>B</b></td> <td colspan=3><b>Redshift</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b></b>axiom-prod-dwh.hyke.ai</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$rsUsername</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$rsPasswordProd</b></td> </tr>" >> tmpFinalOP.txt

	### LDAP
	echo "<tr><td width=15px;><b>C</b></td> <td colspan=3><b>LDAP - (can be used to login to tools like prod-nifi)</b></td> </tr>" >> tmpFinalOP.txt
	# echo "<tr><td width=15px;><b></b></td> <td><b>LDAP(can be used to login to tools like nifi\, jenkins etc.)</b></td> <td><b></b>axiom-prod-dwh.hyke.ai</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$localUserName</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$ldapPassword</b></td> </tr>" >> tmpFinalOP.txt


	echo "<tr><td colspan=3><b style=font-size:15px;color:#339CFF;>Stage Credentials:</b></td></tr>" >> tmpFinalOP.txt

	### AWS
	echo "<tr><td width=15px;><b>A</b></td> <td colspan=3><b>AWS</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b></b>https://a2i-stage.signin.aws.amazon.com/console</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$localEmail</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$awsPassword</b></td> </tr>" >> tmpFinalOP.txt
	# echo "<tr><td colspan=3;>     ----------------------------------     </td> </tr>" >> tmpFinalOP.txt

	### Redshift
	echo "<tr><td width=15px;><b>B</b></td> <td colspan=3><b>Redshift</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b></b>axiom-rnd-dwh.hyke.ai</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$rsUsername</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$rsPasswordStage</b></td> </tr>" >> tmpFinalOP.txt

	### LDAP
	echo "<tr><td width=15px;><b>C</b></td> <td colspan=3><b>LDAP - (can be used to login to tools like stage-nifi\, jenkins\, grafana etc.)</b></td> </tr>" >> tmpFinalOP.txt
	# echo "<tr><td width=15px;><b></b></td> <td><b>LDAP(can be used to login to tools like nifi\, jenkins etc.)</b></td> <td><b></b>axiom-prod-dwh.hyke.ai</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$localUserName</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$ldapPassword</b></td> </tr>" >> tmpFinalOP.txt


	### VPN
	echo "<tr><td width=15px;><b>C</b></td> <td colspan=3><b>VPN - (need to use for accessing all the private services/ portals.)</b></td> </tr>" >> tmpFinalOP.txt
	# echo "<tr><td width=15px;><b></b></td> <td><b>LDAP(can be used to login to tools like nifi\, jenkins etc.)</b></td> <td><b></b>axiom-prod-dwh.hyke.ai</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b>$local_vpnURL</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Pin</b></td> <td><b>$local_vpnPin</b></td> </tr>" >> tmpFinalOP.txt

  # echo "<br>==========================================================" >> tmpFinalOP.txt
	# echo "==========================================================" >> tmpFinalOP.txt
	echo '</table>' >> tmpFinalOP.txt
	# echo "<b style=font-size:12px;color:#339CFF;>+++++++++----------++++++++++----------++++++++++----------++++++++++</b><br>" >> tmpFinalOP.txt

  echo "<br><p style=font-size:15px;>Please reach out to DevOps in case of any concerns. <br>Regards\,<br>DevOps Team</p>" >> tmpFinalOP.txt
  echo '</pre>' >> tmpFinalOP.txt

}

#######################################################################
############################# Main Function ###########################
#######################################################################

echo 'Creating support files'
echo "$users" > tmpUsersList.txt

echo "Removing VPN entries"

python3 vpnHandler.py

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
			echo "I am deleting user for $line"
			username=`echo $line | cut -d '@' -f1`
			organization=`echo $line | cut -d '@' -f2 | cut -d '.' -f1`
			email=`echo $line | cut -d ' ' -f1`
		  firstname=`echo $username | cut -d '.' -f1 `
			echo "Username is $username , firstname is ${firstname}, organization is $organization and email is $email"
			echo "Removing AWS entries"
      profile='prod'
			removeAWSEntries $username $organization $email $profile
      profile='stage'
			removeAWSEntries $username $organization $email $profile
			echo "Removing Redshift entries"
			removeRedshiftEntries $username $organization $email
			echo "Removing LDAP entries"
			removeLDAPEntries $username $organization $email
			echo "Sending email"
			sendMail $username $email $vpnURL $vpnPin
  	fi #if1
done < $filename

# #############################
# ########## CleanUp ##########
# #############################

echo 'Working on workspace cleanup'
rm -rf ./tmp*
