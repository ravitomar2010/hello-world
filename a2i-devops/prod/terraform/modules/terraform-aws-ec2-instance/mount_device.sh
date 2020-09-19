#!/bin/bash
sudo mkdir -p /data
sudo chmod 777 /data
sudo mkfs -t ext4 /dev/xvdb
sudo mount /dev/xvdb /data/
sudo su -c 'echo "/dev/xvdb /data ext4 defaults 0 2"  >> /etc/fstab'
sudo su -c 'mount -a'
