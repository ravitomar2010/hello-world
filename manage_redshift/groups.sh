#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################

filename=tmpGroupsList.txt
# dbClient='axiom'
existingGroupList='';
groupName=$1

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
  #echo "$hostName,$portNo,$dbName,$redshiftPassword,$redshiftuserName,$accountID"
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

fetchGroupListFromSSM(){

      aws ssm get-parameter --name "/a2i/$profile/redshift/groups" --with-decryption --profile $profile --output text --query Parameter.Value > tmpGroupsList.txt

}

setGroupListInSSM(){

	echo 'Checking if group already exists in ssm group list'
	if [[ $groupName == '' ]]; then
			echo 'No groupName is provided as argument - Will not update SSM'
	elif grep -inx "$groupName" tmpGroupsList.txt ; then
			echo "Group $groupName already exists in SSM group list"
	else
			echo "Group $groupName does not exists in SSM group list - adding the same"
			echo "$groupName" >> tmpGroupsList.txt
			echo 'sorting group file '
			sort -o tmpGroupsList.txt tmpGroupsList.txt
			aws ssm put-parameter --name "/a2i/$profile/redshift/groups" --value "$(cat tmpGroupsList.txt)" --type String --overwrite --profile $profile
	fi
}

createGroups(){

	#Get the list of existing groups
	sqlQuery="select groname from pg_group;"
	executeQueryAndGetResults "${sqlQuery}"
	# existingGroupList=`psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"`
	existingGroupList="$results"

	while read line; do
		if [[ $line == "" ]]; then
	    echo "Skipping empty line"
	  else
				groupName=$line
				isGroupExists=`echo $existingGroupList | grep $groupName| wc -l`

						if [[ $isGroupExists -gt 0 ]]; then
							 echo "Group $groupName already exists in DB"
						else
								echo "I am creating group $line"
							  sqlQuery="create group $groupName"
							  echo "sql is $sqlQuery"
								executeQueryAndGetResults "$sqlQuery"
								# psql "host=$hostname port=5439 dbname=$dbname user=$user password=$masterpassword" -F  --no-align -c  "$sql"
						fi
		fi
	done < $filename

}

#######################################################################
############################# Main Function ###########################
#######################################################################

getProfile
getConnectionDetails
fetchGroupListFromSSM
setGroupListInSSM
createGroups

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
# sudo rm -rf ./tmp*
