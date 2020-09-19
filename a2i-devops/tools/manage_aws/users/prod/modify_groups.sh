#!/bin/bash

filename=modify_groups.txt

while read line; do
  if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
      groupname=`echo $line | cut -d ' ' -f1`
      echo "I am modifying group $groupname"
      userlist=`echo $line | cut -d ' ' -f2-`
    #  echo $userlist

      usermembers=`echo $userlist | cut -d ',' -f1-`
    #        echo "$usermembers"
            for word in $usermembers
            do
                #echo "$word"
                islastuser=`echo $word | grep ',' | wc -l`
                if [[ $islastuser -lt 1 ]]; then
                  #statements
                  echo "user $word is a last user"
                  username=`echo $word`
                else
                  username=`echo $word | rev | cut -c 2- | rev`
                  echo "username is $username"
                fi
                aws iam add-user-to-group --user-name="$username" --group-name="$groupname" --profile prod
            done

      #echo "List of users are $usermembers

  fi
done < $filename
