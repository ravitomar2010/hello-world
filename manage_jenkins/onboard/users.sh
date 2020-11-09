#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpUsersList.txt
awsPassword='Password@A2i'
rsUserName=''
rsPasswordProd=''
rsPasswordStage=''
ldapPassword=''
profile='prod'

############################ Test Parameters ##########################

# users='a.b@tothenew.com,a.c@tothenew.com,a.d@tothenew.com,a.e@tothenew.com'

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

createAWSEntries(){
	localUserName=$1
	localOrg=$2
	localEmail=$3
  groupName="base$localOrg"

  if [[ $credLevel == '' ]]; then
      credLevel='UI'
  fi
	echo "Creating AWS prod user entries for $localUserName for $localOrg with email $localEmail in group $groupName"

	cd ../manage_aws/users/ && ./users.sh 'prod' "${credLevel}" "${localEmail}" "$groupName"

  echo "Creating AWS stage user entries for $localUserName for $localOrg with email $localEmail in group $groupName"

  ./users.sh 'stage' "${credLevel}" "${localEmail}" "$groupName" && cd -
}

createRedshiftEntries(){
	localUserName=$1
	localOrg=$2
	localEmail=$3
	firstName=`echo $localUserName | cut -d '.' -f1`
	lastName=`echo $localUserName | cut -d '.' -f2`
	echo "firstName is $firstName and lastName is $lastName and organization is $localOrg"
	# localUserName=`echo "${firstName}_${lastName}"`
	rsUserName=`echo "${firstName}_${lastName}"`

  groupName="base$localOrg"
			echo "Creating Redshift user entries for $localUserName for $localOrg with email $localEmail in group $groupName"
			if [[ $localOrg == *"tothenew"* ]]; then
					org="ttn"
			elif [[ $localOrg == *"intsof"* ]]; then
					org="intsoft"
			elif [[ $localOrg == *"axiomtelecom"* ]]; then
					org="axiom"
			else
					echo "Organization $localOrg not found !!"
			fi
	echo "Group name is read_$org"
  redshift_prod
	redshift_stage
  echo 'Since redshift password is extracted - Removing it from SSM'
  aws ssm delete-parameter --name "/tmp/prod/redshift/${rsUserName}" --profile prod
  aws ssm delete-parameter --name "/tmp/stage/redshift/${rsUserName}" --profile stage

}

redshift_prod(){
  	echo "Creating redshift prod user for $localUserName in group $org"
    cd ../manage_redshift/ && ./users.sh ${localUserName}@${org} 'prod' && cd -
    echo "Created redshift prod entry for ${localUserName} pulling data from SSM"
    rsPasswordProd=`aws ssm get-parameter --name "/tmp/prod/redshift/${rsUserName}" --with-decryption --profile prod --output text --query Parameter.Value`
    echo "Redshift prod password for $rsUserName is $rsPasswordProd"
}

redshift_stage(){
    echo "Creating redshift stage user for $localUserName in group $org"
    cd ../manage_redshift/ && ./users.sh ${localUserName}@${org} 'stage' && cd -
    echo "Created redshift stage entry for ${localUserName} pulling data from SSM"
    rsPasswordStage=`aws ssm get-parameter --name "/tmp/stage/redshift/${rsUserName}" --with-decryption --profile stage --output text --query Parameter.Value`
    echo "Redshift stage password for $rsUserName is $rsPasswordStage"
}

createLDAPEntries() {
  localUserName=$1
	localOrg=$2
	localEmail=$3
  echo "Creating ldap user for $localUserName"
  cd ../manage_ldap/ && ./users.sh ${localEmail} && cd -
  echo "Created ldap entry for ${localUserName} pulling data from SSM"
  ldapPassword=`aws ssm get-parameter --name "/tmp/infra/ldap/${localUserName}" --with-decryption --profile stage --output text --query Parameter.Value`
  echo "LDAP password for ${localUserName} is ${ldapPassword}"
  echo "Removing ldap entry from SSM as parameter is pulled"
  aws ssm delete-parameter --name "/tmp/infra/ldap/${localUserName}" --profile stage

}

sendMail(){
	localUserName=$1
	localEmail=$2
	local_vpnURL=$3
	local_vpnPin=$4
	getSSMParameters
  prepareOutput

	# # Code to send mail using local smtp
	# (echo "To: $localEmail" && echo "Subject: A2i platform credentials" && echo -e "\n Welcome to A2i Family \n\n Please use below credentials to login to A2i platform" &&
	# echo -e "\n - Production Credentials \n\n A. AWS \n URL: https://hyke-admin.signin.aws.amazon.com/console \n Username: $localEmail \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUserName \n Passowrd: $rsPasswordProd \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$localUserName \n Passowrd: $ldapPassword" &&
	# echo -e "\n - Stage Credentials \n\n A. AWS \n URL: https://a2i-stage.signin.aws.amazon.com/console \n Username: $localEmail \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUserName \n Passowrd: $rsPasswordStage \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$localUserName \n Passowrd: $ldapPassword " &&
	# echo -e "\n - VPN \n\n Profile URL: $local_vpnURL \n Pin: $local_vpnPin " &&
	# #echo -e "\n Please use following credentials to login to A2i tools(Jenkins, Grafana etc.) \n URL: http://grafana.hyke.ae:3000/ \n Username:$localUserName \n Passowrd: $ldapPassword" &&
	# echo -e "\n Please reach out to devops team in case of any issues \n\n") | msmtp $localEmail

  # # # Code to send mail to local user
	aws ses send-email \
	--from "a2isupport@axiomtelecom.com" \
	--destination "ToAddresses=$localEmail","CcAddresses=$devopsMailList" \
	--message "Subject={Data=A2i credentials | $username ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
	--profile prod

  # # # # Code to send mail to leads
	# aws ses send-email \
	# --from "a2isupport@axiomtelecom.com" \
	# --destination "ToAddresses=$leadsMailList","CcAddresses=$devopsMailList,anuj.kaushik@axiomtelecom.com" \
	# --message "Subject={Data=A2i-Onboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>onboarding for $username is completed</b> and credentials are shared with the respective individual. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
	# --profile prod

  # # # Code to send mail to devops for testing

	# aws ses send-email \
	# --from "a2isupport@axiomtelecom.com" \
	# --destination "ToAddresses=$localEmail","CcAddresses=yogesh.patil@axiomtelecom.com" \
	# --message "Subject={Data=A2i-Onboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>onboarding for $username is completed</b> and credentials are shared with respective individual. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
	# --profile prod

}

prepareOutput(){

  echo 'I am preparing final output file'
  echo '<pre>' > tmpFinalOP.txt
  echo "<p style=font-size:15px;>Hi $firstName\, <br>Welcome to A2i Family ...!! <br>Please use below credentials to login to A2i platform</p>" >> tmpFinalOP.txt


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
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$rsUserName</b></td> </tr>" >> tmpFinalOP.txt
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
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$rsUserName</b></td> </tr>" >> tmpFinalOP.txt
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

echo 'Removing junk files'
rm -rf ./tmpUsersList.txt

echo 'Creating support files'
for user in $(echo $users | sed "s/,/ /g")
do
  echo "$user" >> tmpUsersList.txt
done

echo "Creating VPN entries"
python3 vpnHandler.py

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
			echo "I am creating user for $line"
			username=`echo $line | cut -d '@' -f1`
			organization=`echo $line | cut -d '@' -f2 | cut -d '.' -f1`
			email=`echo $line | cut -d ' ' -f1`
			vpnURL=`echo $line | cut -d ' ' -f2`
			vpnPin=`echo $line | cut -d ' ' -f3`
		  firstName=`echo $username | cut -d '.' -f1 `
			echo "username is $username , firstName is ${firstName} and organization is $organization and email is $email and vpn profile is $vpnURL and pin is $vpnPin"
			echo "Creating AWS entries"
			createAWSEntries $username $organization $email
			echo "Creating Redshift entries"
			createRedshiftEntries $username $organization $email
			echo "Creating LDAP entries"
			createLDAPEntries $username $organization $email
			echo "Sending email"
			sendMail $username $email $vpnURL $vpnPin
  	fi #if1
done < $filename

#############################
########## CleanUp ##########
#############################

echo 'Working on workspace cleanup'
# rm -rf ./tmp*
