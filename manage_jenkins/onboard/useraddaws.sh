#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################


awsPassword='Password@A2i'

#######################################################################
######################### Feature Function Code #######################
#######################################################################
profile=$env
createAWSEntries(){
	local_email=$emailid
  groupname=$GroupName
	echo "Creating AWS $profile user entries having email $local_email in group $groupname "

		response=`aws iam create-user --user-name $local_email --profile $profile`
		aws iam create-login-profile --user-name="$local_email" --password="$awsPassword" --password-reset-required --profile $profile

		aws iam add-user-to-group --user-name="$local_email" --group-name="$groupname" --profile $profile


		# echo "$local_email $groupname UI" >> ../manage_aws/$profile/users_list.txt
		# echo "$local_email $groupname UI" >> ../manage_aws/stage/users_list.txt
}


sendMail(){

  aws ses send-email \
          --from "a2iteam@axiomtelecom.com" \
          --destination "ToAddresses=$emailid","CcAddresses=ravi.tomar@intsof.com" \
          --message "Subject={Data=A2i $profile AWS credentials ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi User<br><br>Welcome to A2i Family<br><br>===================================================<br><br>Please use below credentials to login to A2i $profile AWS platform<br><br>Url: <a href>https://hyke-admin.signin.aws.amazon.com/console</a><br>Username: $emailid<br>Password: $awsPassword<br><br>Regards<br>Devops Team,Charset=utf8}}" \
          --profile $profile


}

createAWSEntries
if [[ $? == 0 ]];then
  echo "sending email..."
  sendMail
fi
