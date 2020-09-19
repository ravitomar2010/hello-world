#!/bin/bash

profile=$env
existinguserlist=`aws iam list-users --profile $profile | grep '"UserName": "'`
password='Password@A2i'
flagone=1

sendMail(){

    echo 'Sending email to concerned individuals'
    aws ses send-email \
    --from "a2isupport@axiomtelecom.com" \
    --destination "ToAddresses=$to","CcAddresses=yogesh.patil@axiomtelecom.com,ravi.tomar@intsof.com" \
    --message "Subject={Data= $subject ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$body,Charset=utf8}}" \
    --profile $profile
}

create_and_share_keys_only () {
		username=$1
  	echo "Creating access keys for $username"
		response=`aws iam create-user --user-name $username --profile $profile`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile $profile`
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		#echo -e "\n\n Access Key is $acceskey \n\n secretkey is $secretkey"
		echo "Sending email to $username"
		to=$username
		subject="A2i stage AWS credentials"
		body="Welcome to A2i Family \n\n Please use below credentials(keys) to login to A2i stage AWS platform  \n\n $acceskey \n\n $secretkey"
		sendMail

}

create_and_share_ui_creden_only () {
		username=$1
  	echo "Creating ui credentials for $username"
		response=`aws iam create-user --user-name $username --profile $profile`
		# echo "$response"
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile $profile
		#aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile $profile
		to=$username
		subject="A2i $profile AWS credentials"
		body="Welcome to A2i Family \n\n Please use below credentials to login to A2i stage AWS platform \n\n Url: <a href>https://a2i-stage.signin.aws.amazon.com/console</a> \n\n Username: $username \n\n Password: $password"
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
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		to=$username
		subject="A2i $profile AWS credentials"
		body="Welcome to A2i Family \n\n Please use below credentials to login to A2i stage AWS platform \n\n Url: https://a2i-stage.signin.aws.amazon.com/console \n\n Username: $username \n\n Password: $password \n\n $acceskey \n\n $secretkey"
		sendMail
}

######################## Main function ######################################
			username=$emailid
			echo "working for user $username"
			groupname=$GroupName
			echo "working on adding user on group $groupname"
			credenlevel=$CredLevel
			echo "Credentials type is $credenlevel"
			##Check if user already exists
			isexists=`echo $existinguserlist | grep $username | wc -l`;
			iskeyonly=`echo $credenlevel | grep -Fx 'KEY' | wc -l`
			isuionly=`echo $credenlevel | grep -Fx 'UI' | wc -l`
			iskeyouiboth=`echo $credenlevel | grep -Fx 'UIKEY' | wc -l`

			if [[ $credenlevel == "" ]]; then
				#statements
				echo "credentials type not specified"
				isuionly=1;
			fi
			#echo "iskeyonly $iskeyonly , isuionly $isuionly, iskeyouiboth $iskeyouiboth"

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
						echo "Adding user $username to group $groupname"
						aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile $profile

			else

						echo "User $username already exists adding to group $groupname if its not a member"
					  aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile $profile

			fi

			##Reset flags
			isexists=0;
			iskeyonly=0;
			isuionly=0;
			isuikeyboth=0;
