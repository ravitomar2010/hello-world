#!/bin/bash

filename=users_list.txt
existinguserlist=`aws iam list-users --profile stage | grep '"UserName": "'`
password='Password@A2i'
flagone=1

create_and_share_keys_only () {
		username=$1
  	echo "Creating access keys for $username"
		response=`aws iam create-user --user-name $username --profile stage`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile stage`
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		#echo -e "\n\n Access Key is $acceskey \n\n secretkey is $secretkey"
		echo "Sending email to $username"
		(echo "To: $username" && echo "Subject: A2i stage AWS credentials" && echo -e "Welcome to A2i Family \n\n Please use below credentials(keys) to login to A2i stage AWS platform  \n\n $acceskey \n\n $secretkey") | msmtp $username
}

create_and_share_ui_creden_only () {
		username=$1
  	echo "Creating ui credentials for $username"
		response=`aws iam create-user --user-name $username --profile stage`
		# echo "$response"
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile stage
		#aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile stage
		(echo "To: $username" && echo "Subject: A2i stage AWS credentials" && echo -e "Welcome to A2i Family \n\n Please use below credentials to login to A2i stage AWS platform \n\n Url: https://a2i-stage.signin.aws.amazon.com/console \n\n Username: $username \n\n Password: $password") | msmtp $username
}

create_and_share_keys_and_ui_both () {
		username=$1
  	echo "Creating access keys and credentials for $username"
		response=`aws iam create-user --user-name $username --profile stage`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile stage`
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile stage
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		(echo "To: $username" && echo "Subject: A2i stage AWS credentials" && echo -e "Welcome to A2i Family \n\n Please use below credentials to login to A2i stage AWS platform \n\n Url: https://a2i-stage.signin.aws.amazon.com/console \n\n Username: $username \n\n Password: $password \n\n $acceskey \n\n $secretkey") | msmtp $username
}

while read line; do
	if [[ $line == "" ]]; then #if1
	    echo "Skipping empty line"
  else
			username=`echo $line | cut -d ' ' -f1`
			echo "working on user $username"
			groupname=`echo $line | cut -d ' ' -f2`
			echo "working on group $groupname"
			credenlevel=`echo $line | cut -d ' ' -f3`
			echo "Credentials type is $credenlevel"
			##Check if user already exists
			isexists=`echo $existinguserlist | grep $username | wc -l`;
			iskeyonly=`echo $credenlevel | grep -Fx 'KEY' | wc -l`
			isuionly=`echo $credenlevel | grep -Fx 'UI' | wc -l`
			iskeyouiboth=`echo $credenlevel | grep -Fx 'UIKEY' | wc -l`

			if [[ $credenlevel == "" ]]; then
				#statements
				echo "$line is blank credentials"
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
						aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile stage

			else

						echo "User $username already exists adding to group $groupname if its not a member"
					  aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile stage

			fi

			##Reset flags
			isexists=0;
			iskeyonly=0;
			isuionly=0;
			isuikeyboth=0;

	fi #if1
done < $filename
