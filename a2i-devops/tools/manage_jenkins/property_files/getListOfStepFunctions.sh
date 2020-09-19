#!/bin/bash

echo "Populating list of step functions for prod account"

listOfSFProd=$(aws stepfunctions list-state-machines --query stateMachines[*].name --profile prod)
listOfSFStage=$(aws stepfunctions list-state-machines --query stateMachines[*].name --profile stage)

prodFile=./sf-list.txt

cat '' > ./sf-list.txt

for each in "${listOfSFProd}"
do
  echo "List element is  "
  echo "$each"
done
