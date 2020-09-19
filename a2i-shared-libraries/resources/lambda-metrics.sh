#!/bin/sh
alias date='gdate'
YESTERDAY=`date -d '1 days ago' '+%Y/%m/%d'`
RANGE=`date -d "$2 days ago" '+%Y/%m/%d'`
START_TIME=`date -d $RANGE' 00:00:00 9 hours ago' '+%s'`
END_TIME=`date -d $YESTERDAY' 23:59:59 9 hours ago' '+%s'`
CLOUDWATCH_LOG_GROUP_NAME="/aws/lambda/$1"
REGION="eu-west-1"
#QUERY="fields @timestamp, @message | limit 10"
QUERY='
filter @type = "REPORT"
| fields @timestamp as Timestamp, @logStream as LogStream, @billedDuration as BilledDurationInMS, @memorySize/1000000 as MemorySetInMB, @billedDuration/1000*MemorySetInMB/1024 as BilledDurationInGBSeconds, @maxMemoryUsed/1000000 as MemoryConsumedInMB
| sort  BilledDurationInGBSeconds desc
| head 20
'
echo 'Start aggregation.'

QUERYID=`
~/.local/bin/aws logs start-query \
--log-group-name $CLOUDWATCH_LOG_GROUP_NAME \
--start-time $START_TIME \
--end-time $END_TIME \
--query-string "$QUERY" \
--region $REGION \
--output text
`


if [ "$?" -ne 0 ]; then
	echo "No logs found for $1"
	exit
fi

#Waiting fir completion
printf 'Waiting for completion'
while : 
do
    STATUS=`~/.local/bin/aws logs get-query-results --query-id $QUERYID --output text --region $REGION | sed -n '1p'`
    if [ "$STATUS" = "Complete" ]; then
        break
    fi
    printf "."
    sleep 1s;
done
echo '\n'

#aws logs get-query-results --query-id $QUERYID --output table --region $REGION
RESULT_JSON=`~/.local/bin/aws logs get-query-results --query-id $QUERYID --output json --region $REGION`
TODAY=`date -d '0 days ago' '+%Y-%m-%d'`
MATCHED=`echo $RESULT_JSON | jq '.statistics.recordsMatched'`
if [ $MATCHED -gt 0 ] ; then
    #
    echo $RESULT_JSON \
    | jq '.results[0]' \
    | jq -r -c '([ .[].field | values ]) | @csv' \
    > "./$1-$TODAY.csv"

    echo $RESULT_JSON \
    | jq '.results[]' \
    | jq -r -c '([ .[].value | values ]) | @csv' \
    >> "./$1-$TODAY.csv"
fi
cut -d, -f2,7 --complement ./$1-$TODAY.csv | column -s, -t
~/.local/bin/aws s3 cp "./$1-$TODAY.csv" "s3://a2i-lambda-execution-metrics/$1/" > /dev/null 2>&1
echo 'Aggregation has completed.\n'
