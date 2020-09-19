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
	local_username=$1
	local_organization=$2
	local_email=$3
  groupname="base$local_organization"
	echo "Creating AWS user entries for $local_username for $localorganization with email $local_email in group $groupname"

		response=`aws iam create-user --user-name $local_email --profile prod`
		aws iam create-login-profile --user-name="$local_email" --password="$awsPassword" --password-reset-required --profile prod

		response=`aws iam create-user --user-name $local_email --profile stage`
		aws iam create-login-profile --user-name="$local_email" --password="$awsPassword" --password-reset-required --profile stage

		aws iam add-user-to-group --user-name="$local_email" --group-name="$groupname" --profile prod
		aws iam add-user-to-group --user-name="$local_email" --group-name="$groupname" --profile stage

		# echo "$local_email $groupname UI" >> ../manage_aws/prod/users_list.txt
		# echo "$local_email $groupname UI" >> ../manage_aws/stage/users_list.txt
}

createRedshiftEntries(){
	local_username=$1
	local_organization=$2
	local_email=$3
	firstname=`echo $local_username | cut -d '.' -f1`
	lastname=`echo $local_username | cut -d '.' -f2`
	echo "firstname is $firstname and lastname is $lastname and organization is $local_organization"
	local_username=`echo "${firstname}_${lastname}"`
	rsUsername=`echo "${firstname}_${lastname}"`

  # groupname="base$local_organization"
			echo "Creating Redshift user entries for $local_username for $localorganization with email $local_email in group $groupname"
			if [[ $local_organization == *"tothenew"* ]]; then
					groupname="read_ttn"
			elif [[ $local_organization == *"intsof"* ]]; then
					groupname="read_intsoft"
			elif [[ $local_organization == *"axiomtelecom"* ]]; then
					groupname="read_axiom"
			else
					echo "Organization $local_organization not found !!"
			fi
	echo "Group name is $groupname"
  redshift_prod $local_username $groupname
	redshift_stage $local_username $groupname
	echo "$rsUsername $groupname" >> ../manage_redshift/prod/users_list.txt
	echo "$rsUsername $groupname" >> ../manage_redshift/stage/users_list.txt
}

redshift_prod(){
	local_username=$1
	groupname=$2
	masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/rootpassword" --with-decryption --profile prod --output text --query Parameter.Value`
	hostname=axiom-prod-dwh.hyke.ai
	dbname=axiom_stage
	user=axiom_stage

		echo "Modifying SSM to include the new user "
		{
					echo "Generating random password for user $local_username"
					##Generate Passowrd for user
					p1=`echo $local_username | cut -d "_" -f1`
					#echo "$p1"
					p1+="@R"
					p2=`echo $((RANDOM)) | cut -c-4`
					#echo "$p2"
					rsPasswordProd="${p1}${p2}"
					echo "Passowrd is $rsPasswordProd"
		 }

			existinguserlistssmssm=`aws ssm get-parameter --name "/a2i/infra/redshift_prod/users" --with-decryption --profile prod --output text --query Parameter.Value`

			newuserlist="${existinguserlistssmssm}"
			newuserlist+="\n"
			newuserlist+="$local_username $rsPasswordProd"

			newuserlist=`echo -e "$newuserlist"`
			#echo "New users list is $newuserlist"
			##Updating parameter in SSM
			aws ssm put-parameter --name "/a2i/infra/redshift_prod/users" --value "$newuserlist" --overwrite --type SecureString --profile prod

			## Creating user in redshift
			sql="create user $local_username with password '"$rsPasswordProd"' in group $groupname"
			echo "sql is $sql"
			psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
}

redshift_stage(){
	local_username=$1
	groupname=$2
	masterpassword=`aws ssm get-parameter --name "/a2i/infra/redshift_stage/rootpassword" --with-decryption --profile stage --output text --query Parameter.Value`
	hostname=axiom-rnd-dwh.hyke.ai
	dbname=axiom_rnd
	user=axiom_rnd

		echo "Modifying SSM to include the new user "
		{
					echo "Generating random password for user $local_username"
					##Generate Passowrd for user
					p1=`echo $local_username | cut -d "_" -f1`
					#echo "$p1"
					p1+="@R"
					p2=`echo $((RANDOM)) | cut -c-4`
					#echo "$p2"
					rsPasswordStage="${p1}${p2}"
					echo "Passowrd is $rsPasswordStage"
		 }

			existinguserlistssmssm=`aws ssm get-parameter --name "/a2i/infra/redshift_stage/users" --with-decryption --profile stage --output text --query Parameter.Value`

			newuserlist="${existinguserlistssmssm}"
			newuserlist+="\n"
			newuserlist+="$local_username $rsPasswordStage"

			newuserlist=`echo -e "$newuserlist"`
			#echo "New users list is $newuserlist"
			##Updating parameter in SSM
			aws ssm put-parameter --name "/a2i/infra/redshift_stage/users" --value "$newuserlist" --overwrite --type SecureString --profile stage

			## Creating user in redshift
			sql="create user $local_username with password '"$rsPasswordStage"' in group $groupname"
			echo "sql is $sql"
			psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
}

createLDAPEntries() {
	local_username=$1
	local_organization=$2
	local_email=$3

	basedn='dc=a2i,dc=infra'
	masterpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/rootpwd" --with-decryption --profile stage --output text --query Parameter.Value`
	masterusername="cn=admin,$basedn"
	bindpassword=`aws ssm get-parameter --name "/a2i/infra/ldap/bindpwd" --with-decryption --profile stage --output text --query Parameter.Value`
	binduser="uid=ldap,$basedn"
	ldapuri="ldap://ldap.hyke.ae:389"
	LDAP_USER_GROUP="cn=ldap-basic,ou=groups,${basedn}"

	existinguserlist=`ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" cn | grep -e '^cn:' | cut -d':' -f2`
	#echo "$existinguserlist"
	HIGHEST_UID=$(ldapsearch -x -w "$bindpassword" -b "$basedn" -D "$binduser" -H $ldapuri -LLL "(objectclass=posixaccount)" uidnumber | grep -e '^uid' | cut -d':' -f2 | sort | tail -1)
	let USER_ID=HIGHEST_UID+1
  #echo "Highest UID is $HIGHEST_UID"

	USER_PASS=`perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..9'`
	#ldapPassword=`"echo $USER_PASS"`
	ldapPassword=`echo "${USER_PASS}"`

	GROUP_ID=519;
			local_givenName=`echo $local_username | cut -d '.' -f1`
			USER_CN=`echo $local_username`
			USER_SN=`echo $local_username | cut -d '.' -f2`
			echo "USER_CN is $USER_CN and USER_SN is $USER_SN";

LDIF=$(cat<<EOF
dn: cn=${local_username},ou=users,${basedn}
changetype: add
uid: ${local_username}
cn: ${USER_CN}
sn: ${USER_SN}
givenName: ${local_givenName}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
userPassword: ${USER_PASS}
loginShell: /bin/bash
uidNumber: ${USER_ID}
gidNumber: ${GROUP_ID}
homeDirectory: /home/users/${local_username}

dn: ${LDAP_USER_GROUP}
changetype: modify
add: memberuid
memberuid: ${local_username}

EOF
)
			echo "Adding LDAP entries for $local_username with password "
			echo "$LDIF" | ldapmodify -x -c -D "$masterusername" -w $masterpassword  -H $ldapuri

			echo "$rsUsername $groupname" >> ../manage_ldap/users_list.txt
			#echo "$rsUsername $groupname UI" >> ../manage_ldap/stage/users_list.txt

}

sendMail(){
	local_username=$1
	local_email=$2
	local_vpnURL=$3
	local_vpnPin=$4
	getSSMParameters
  prepareOutput

	# # Code to send mail using local smtp
	# (echo "To: $local_email" && echo "Subject: A2i platform credentials" && echo -e "\n Welcome to A2i Family \n\n Please use below credentials to login to A2i platform" &&
	# echo -e "\n - Production Credentials \n\n A. AWS \n URL: https://hyke-admin.signin.aws.amazon.com/console \n Username: $local_email \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUsername \n Passowrd: $rsPasswordProd \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$local_username \n Passowrd: $ldapPassword" &&
	# echo -e "\n - Stage Credentials \n\n A. AWS \n URL: https://a2i-stage.signin.aws.amazon.com/console \n Username: $local_email \n Passowrd: $awsPassword \n\n B. Redshift \n Username: $rsUsername \n Passowrd: $rsPasswordStage \n\n C. LDAP(can be used to login to tools like nifi, jenkins etc.) \n Username:$local_username \n Passowrd: $ldapPassword " &&
	# echo -e "\n - VPN \n\n Profile URL: $local_vpnURL \n Pin: $local_vpnPin " &&
	# #echo -e "\n Please use following credentials to login to A2i tools(Jenkins, Grafana etc.) \n URL: http://grafana.hyke.ae:3000/ \n Username:$local_username \n Passowrd: $ldapPassword" &&
	# echo -e "\n Please reach out to devops team in case of any issues \n\n") | msmtp $local_email

  # # # Code to send mail to local user
	aws ses send-email \
	--from "a2isupport@axiomtelecom.com" \
	--destination "ToAddresses=$local_email","CcAddresses=yogesh.patil@axiomtelecom.com" \
	--message "Subject={Data=A2i credentials | $username ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
	--profile prod

  # # # Code to send mail to leads
	aws ses send-email \
	--from "a2isupport@axiomtelecom.com" \
	--destination "ToAddresses=$leadsMailList","CcAddresses=$devopsMailList,anuj.kaushik@axiomtelecom.com" \
	--message "Subject={Data=A2i-Onboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>onboarding for $username is completed</b> and credentials are shared with the respective individual. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
	--profile prod

  # # # Code to send mail to devops for testing

	# aws ses send-email \
	# --from "a2isupport@axiomtelecom.com" \
	# --destination "ToAddresses=yogesh.patil@axiomtelecom.com","CcAddresses=yogesh.patil@axiomtelecom.com" \
	# --message "Subject={Data=A2i-Onboarding | $username | Success ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=<p style=font-size:15px;>Hi All\,<br><br>This is to notify you all that <b>onboarding for $username is completed</b> and credentials are shared with respective individual. <br>Please reach out to DevOps in case of any concern.<br><br>Thanks and Regards\,<br>DevOps Team</p>,Charset=utf8}}" \
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
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$local_email</b></td> </tr>" >> tmpFinalOP.txt
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
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$local_username</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Password</b></td> <td><b>$ldapPassword</b></td> </tr>" >> tmpFinalOP.txt


	echo "<tr><td colspan=3><b style=font-size:15px;color:#339CFF;>Stage Credentials:</b></td></tr>" >> tmpFinalOP.txt

	### AWS
	echo "<tr><td width=15px;><b>A</b></td> <td colspan=3><b>AWS</b></td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>URL</b></td> <td><b></b>https://a2i-stage.signin.aws.amazon.com/console</td> </tr>" >> tmpFinalOP.txt
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$local_email</b></td> </tr>" >> tmpFinalOP.txt
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
	echo "<tr><td width=15px;><b></b></td> <td><b>Username</b></td> <td><b>$local_username</b></td> </tr>" >> tmpFinalOP.txt
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

echo "Creating VPN entries"

python3 vpnHandler.py

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
			#echo "I am creating user for $line"
			username=`echo $line | cut -d '@' -f1`
			organization=`echo $line | cut -d '@' -f2 | cut -d '.' -f1`
			email=`echo $line | cut -d ' ' -f1`
			vpnURL=`echo $line | cut -d ' ' -f2`
			vpnPin=`echo $line | cut -d ' ' -f3`
		  firstname=`echo $username | cut -d '.' -f1 `
			# echo "username is $username , firstname is ${firstname} and organization is $organization and email is $email and vpn profile is $vpnURL and pin is $vpnPin"
			# echo "Creating AWS entries"
			# createAWSEntries $username $organization $email
			echo "Creating Redshift entries"
			createRedshiftEntries $username $organization $email
			# echo "Creating LDAP entries"
			# createLDAPEntries $username $organization $email
			# echo "Sending email"
			# sendMail $username $email $vpnURL $vpnPin
  	fi #if1
done < $filename

#############################
########## CleanUp ##########
#############################

echo 'Working on workspace cleanup'
rm -rf ./tmp*
