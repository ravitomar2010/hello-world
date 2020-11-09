#!/bin/bash

#######################################################################
########################### Global Variables ##########################
#######################################################################
env='prod'
profile=${env}
# parameters='i-0bd8e105dcf45dff7 t3.large
# i-01f650827029c6936 t3.medium'

#######################################################################
############################# Generic Code ############################
#######################################################################

getSSMParameters(){
        echo "Fetching Parameters from ssm"
        devopsMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/devopsMailList" --with-decryption --output text --query Parameter.Value`
        leadsMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/leadsMailList" --with-decryption --query Parameter.Value --output text`
        toMailList=`aws ssm get-parameter --profile ${profile} --name "/a2i/${profile}/ses/toAllList" --with-decryption --query Parameter.Value --output text`
        fromEmail=`aws ssm get-parameter --name /a2i/${profile}/ses/fromemail --profile ${profile} --with-decryption --query Parameter.Value --output text`

        if [ ${profile} == 'stage' ]
        then
                redshiftuserName="axiom_rnd"
        else
                redshiftuserName="axiom_stage"
        fi
        # echo "$hostName-$portNo-$dbName-$redshiftPassword-$accountID-$redshiftuserName"
}

#######################################################################
######################### Feature Function Code #######################
#######################################################################

listInstances(){

    echo "Listing instances for ${profile}"
    aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId][]' --profile ${profile} --output text > tmpListOfInstance.txt
}

getInstanceDetails(){
filename='tmpListOfInstance.txt'

  while read line; do
    if [[ $line == "" ]]; then #if1
        echo "Skipping empty line"
    else
        echo "Working on $line"
        instanceID="${line}"
        # echo "instanceID is ${instanceID}"
        instanceType=`aws ec2 describe-instances --instance-ids ${instanceID} --profile ${profile} --query Reservations[*].Instances[*].InstanceType --output text`
        instaceState=` aws ec2 describe-instance-status --instance-ids ${instanceID} --profile ${profile} --query InstanceStatuses[*].InstanceState | grep '"Name":' | cut -d ':' -f2 | tr -d '"'`
        instaceName=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instanceID" --profile ${profile} --query 'Tags[?Key==`Name`].[Value][]' --output text)
        echo "instaceName : ${instaceName} ; instanceID : ${instanceID} ; instanceType : ${instanceType} ; instaceState : ${instaceState}"
        if [[ ${profile} == 'prod' ]]; then
            if [[ ${instaceState} == '' ]]; then
                instaceState='Stopped'
                echo "<tr><td><font face=Arial color=BLUE>${profile}</font></td><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td><font face=Arial color=RED>${instaceState}</font></td></tr>" >> tmpFinalDetails.txt
            else
                echo "<tr><td><font face=Arial color=BLUE>${profile}</font></td><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td><font face=Arial color=GREEN>${instaceState}</font></td></tr>" >> tmpFinalDetails.txt
                # echo "<tr><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td>${instaceState}</td></tr>" >> tmpFinalDetails.txt
            fi
        else
            if [[ ${instaceState} == '' ]]; then
                instaceState='Stopped'
                echo "<tr><td><font face=Arial color=ORANGE>${profile}</font></td><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td><font face=Arial color=RED>${instaceState}</font></td></tr>" >> tmpFinalDetails.txt
            else
                echo "<tr><td><font face=Arial color=ORANGE>${profile}</font></td><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td><font face=Arial color=GREEN>${instaceState}</font></td></tr>" >> tmpFinalDetails.txt
                # echo "<tr><td>${instaceName}</td><td>${instanceID}</td><td>${instanceType}</td><td>${instaceState}</td></tr>" >> tmpFinalDetails.txt
            fi
        fi

    fi # if 1
  done < $filename

}

prepareOutput(){
  echo '<pre>' > tmpMail.txt
  echo '<h4>Hi All\, Please find the instance report for A2i account </h4>' >> tmpMail.txt

  echo '<table BORDER=3 BORDERCOLOR=#0000FF BORDERCOLORLIGHT=#33CCFF BORDERCOLORDARK=#0000CC width= 80%>' >> tmpMail.txt
  echo '<tr><th>Account</th><th>InstanceName</th><th>InstanceID</th><th>InstanceType</th><th>InstaceState</th></tr>' >> tmpMail.txt
  cat tmpFinalDetails.txt >> tmpMail.txt
  echo '</table>' >> tmpMail.txt

  echo '<h4>In case of any concern kindly reach out to team DevOps.<br><br>' >> tmpMail.txt
  echo '<p>Regards\,<br>Team DevOps</h4></p>' >> tmpMail.txt
  echo '</pre>' >> tmpMail.txt

}

sendNotification(){

    getSSMParameters
    aws ses send-email \
    --from "${fromEmail}" \
    --destination "ToAddresses=${devopsMailList}","CcAddresses=yogesh.patil@axiomtelecom.com" \
    --message "Subject={Data=A2i EC2 instace details ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpMail.txt),Charset=utf8}}" \
    --profile $profile

}


#######################################################################
############################# Main Function ###########################
#######################################################################

rm -rf tmpFinalDetails.txt
touch tmpFinalDetails.txt

profile='prod'
listInstances
getInstanceDetails
profile='stage'
listInstances
getInstanceDetails

profile='prod'
prepareOutput
sendNotification

#############################
########## CleanUp ##########
#############################

echo "Working on CleanUp"
sudo rm -rf ./tmp*
