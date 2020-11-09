import os
import sys
import json
import boto3
import urllib3
import psycopg2
from datetime import datetime
from pathlib import Path

########################################################### VARIABLE DECLARATION ####################################################

ssm_pid_list = [] #hold the ssm parameter value for query monitoring as list
dbClient = "axiom"
profile = sys.argv[1]

http = urllib3.PoolManager()  # to send post request on slack
session = boto3.Session(profile_name=profile)

s3 = session.client("s3")   #to upload/download file 
ses = session.client("ses") #to send email
ssm = session.client("ssm") #to get ssm parameters

local_file_name = 'tmpQueries.txt' 
month = datetime.now().strftime('%B')
year = datetime.now().strftime('%Y')

########################################################### SETTING PROFILE ####################################################

def setProfile(l_profile):
    if l_profile == '':
        base_path = str(Path(os.getcwd()))
        l_profile=(base_path.split('/')[-1])
        print('profile is ',l_profile)
        return l_profile
    else:
        print('profile is ',l_profile)
        return l_profile

########################################################### GETTING SSM PARAMETERS ####################################################

def getSSMParameter(profile):
    global hostName, portNo, dbName, redshiftPassword, redshiftUserName, from_email, toMailList, toDevopsList
    print("Fetching SSM Parameters")
    hostName = ssm.get_parameter(Name="/a2i/" + profile + "/redshift/host", WithDecryption=True)["Parameter"]["Value"]
    portNo = ssm.get_parameter(Name="/a2i/" + profile + "/redshift/port", WithDecryption=True)["Parameter"]["Value"]
    dbName = ssm.get_parameter(Name="/a2i/" + profile + "/redshift/db/" + dbClient, WithDecryption=True)["Parameter"]["Value"]
    redshiftPassword = ssm.get_parameter(Name="/a2i/infra/redshift_" + profile + "/rootpassword", WithDecryption=True)["Parameter"]["Value"]
    # accountID = ssm.get_parameter(Name="/a2i/" + profile + "/accountid", WithDecryption=True)["Parameter"]["Value"]
    from_email = ssm.get_parameter( Name=f'/a2i/{profile}/ses/fromemail', WithDecryption=False)['Parameter']['Value']
    toMailList = ssm.get_parameter(Name=f'/a2i/{profile}/ses/toAllList', WithDecryption=False)['Parameter']['Value'].replace('[\n','').replace('\n]','').split(',\n')
    toDevopsList = ssm.get_parameter(Name=f'/a2i/{profile}/ses/devopsMailList', WithDecryption=False)['Parameter']['Value'].split(',\n')
    toDevopsList.append('m.naveenkumar@axiomtelecom.com')
    if profile == "stage":
        redshiftUserName = "axiom_rnd"
    else:
        redshiftUserName = "axiom_stage"

    try:
        global ssm_pid_list
        ssm_pid_list = ssm.get_parameter(Name=f"/a2i/{profile}/redshift/queryMonitoring", WithDecryption=True)["Parameter"]["Value"].split(",")
    except:
        print("No previous long running queries data in SSM")

########################################################### DOWNLOAD FILE FROM S3 ####################################################

def downloadS3File():
    #for each object in a2i-devops-prod/redshift/queryLogs
    for content in s3.list_objects(Bucket = 'a2i-devops-prod',Prefix ='redshift/queryLogs')['Contents']:
        if f'{month}-{year}' in content['Key']:
            print (f"{month}-{year} folder exists in a2i-devops-prod bucket")
            try:
                s3.download_file('a2i-devops-prod', f'redshift/queryLogs/{month}-{year}/prod-queries.txt', 'tmpQueries.txt')
            except:
                # print (f"tmpQueries.txt doesn't exist in redshift/queryLogs/{month}-{year}")
                Path('tmpQueries.txt').touch()
            return
        
    #create month-year folder
    s3.put_object(
        Bucket='a2i-devops-prod',
        Key=f'redshift/queryLogs/{month}-{year}/'
    )

########################################################### SENDING EMAIL ####################################################

def send_email(mail_body, header):
    
    #check if mail_body has value
    if len(mail_body)>0:

        print("Sending email")
        #Creating header, footer and mail_body for email
        message=f'''
        <h4>Hello All,</h4>
        <p>{header}
        <table>{mail_body}</table>
        Regards,<br>
        Team DevOps</p>
        '''
        subject=f"{profile} | Redshift | Long Running Queries"
        response = ses.send_email(
            Source=from_email,
            Destination={ 'ToAddresses': ['harsh.agarwal@intsof.com', 'anees.mohamed@axiomtelecom.com', 'sandeep.sunkavalli@tothenew.com'], 'CcAddresses': toDevopsList},
            Message={
                'Subject': { 'Data': subject, 'Charset': 'utf8' },
                'Body': {
                    'Text': { 'Data': 'Testing Body', 'Charset': 'utf8' },
                    'Html': {
                    'Data': message,
                    'Charset': 'utf8'
                    }
                }
            }
        )
        print(response)

########################################################### SENDING SLACK NOTIFICATION ####################################################


def send_slack_notification(notification_no, username, db_name, status, durationInMin, pid):
    
    print("sending slack notification")
    webhook_email=ssm.get_parameter(Name=f'/a2i/{profile}/redshift/a2i-redshift-alerts/channelLink', WithDecryption=False)['Parameter']['Value']
    pretext = fallback = f"{profile} | Redshift long running queries"
    msg = {
        "attachments": [
            {
                "fallback": fallback,
                "color": "#2eb886",
                "pretext": pretext,
                "fields": [
                    {"title": "Notification no", "value": notification_no, "short": "true"},
                    {"title": "Process Id", "value": pid, "short": "true"},
                    {"title": "Username", "value": username, "short": "true"},
                    {"title": "Db Name", "value": db_name, "short": "true"},
                    {"title": "Status", "value": status, "short": "true"},
                    {"title": "Duration (in minutes)", "value": durationInMin, "short": "true"},
                ],
            }
        ]
    }
    encoded_msg = json.dumps(msg).encode("utf-8")
    http.request("POST", webhook_email, body=encoded_msg)

########################################################### DELETE SSM PARAMETER ####################################################

def DeleteSsmParameter():
    print("Deleting SSM Parameter")
    ssm.delete_parameter( Name = f"/a2i/{profile}/redshift/queryMonitoring")

########################################################### WRITE LOGS IN S3 BUCKET #################################################

def updateLogsInS3(pid, username, db_name, query):
    
    file1 = open(local_file_name, "a")  # append mode 
    content=f'''
    Process Id: {pid}
    Username: {username}
    Database: {db_name}
    Query: {query}

    ************************************************************************************************************************************************
    '''
    file1.write(content) 
    file1.close()

########################################################### FETCHING DATA FROM DB ################################################### 

def getRecords():

    sql = "select * from stv_recents where status != 'Done' and duration > 1800000000"
    conn = psycopg2.connect(dbname=dbName,user=redshiftUserName,password=redshiftPassword,port=portNo,host=hostName)
    cur = conn.cursor()
    cur.execute(sql)
    records = cur.fetchall()

    #if there are no time taking queries in Redshift then delete the ssm parameter and exit 
    if len(records) == 0:
        print(f"No Long running queries in {profile} Redshift")
        if len(ssm_pid_list) > 0:
            DeleteSsmParameter()
        sys.exit()
    else:
        print(f"No. of queries running from last 30 minutes: {len(records)}")
    return records


def processingRecords(records):
    print("Processing each record")
    #hold list of string pid and number of prior notifications sent separated by space 
    ssm_value = []  
    #creating mail body
    mail_body=''
    mail_body_30=''

    for record in records:
        status = record[1]
        durationInMicrosec = record[3]
        username = record[4].strip()
        db_name = record[5].strip()
        query = record[6]
        pid = record[7]

        durationInMin=str(round((durationInMicrosec)/(1000000*60)))
        print(f"Duration for pid {pid} is {durationInMin} minutes")

        #holds number of prior notifications sent
        notification_no = 0

        #if SSM contain pids
        if len(ssm_pid_list) > 0:
            # searching for pid in ssm parameter
            ssm_pid_notification = [ssm_pid for ssm_pid in ssm_pid_list if str(pid) in ssm_pid]
            # fetching number of prior notifications sent for corresponding pid from ssm value
            notification_no = int(ssm_pid_notification[0].split(" ")[1] if len(ssm_pid_notification) > 0 else "0")

        #increamenting by 1
        notification_no += 1

        #sending slack notification
        send_slack_notification(notification_no, username, db_name, status, durationInMin,pid)

        #appending pid and prior notificatons number as a string to ssm_value
        ssm_value.append(str(pid) + " " + str(notification_no))

        #prepare mail body if duration of query exceeds 60 minutes 
        if int(durationInMin) > 60:
            mail_body+=f'''
                        <tr><td colspan="2">********************************</td><tr>
                        <tr><td>Username:</td><td>{username}</td></tr>
                        <tr><td>Status:</td><td>{status}<br></td></tr>
                        <tr><td>Db name:</td><td>{db_name}<br></td></tr>
                        <tr><td>Process Id:</td><td>{pid}<br></td></tr>
                        <tr><td>Duration:</td><td>{durationInMin} minutes<br></td></tr>
                       '''

        #prepare mail body for duration of 30 minutes or more 
        if int(durationInMin) > 29:
            mail_body_30+=f'''
                        <tr><td colspan="2">********************************</td><tr>
                        <tr><td>Username:</td><td>{username}</td></tr>
                        <tr><td>Status:</td><td>{status}<br></td></tr>
                        <tr><td>Db name:</td><td>{db_name}<br></td></tr>
                        <tr><td>Process Id:</td><td>{pid}<br></td></tr>
                        <tr><td>Duration:</td><td>{durationInMin} minutes<br></td></tr>
                        <tr><td>Query:</td><td>{query}<br></td></tr>
                        '''

        updateLogsInS3(pid, username, db_name, query)
    return ssm_value, mail_body, mail_body_30

########################################################### UPLOAD FILE IN S3 ####################################################

def uploadFileinS3():
    s3.upload_file(local_file_name, 'a2i-devops-prod', f'redshift/queryLogs/{month}-{year}/prod-queries.txt')

########################################################### CREATE SSM PARAMETER ####################################################

def createSSMParameter(ssm_value):
    if len(ssm_value) > 0:
        print("Creating SSM Parameter")
        #creating a coma separated string from list
        ssm_value = ",".join(ssm_value)
        #writing parameter to ssm
        ssm.put_parameter(
            Name=f"/a2i/{profile}/redshift/queryMonitoring",
            Description="Stores space separated list of pid and number of prior notifications sent for Redshift long running queries",
            Value=ssm_value,
            Type="String",
            Overwrite=True,
            Tier="Standard",
            DataType="text",
        )

########################################################### MAIN CODE ####################################################

profile=setProfile(profile)
getSSMParameter(profile)
downloadS3File()
records=getRecords()
ssm_value, mail_body, mail_body_30=processingRecords(records)
uploadFileinS3()
os.remove(local_file_name)
createSSMParameter(ssm_value)

#sending email for queries running from more than 30 minutes
header=f"Below is the information of queries running on <b>{profile} Redshift</b> from more than 30 minutes."
send_email(mail_body_30,header)

#sending email for queries running from more than 60 minutes
header=f"Below is the information of queries running on <b>{profile} Redshift</b> for more than 60 minutes."
send_email(mail_body, header)