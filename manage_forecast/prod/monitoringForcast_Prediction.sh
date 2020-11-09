#!/bin/bash
#Author : Ravi Tomar!
#Company : Axiom Telecom#
##Description :used to monitor aws forcast and  prediction service limit ##
###Dated 02 july 2020 #####


######### Varibale declaration ###################
env=$1

######################### checking aws forecast count ##################

checkForecastCount(){

forecastCount=$(aws forecast list-forecasts --profile $env --query "Forecasts[?Status=='ACTIVE']" | grep '"ForecastArn":' | cut -d'/' -f2 | cut -d'"' -f1 | wc -l)
echo forecast count on $env is $forecastCount .

}

######################### checking aws forecast Prediction count ##################

checkPredictorsCount(){

predictorCount=$(aws forecast list-predictors --profile $env --query "Predictors[?Status=='ACTIVE']" | grep '"PredictorArn":' | cut -d '/' -f2 | cut -d'"' -f1 | wc -l)
echo prediction count on $env is $predictorCount .

}

################################ Sending email ##################################

sendingForcastMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=axiomdipoffshoredev@intsof.com,Shorveer.singh@tothenew.com,abhishek.goswami@tothenew.com","CcAddresses=yogesh.patil@axiomtelecom.com,m.naveenkumar@axiomtelecom.com" \
        --message "Subject={Data=AWS $env Forecast Monitoring Alert,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi Team <br> <br>This is to inform you that AWS $env Forecast service limit has reached threshold limit 20.<br>Right now AWS $env Forecast count is $forecastCount.<br><br>Please take action accordingly<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env
}
sendingPredictionMail(){

        aws ses send-email \
        --from "a2iteam@axiomtelecom.com" \
        --destination "ToAddresses=axiomdipoffshoredev@intsof.com,shorveer.singh@tothenew.com,abhishek.goswami@tothenew.com","CcAddresses=yogesh.patil@axiomtelecom.com,m.naveenkumar@axiomtelecom.com" \
        --message "Subject={Data=AWS $env Prediction Monitoring Alert,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=Hi Team <br> <br>This is to inform you that AWS $env Forecast Prediction service threshold limit is 50.<br>Right now AWS $env Forecast prediction count is $predictorCount.<br><br>Please take action accordingly<br><br><br>Regards<br>Devops Team ,Charset=utf8}}" \
        --profile $env
}
#################################### put time stamp on aws #####################################
puttimestampaws(){

emailtriggertimestamp=$(date +%s)
aws ssm put-parameter --name "/a2i/$env/$var/timestamp/email" --value "$emailtriggertimestamp" --type SecureString --overwrite --profile $env
echo "updated aws timestamp  is $emailtriggertimestamp"

}

gettimestampaws(){

awsemailtimestamp=$(aws ssm get-parameter --name "/a2i/$env/$var/timestamp/email" --with-decryption --profile $env --output text --query Parameter.Value)

echo " fetched timestamp on aws is $awsemailtimestamp"

}

waitThreeHour(){

        gettimestampaws
        timestampnow=$(date +%s)
        isthreehour=$( expr $timestampnow - $awsemailtimestamp )
        echo $isthreehour

}


######################### checking aws forecast service limit and sending email ##################

checkForecastlimit(){

if [ $forecastCount -ge 19 ]
then
   var=forecast
   waitThreeHour
   if [ $isthreehour -ge 10800  ]
   then
        echo sending mail Forecast
        sendingForcastMail
        puttimestampaws
   else
        echo "waiting......... to trigger after 3 hour "
   fi
else
   echo $env Forecast Service Limit is below 9 Hence No action required.
fi

}

######################### checking aws forecast prediction  service limit and sending email ##################

checkPredictionlimit(){

if [ $predictorCount -ge 49  ]
then
   var=prediction
   waitThreeHour
   if [ $isthreehour -ge 10800  ]
   then
        echo sending mail Prediction
        sendingPredictionMail
        puttimestampaws
   else
        echo "waiting......... to trigger after 3 hour "
   fi
else
   echo $env Forecast Prediction Service Limit is below 49 Hence No action required.
fi

}

############################### Main function ##################################

checkForecastCount
checkPredictorsCount
checkForecastlimit
checkPredictionlimit
