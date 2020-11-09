#!/bin/bash
filename="host_list.txt"

while read line; do
	if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
    echo "line is $line"
    host=`echo $line | cut -d ' ' -f1`
    key=`echo $line | cut -d ' ' -f2`
    node=`echo $host | cut -d '.' -f1`
    echo "Host is $host, key is $key and node is $node"
		# echo "$dir" > tmp_dir_list.txt
		sed "s/node-to-replace/$node/g" ./take-backup-to-s3.sh > tmp_script_to_ship.sh
		echo "Creating required directories"
		ssh -i ~/$key ubuntu@$host 'sudo mkdir -p /root/scripts/backup/'
		echo "Copying required files on remote host"
		scp -i ~/$key -r ./tmp_script_to_ship.sh ubuntu@$host:~/
		scp -i ~/$key -r ./update-cron-jobs.sh ubuntu@$host:~/
		echo "Changing permissions of required files on remote host"
		ssh -i ~/$key ubuntu@$host 'sudo mv ~/tmp_script_to_ship.sh /root/scripts/backup/take-backup-to-s3.sh;sudo chmod 777 /root/scripts/backup/take-backup-to-s3.sh;'
		ssh -i ~/$key ubuntu@$host 'sudo mv ~/update-cron-jobs.sh /root/scripts/backup/update-cron-jobs.sh;sudo chmod 777 /root/scripts/backup/update-cron-jobs.sh;'
		echo "Updating crontab on remote hosts"
		ssh -i ~/$key ubuntu@$host bash -c "'sudo /root/scripts/backup/update-cron-jobs.sh;'"
	fi
done < $filename

rm -rf ./tmp*
