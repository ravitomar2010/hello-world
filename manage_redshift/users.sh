#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpUsersList.txt
user=$1
if [[ $2 != '' ]]; then
    env=$2
    dbClient='axiom'
else
    echo 'Working with default env - No argument provided'
fi

##############################Test Parameter ##########################
# dbClient='axiom'
# env='prod'

#######################################################################
############################# Generic Code ############################
#######################################################################

getProfile(){
  # curr_dir=`pwd`
  # profile=`echo "$curr_dir" | rev | cut -d '/' -f1 | rev`
  echo "dbClient is $dbClient"
  profile="${env}"
  echo "profile is $profile"
  if [[ $profile == 'stage' ]]; then
    redshfitClusterID='axiom-rnd'
  else
    redshfitClusterID='axiom-stage'
  fi
}

getConnectionDetails(){
  echo 'Fetching required parameters from SSM'
  hostName=`aws ssm get-parameter --name "/a2i/$profile/redshift/host" --with-decryption --profile $profile --output text --query Parameter.Value`
  portNo=`aws ssm get-parameter --name "/a2i/$profile/redshift/port" --with-decryption --profile $profile --output text --query Parameter.Value`
  dbName=`aws ssm get-parameter --name "/a2i/$profile/redshift/db/$dbClient" --with-decryption --profile $profile --output text --query Parameter.Value`
  redshiftPassword=`aws ssm get-parameter --name "/a2i/infra/redshift_$profile/rootpassword" --with-decryption --profile $profile --output text --query Parameter.Value`
  accountID=`aws ssm get-parameter --name "/a2i/$profile/accountid" --with-decryption --profile $profile --output text --query Parameter.Value`
  if [[ $profile == "stage" ]]; then
    redshiftuserName="axiom_rnd"
  else
    redshiftuserName="axiom_stage"
  fi
  echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftuserName,$accountID"
}

executeQueryAndGetResults(){
    sqlQuery=$1
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery"`
}

executeQueryAndWriteResultsToFile(){
    sqlQuery=$1
    outputFile=$2
    echo "Query is $sqlQuery"
    results=`psql -tAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sqlQuery" > "$outputFile"`
}

executeQueryFile(){
    sqlQueryFile=$1
    echo "Executing queries from file $sqlQueryFile"
    results=`psql -atAX "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -f  "$sqlQueryFile"`
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

fetchUserListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/users" --with-decryption --profile $profile --output text --query Parameter.Value > tmpUsersList.txt

}

fetchGroupListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/groups" --with-decryption --profile $profile --output text --query Parameter.Value > tmpGroupsList.txt

}

getUserParameters(){

		if [[ $user == '' ]]; then
				echo 'No userName provided as argument - will not try getting user parameters'
    elif [[ $user == *"batch"* ]]; then
        userName=`echo "$user" | cut -d '@' -f1`
        echo "userName is $userName"
        groupName=`echo "$user" | cut -d '@' -f2`
        echo "groupName is $groupName"
		else
				userName=`echo "$user" | cut -d '@' -f1`
        firstName=`echo $userName | cut -d '.' -f1`
        lastName=`echo $userName | cut -d '.' -f2`
        userName="${firstName}_${lastName}"
				echo "userName is $userName"
				organization=`echo "$user" | cut -d '@' -f2 | cut -d '.' -f1`
				echo "organization is $organization"
  	fi

}

checkUserParameters(){

		echo 'Checking if user already exists in ssm user list'
    if [[ $user == '' ]]; then
          echo 'No userName provided as argument - Will not update SSM'
    elif [[ $user == *"batch"* ]]; then
        echo 'User is batch user'
        if grep -inx "$userName $groupName" tmpUsersList.txt ; then
            echo "User $userName already exists in SSM user list"
        else
            echo "User $userName does not exists in SSM user list - adding the same"
            echo "$userName $groupName" >> tmpUsersList.txt
            echo 'sorting user file '
            sort -o tmpUsersList.txt tmpUsersList.txt
            aws ssm put-parameter --name "/a2i/$profile/redshift/users" --value "$(cat tmpUsersList.txt)" --type String --overwrite --profile $profile
        fi
    else
        echo 'User is not batch user'

        if grep -inx "$userName read_${organization}" tmpUsersList.txt ; then
            echo "User $userName already exists in SSM user list"
        else
            echo "User $userName does not exists in SSM user list - adding the same"
            echo "$userName read_${organization}" >> tmpUsersList.txt
            echo 'sorting user file '
            sort -o tmpUsersList.txt tmpUsersList.txt
            aws ssm put-parameter --name "/a2i/$profile/redshift/users" --value "$(cat tmpUsersList.txt)" --type String --overwrite --profile $profile
        fi
    fi

}

createUsers(){
		##Get all the existing user list
		usersql="select usename from pg_user;"
		userListDB=`psql "host=$hostName port=5439 dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$usersql"`
		echo "$userListDB"

	while read line; do
		if [[ $line == "" ]]; then #if1
		    echo "Skipping empty line"
	  else

				echo "I am creating user for $line"
				userName=`echo $line | cut -d ' ' -f1`
			  # echo "userName is $userName"
				defaultGroup=`echo $line | cut -d ' ' -f2`
			  # echo "defaultGroup is $defaultGroup"

				# userexistflagssm=`echo $existinguserlistssm | grep -e $userName | wc -l`
				isuserexistsindb=`echo $userListDB | grep -e $userName | wc -l`

				if [[ $isuserexistsindb -gt 0 ]]; then #if 2
								echo "User $userName already exists in db"
				else #else 2

            # echo 'Checking if user is batch user'
						isbatchuser=`echo $userName | grep -e batch | wc -l`

						if [[ $isbatchuser -gt 0  ]]; then #if3
									echo "User is a batch user "
                  checkAndCreateBatchGroup
									isbatchuserexistsssm=`aws ssm get-parameter --name "/a2i/$profile/redshift/users/$userName" --with-decryption --profile $profile --output text --query Parameter.Value | wc -l`
									if [[ $isbatchuserexistsssm -gt 0 ]]; then #if4
												echo "SSM entry for $userName already exists"
												password=`aws ssm get-parameter --name "/a2i/$profile/redshift/users/$userName" --with-decryption --profile $profile --output text --query Parameter.Value`
												# echo "Password for batch user is $password"
												## Creating user in redshift
												sqlQuery="create user $userName with password '"$password"' in group $defaultGroup"
												# echo "sql is $sqlQuery"
												# psql "host=$hostName port=$portNo dbname=$dbName user=$redshiftuserName password=$redshiftPassword" -F  --no-align -c  "$sql"
												executeQueryAndGetResults "${sqlQuery}"

									else #else 4
                        echo "SSM entry for $userName does not exists - Creating entry in SSM "
															{
																		echo "Generating random password for user $userName"
																		##Generate Passowrd for user
																		p1=`echo $userName | cut -d "_" -f1`
																		#echo "$p1"
																		p1+="@R"
																		p2=`date +%M%S`
																		#echo "$p2"
																		password="${p1}${p2}"
																		echo "Passowrd is $password"
															 }

												  aws ssm put-parameter --name "/a2i/$profile/redshift/users/$userName" --value "$password" --type SecureString --profile $profile
													## Creating user in redshift
													sqlQuery="create user $userName with password '"$password"' in group $defaultGroup"
													# echo "sql is $sqlQuery"
													executeQueryAndGetResults "${sqlQuery}"
									fi #if4

						else #else 3
									echo 'User is not a batch user - Creating new user'
									{
												echo "Generating random password for user $userName"
												##Generate Passowrd for user
												p1=`echo $userName | cut -d "_" -f1`
												#echo "$p1"
												p1+="@R"
												p2=`date +%M%S`
												#echo "$p2"
												password="${p1}${p2}"
												echo "Passowrd is $password"
									 }
									sqlQuery="create user $userName with password '"$password"' in group $defaultGroup"
									# echo "sql is $sqlQuery"
									executeQueryAndGetResults "${sqlQuery}"
                  createTempSSMEntryForUser
						fi #if 3
				fi  #if 2
		fi # if 1
	done < $filename
}

createTempSSMEntryForUser(){

    echo "Setting SSM parameter to be referenced by onboard script for $userName"

    aws ssm put-parameter \
          --name /tmp/${profile}/redshift/${userName} \
          --description "This is tempporary redshift password entry for ${userName}" \
          --value "${password}" \
          --type SecureString \
          --overwrite \
          --profile $profile

}

checkAndCreateBatchGroup(){

    fetchGroupListFromSSM
    groupEntryFlag=`cat tmpGroupsList.txt  | grep "$defaultGroup" | wc -l`

    if [[ $groupEntryFlag -eq 0 ]]; then
        echo "Group entry doesn't exists - creating the same"
        ./groups.sh "$defaultGroup"
    fi
}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
getConnectionDetails
fetchUserListFromSSM
getUserParameters
checkUserParameters
createUsers

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
