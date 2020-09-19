#!/bin/bash
#write out current crontab
crontab -l > mycron
#echo new cron into cron file

cronFlag=`cat mycron | grep 'clean-logs.sh' | wc -l`

	if [[ $cronFlag -eq 0 ]]; then
		echo "0 * * * * /root/scripts/logsmanagement/clean-logs.sh" >> mycron
		#install new cron file
		crontab mycron
	fi

rm mycron
