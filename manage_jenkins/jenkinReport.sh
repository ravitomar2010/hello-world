#!/bin/bash
##Author Ravi Tomar ##
## dated 28 October 2020 ##
## Description: Script used to send detailed report of jenkins ####
#### Team Devops ####

echo '' > statusreport.txt

listjobs(){

        jenkinjobs=$(curl -X POST -L --user jenkins-admin:${token} http://jenkins.a2i.infra:8080/api/json?tree=jobs[name] | jq -r '.jobs[].name')

}

jenkins_job_status(){

        job_name=$1
        echo "working on job $job_name"
        status=$(curl -X POST -L --user jenkins-admin:${token} "http://jenkins.a2i.infra:8080/job/${job_name}/lastBuild/api/json" | jq -r '.result')

sleep 2

  if [[ $status == "SUCCESS" ]]; then
      echo "$job_name status is $status"
  elif [ -z "$status" ]
          then
                  status="DISABLED"
                  echo -e "<tr> <td>$job_name</td> <td><b style=color:Blue;>$status</b></td> </tr>" >> statusreport.txt
  elif [ $status == "null" ]
          then
                 status="RUNNING"
                 echo -e "<tr> <td>$job_name-${jobsubjob}-${branch}</td> <td><b style=color:Blue;>$status</b></td> </tr>" >> statusreport.txt
  else
      echo -e "<tr> <td>$job_name</td> <td><b style=color:Red;>$status</b></td> </tr>" >> statusreport.txt
  fi

}

onenestedjob(){

      job_name=$1
      branch=$2
      echo "working on job $job_name-$branch"
      status=$(curl -X POST -L --user jenkins-admin:${token} "http://jenkins.a2i.infra:8080/job/${job_name}/job/${branch}/lastBuild/api/json" | jq -r '.result')


  sleep 2

  if [[ $status == "SUCCESS" ]]; then
      echo "$job_name status is $status"
    elif [ $status == "null" ]
           then
                   status="RUNNING"
                   echo -e "<tr> <td>$job_name-${jobsubjob}-${branch}</td> <td><b style=color:Blue;>$status</b></td> </tr>" >> statusreport.txt
  else
      echo -e "<tr> <td>$job_name-$branch</td> <td><b style=color:Red;>$status</b></td> </tr>" >> statusreport.txt
  fi


}
pipelinejobsextraction(){

job_name=$1

jobsubjobs=$(curl -X POST -L --user jenkins-admin:${token} http://jenkins.a2i.infra:8080/job/${job_name}/api/json?tree=jobs[name] | jq -r '.jobs[].name')

for jobsubjob in $jobsubjobs
do
        jenkins_subjob_status ${job_name} ${jobsubjob} developer

        sleep 2

        jenkins_subjob_status ${job_name} ${jobsubjob} master


done

}

jenkins_subjob_status(){

        job_name=$1
        jobsubjob=$2
        branch=$3
        echo "checking job $job_name-$jobsubjob-$branch"
        status=$(curl -X POST -L --user jenkins-admin:${token} "http://jenkins.a2i.infra:8080/job/${job_name}/job/${jobsubjob}/job/${branch}/lastBuild/api/json" | jq -r '.result')

sleep 2

  if [[ $status == "SUCCESS" ]]; then
      echo -e "job name $job_name-${jobsubjob}-${branch} status is $status"

   elif [ -z "$status" ]
          then
                  status="$branch NOT EXIST"
                  echo -e "<tr> <td>$job_name-${jobsubjob}-${branch}</td> <td><b style=color:Blue;>$status</b></td> </tr>" >> statusreport.txt

   elif [ $status == "null" ]
          then
                  status="RUNNING"
                  echo -e "<tr> <td>$job_name-${jobsubjob}-${branch}</td> <td><b style=color:Blue;>$status</b></td> </tr>" >> statusreport.txt
   else

      echo -e "<tr> <td>$job_name-${jobsubjob}-${branch}</td> <td><b style=color:Red;>$status</b></td> </tr>" >> statusreport.txt
  fi

}

prepareOutput(){

    echo '<pre>' > tmpFinalOP.txt
    # echo "<p style=font-size=15px;>Hi All\, <br>Please find below list of lambdas which are older/ junk/ unused in $profile account.</p>" >> tmpFinalOP.txt
    echo "<h3>Hi All\, <br><br>Please find below jenkin job status report.</h3>" >> tmpFinalOP.txt
    echo '<table>' >> tmpFinalOP.txt
    echo '<tr><td>-------------+++++++++++----------</td><td>++++++++++-----------++++++++++</td></tr>' >> tmpFinalOP.txt
    cat statusreport.txt >> tmpFinalOP.txt
    echo '<tr><td>-------------+++++++++++----------</td><td>++++++++++-----------++++++++++</td></tr>' >> tmpFinalOP.txt
    echo "</table><br>." >> tmpFinalOP.txt
    echo "<h3>Please reach out to devops in case of any concerns. <br>Regards\,<br>DevOps Team</h3>" >> tmpFinalOP.txt
    echo '</pre>' >> tmpFinalOP.txt
}


sendMail(){

     # getSSMParameters
      echo 'Sending email to concerned individuals'
      aws ses send-email \
      --from "$fromEmail" \
      --destination "ToAddresses=$toMail","CcAddresses=yogesh.patil@axiomtelecom.com" \
      --message "Subject={Data= Jenkin Job Status Notification ,Charset=utf8},Body={Text={Data=Testing Body,Charset=utf8},Html={Data=$(cat tmpFinalOP.txt),Charset=utf8}}" \
      --profile prod

}

getSSMParameters(){

  echo "Pulling parameters from SSM for prod environment"
  fromEmail=`aws ssm get-parameter --name /a2i/prod/ses/fromemail --profile prod --with-decryption --query Parameter.Value --output text`
  toMail=`aws ssm get-parameter --name /a2i/prod/ses/devopsMailList --profile prod --with-decryption --query Parameter.Value --output text`
  leadsMailList=`aws ssm get-parameter --name /a2i/prod/ses/fromemail --profile prod --with-decryption --query Parameter.Value --output text`
  token=`aws ssm get-parameter --name /a2i/infra/jenkins/admin-api-token --profile stage --with-decryption --query Parameter.Value --output text`

}

getSSMParameters
listjobs
#echo $token
for jenkinjob in $jenkinjobs
do
        if [ $jenkinjob == "Google-sheet-pipeline" ]
          then
                onenestedjob $jenkinjob master
                sleep 2
                onenestedjob $jenkinjob developer

        elif [ $jenkinjob == "a2i-lambda-pipeline" ]
          then
               pipelinejobsextraction $jenkinjob

        elif [ $jenkinjob == "production-df-init" ]
          then
                  onenestedjob $jenkinjob master


          elif [ $jenkinjob == "production-df-init-ksa" ]
          then
                  onenestedjob $jenkinjob master

        elif [ $jenkinjob == "stage-df-init" ]
          then
                  onenestedjob $jenkinjob developer

        elif [ $jenkinjob == "stage-df-init-ksa" ]
          then
               onenestedjob $jenkinjob ksa_dp
        else

                jenkins_job_status $jenkinjob

        fi

done
#echo '</pre>' >> statusreport.txt
prepareOutput
sendMail
