#!/bin/bash

dilist=`cat /root/scripts/logsmanagement/dir_list.txt`
# # time=`date +%d%m%y%H`
# # echo "$time"
# #
# #touch /root/scripts/$time.txt
if [[ $dilist =~ ',' ]]; then
    #statements
    #echo "String has comma"
    echo $dilist | tr "," "\n" | while read -r dir;
    do
        echo "Working on dir $dir"
        #dir=$dilist
        #cd $dir
        diskSize=`df -k . | awk '{print $5}' | head -2 | tail -1 | cut -d '%' -f1`
        if [[ $diskSize -gt 60 ]]; then
          #statements
          echo " Disk utilization is $diskSize%"
          sudo find $dir -type f -mtime +1 -delete
        fi
    done;
else
    echo "String dont have any comma"
    dir=$dilist
    #cd $dir
    diskSize=`df -k . | awk '{print $5}' | head -2 | tail -1 | cut -d '%' -f1`
    if [[ $diskSize -gt 60 ]]; then
      #statements
      echo " Disk utilization is $diskSize%"
      sudo find $dir -type f -mtime +1 -delete
    fi
fi
