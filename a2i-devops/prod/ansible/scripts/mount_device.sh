#!/bin/bash

isMounted='mount | grep data | wc -l'
value=0

if [ $isMounted -gt $value ]
then
    sudo mkdir -p /data
    sudo chmod 777 /data
    sudo mkfs -t ext4 /dev/xvdb
    sudo mount /dev/xvdb /data/
    sudo su -c 'echo "/dev/xvdb /data ext4 defaults 0 2"  >> /etc/fstab'
    sudo su -c 'mount -a'
else
    echo "Device already mounted"
fi
