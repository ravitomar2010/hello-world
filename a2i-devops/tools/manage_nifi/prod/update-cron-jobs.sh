#!/bin/bash
#write out current crontab
crontab -l > mycron
#echo new cron into cron file

cronFlag=`cat mycron | grep 'take-backup-to-s3.sh' | wc -l`

	if [[ $cronFlag -eq 0 ]]; then
		echo "0 * * * * /root/scripts/backup/take-backup-to-s3.sh" >> mycron
		#install new cron file
		crontab mycron
	fi

rm mycron
