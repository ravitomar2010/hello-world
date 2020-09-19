#!/bin/bash

echo "Started"

listOfInstance=$(aws ec2 describe-tags --filters Name=resource-type,Values=instance Name=key,Values=Name --query Tags[].Value --profile prod)

echo "List is "

for each in "${listOfInstance}"
do
  echo "List element is  "
  echo "$each"
done
