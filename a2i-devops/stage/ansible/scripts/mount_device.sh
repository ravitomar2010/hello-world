#!/bin/bash

## Need to correct as per the t3 and t2 instancetypes
##In case of t2 mount disk is the last one in case of t3 it is first one
isMounted=`mount | grep '/data' | wc -l`
value=0

instanceType=`curl http://169.254.169.254/latest/meta-data/instance-type`

instanceType=`echo $instanceType | cut -d '.' -f1`
echo "instance type is $instanceType"

deviceToMount=`lsblk | tail -n 1 | cut -d ' ' -f1`
echo "deviceToMount is $deviceToMount"

if [[ $isMounted -eq $value ]]; then
    echo 'Inside If'

    sudo mkdir -p /data
    sudo chmod 777 /data
    sudo mkfs -t ext4 /dev/${deviceToMount}
    sudo mount /dev/${deviceToMount} /data/
    sudo su -c "echo \"/dev/${deviceToMount} /data ext4 discard,defaults,nofail 0 2\"  >> /etc/fstab"
    sudo su -c 'mount -a'

      # if [[ $instanceType == "t3" ]]; then
    	# echo "Dealing with t3 instances"
    	#  #sudo mkfs -t ext4 /dev/xvdb
     	#  #sudo mount /dev/xvdb /data/
      #   	 #sudo su -c "echo \"/dev/${deviceToMount} /data ext4 defaults 0 2\"  >> /etc/fstab"
      #        #sudo su -c 'mount -a'
      #   else
      #     echo "Dealing with t2 instances"
      #        #sudo mkfs -t ext4 /dev/xvdb
      #         #sudo mount /dev/xvdb /data/
      #        #sudo su -c 'echo "/dev/xvdb /data ext4 defaults 0 2"  >> /etc/fstab'
      #       #sudo su -c 'mount -a'
      #   fi

else
    echo "Device already mounted"
fi
