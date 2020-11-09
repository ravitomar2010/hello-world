filename=groups_list.txt

#Get the list of existing schemas
existinggrouplist=`aws iam list-groups --profile stage | grep '"GroupName": "'`

while read line; do
	if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
			group_name=$line
			isgroupexists=`echo $existinggrouplist | grep $group_name| wc -l`

					if [[ $isgroupexists -gt 0 ]]; then
						#statements
						 echo "Group $group_name already exists"

					else
							echo "I am creating group $line"
						 # group_name=$line
						  aws iam create-group --group-name $group_name --profile prod
							aws iam attach-group-policy --group-name $group_name --policy-arn arn:aws:iam::aws:policy/IAMUserChangePassword --profile prod
					fi
	fi
done < $filename
