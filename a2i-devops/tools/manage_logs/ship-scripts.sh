#!/bin/bash
filename="host_list.txt"

while read line; do
	if [[ $line == "" ]]; then
    echo "Skipping empty line"
  else
    echo "line is $line"
    host=`echo $line | cut -d ' ' -f1`
    key=`echo $line | cut -d ' ' -f2`
    dir=`echo $line | cut -d ' ' -f3`
    echo "Host is $host, key is $key and dir is $dir"
		echo "$dir" > tmp_dir_list.txt
		#dirFileName=`echo "tmp_dir_$host.txt"`
		#echo "dirFileName is $dirFileName"
		echo "Creating required directories"
		ssh -i ~/$key ubuntu@$host 'sudo mkdir -p /root/scripts/logsmanagement/'
		echo "Copying required files on remote host"
		scp -i ~/$key -r ./clean-logs.sh ubuntu@$host:~/
		scp -i ~/$key -r ./tmp_dir_list.txt ubuntu@$host:~/
		scp -i ~/$key -r ./update-cron-jobs.sh ubuntu@$host:~/
		echo "Changing permissions of required files on remote host"
		ssh -i ~/$key ubuntu@$host 'sudo mv ~/clean-logs.sh /root/scripts/logsmanagement/;sudo chmod 777 /root/scripts/logsmanagement/clean-logs.sh;'
		ssh -i ~/$key ubuntu@$host 'sudo mv ~/tmp_dir_list.txt /root/scripts/logsmanagement/dir_list.txt;sudo chmod 777 /root/scripts/logsmanagement/dir_list.txt;'
		ssh -i ~/$key ubuntu@$host 'sudo mv ~/update-cron-jobs.sh /root/scripts/logsmanagement/update-cron-jobs.sh;sudo chmod 777 /root/scripts/logsmanagement/update-cron-jobs.sh;'
		echo "Updating crontab on remote hosts"
		ssh -i ~/$key ubuntu@$host bash -c "'sudo /root/scripts/logsmanagement/update-cron-jobs.sh;'"
		echo "Done for host $host"
	fi
done < $filename

echo "Working on cleanup "

rm -rf ./tmp*
