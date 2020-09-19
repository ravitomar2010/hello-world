#!/bin/bash

filename=users_list.txt
existinguserlist=`aws iam list-users --profile prod | grep '"UserName": "'`
password='Password@A2i'
flagone=1

create_and_share_keys_only () {
		username=$1
  	echo "Creating access keys for $username"
		response=`aws iam create-user --user-name $username --profile prod`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile prod`
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":' | tr -d '"'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":' | tr -d '"'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		echo -e "\n\n Access Key is $acceskey \n\n secretkey is $secretkey"
		echo "Sending email to $username"
		aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
				--destination "ToAddresses=$username","CcAddresses=yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=A2i production AWS credentials ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi User<br><br>Welcome to A2i Family<br><br>===================================================<br><br>Please use below credentials(keys) to login to A2i production AWS platform<br><br>$acceskey<br><br>$secretkey<br><br>Regards<br>Devops Team,Charset=utf8}}" \
        --profile prod
}

create_and_share_ui_creden_only () {
		username=$1
  	echo "Creating ui credentials for $username"
		response=`aws iam create-user --user-name $username --profile prod`
		# echo "$response"
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile prod
		#aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile prod
		aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
				--destination "ToAddresses=$username","CcAddresses=yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=A2i production AWS credentials ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi User<br><br>Welcome to A2i Family<br><br>===================================================<br><br>Please use below credentials to login to A2i production AWS platform<br><br>Url: <a href>https://hyke-admin.signin.aws.amazon.com/console</a><br><br>Username: $username<br><br>Password: $password<br><br>Regards<br>Devops Team,Charset=utf8}}" \
        --profile prod
}

create_and_share_keys_and_ui_both () {
		username=$1
  	echo "Creating access keys and credentials for $username"
		response=`aws iam create-user --user-name $username --profile prod`
		# echo "$response"
		output=`aws iam create-access-key --user-name $username --profile prod`
		aws iam create-login-profile --user-name="$username" --password="$password" --password-reset-required --profile prod
		#echo -e "output is $output"
		acceskey=`echo "$output" | grep '"AccessKeyId":'`
		acceskey=`echo "$acceskey" | rev | cut -c 2- | rev`
		secretkey=`echo "$output" | grep '"SecretAccessKey":'`
		secretkey=`echo "$secretkey" | rev | cut -c 2- | rev`
		echo "Sending email to $username"
		aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=$username","CcAddresses=yogesh.patil@axiomtelecom.com" \
        --message "Subject={Data=A2i production AWS credentials ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi User<br><br>Welcome to A2i Family<br><br>===================================================<br><br>Please use below credentials(keys) to login to A2i production AWS platform<br><br>Url: <a href>https://hyke-admin.signin.aws.amazon.com/console</a><br><br>Username: $username<br><br>Password: $password<br><br>access key: $acceskey<br><br>Secret Key: $secretkey<br><br>Regards<br>Devops Team,Charset=utf8}}" \
        --profile prod
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
						aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile prod

			else

						echo "User $username already exists adding to group $groupname if its not a member"
					  aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile prod

			fi

			##Reset flags
			isexists=0;
			iskeyonly=0;
			isuionly=0;
			isuikeyboth=0;

	fi #if1
done < $filename
