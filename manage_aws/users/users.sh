#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

if [[ $1 != '' ]]; then
    env=$1
    credLevel=$2
    emailID=$3
    groupName=$4
    mailFlag='false'
    echo "Received parameters for creating AWS entries in $env environment"
    echo "emailID is ${emailID}, credLevel is ${credLevel} and groupName is ${groupName}"
fi

profile=$env
existinguserlist=`aws iam list-users --profile $profile | grep '"UserName": "'`
password='Password@A2i'
flagone=1
to=$emailID

#######################################################################
############################# Generic Code ############################
#######################################################################

getSSMParameters(){
  echo "Pulling parameters from SSM for $profile environment"
  fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/${profile}/ses/toAllList --profile ${profile} --with-decryption --query Parameter.Value --output text`
  ccMailList=`aws ssm get-parameter --name /a2i/${profile}/ses/devopsMailList --profile ${profile} --with-decryption --query Parameter.Value --output text`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

sendMail(){
    if [[ ${mailFlag} == 'false' ]]; then
        echo 'I found mail flag as false - will not send any mail'
    else
        getSSMParameters
        echo 'Sending email to concerned individuals'
        echo "from email:${fromEmail} to:${to} cc:${ccMailList} "
        aws ses send-email \
        --from "$fromEmail" \
        --destination "ToAddresses=$to","CcAddresses=$ccMailList" \
        --message "Subject={Data=$subject,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$body <br><br>Regards<br>Devops Team,Charset=utf8}}" \
        --profile $profile
    fi

}

create_and_share_keys_only () {
		username=$1
  	echo "Creating access keys for $username"
		response=`aws iam create-user --user-name $username --profile $profile`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile $profile`
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev | sed 's/"//g'`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev | sed 's/"//g'`
		#echo -e "<br><br> Access Key is $acceskey <br><br> secretkey is $secretkey"
		echo "Sending email to $username"
		to=$username
		subject="A2i $profile AWS credentials"
		body="Welcome to A2i Family <br><br> Please use below credentials(keys) to login to A2i $profile AWS platform <br><br> $acceskey
    <br><br> $secretkey"
		sendMail

}

create_and_share_ui_creden_only () {
		username=$1
  	echo "Creating ui credentials for $username"
		response=`aws iam create-user --user-name $username --profile $profile`
		# echo "$response"
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile $profile
		#aws iam add-user-to-group --user-name="$username" --group-name="$groupName" --profile $profile
		subject="A2i $profile AWS credentials"
		body="Welcome to A2i Family <br><br> Please use below credentials to login to A2i $profile AWS platform <br><br> Url: <a href>https://a2i-stage.signin.aws.amazon.com/console</a> <br><br> Username: $username <br><br> Password: $password"
		sendMail

}

create_and_share_keys_and_ui_both () {
		username=$1
  	echo "Creating access keys and credentials for $username"
		response=`aws iam create-user --user-name $username --profile $profile`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile $profile`
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile $profile
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev | sed 's/"//g'`
    echo $acceskey
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev | sed 's/"//g'`
    echo $secretkey

		to=$username
		subject="A2i $profile AWS credentials"
		body="Welcome to A2i Family <br><br> Please use below credentials to login to A2i $profile AWS platform <br><br> Url: https://a2i-stage.signin.aws.amazon.com/console <br><br> Username: $username <br><br> Password: $password <br><br> $acceskey
    <br><br> $secretkey"
		sendMail
}

#######################################################################
############################# Main Function ###########################
#######################################################################

username=$emailID
echo "working for user $username"
groupName=$groupName
echo "working on adding user on group $groupName"
echo "Credentials type is $credLevel"

isexists=`echo $existinguserlist | grep $username | wc -l`;
iskeyonly=`echo $credLevel | grep -Fx 'KEY' | wc -l`
isuionly=`echo $credLevel | grep -Fx 'UI' | wc -l`
iskeyouiboth=`echo $credLevel | grep -Fx 'UIKEY' | wc -l`

if [[ $credLevel == ' ' ]]; then
	echo "credentials type not specified"
	isuionly=1;
fi
echo "iskeyonly $iskeyonly , isuionly $isuionly, iskeyouiboth $iskeyouiboth"

if [[ $isexists -lt 1 ]]; then

			echo "User $username doesnt exists and need to create one"
			if [[ $isuionly -eq $flagone ]]; then
						##echo "$username needs UI only credentials"
						create_and_share_ui_creden_only $username
			elif [[ $iskeyonly -eq $flagone ]]; then
						#echo "$username needs Key only credentials"
						create_and_share_keys_only $username
			else
						##echo "$username needs both type of credentials"
						create_and_share_keys_and_ui_both $username
			fi
			echo "Adding user $username to group $groupName"
			aws iam add-user-to-group --user-name="$username" --group-name="$groupName" --profile $profile
else

			echo "User $username already exists adding to group $groupName if its not a member"
		  aws iam add-user-to-group --user-name="$username" --group-name="$groupName" --profile $profile
fi
