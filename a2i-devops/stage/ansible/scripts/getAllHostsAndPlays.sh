#!/bin/bash

windowsHostIps=`aws ec2 describe-instances --profile stage --query Reservations[*].Instances[*].[PrivateIpAddress][][] --filters "Name=platform,Values=windows"`
#windowsHostIps=`aws ec2 describe-instances --profile stage --query Reservations[*].Instances[*].[PrivateIpAddress][][]`
AllHostDetails=`aws ec2 describe-instances --profile stage --query Reservations[*].Instances[*].[PrivateIpAddress,KeyName][][]`

windowsHostIps=`echo "${windowsHostIps//[}"`
windowsHostIps=`echo "${windowsHostIps//]}"`
echo "windowsHostIps are $windowsHostIps"

noOfWindowsIPs=`echo "$windowsHostIps" | wc -l`

AllHostDetails=`echo "${AllHostDetails//[}"`
AllHostDetails=`echo "${AllHostDetails//]}"`
echo "No of windows ips are $noOfWindowsIPs"
echo "All hosts are $AllHostDetails"
# if [[ condition ]]; then
#   #statements
# fi

while read -r line
do
  if [[ $line == '' ]]; then
    #statements
    echo 'This is blank line '
  else
    echo "A line of input: $line"
  fi

done <<<"$AllHostDetails"
