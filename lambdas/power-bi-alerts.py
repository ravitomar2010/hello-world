import boto3
import urllib3 
import json

ssm = boto3.client('ssm')   #to get parameters
ses = boto3.client('ses')   #to send an email
http = urllib3.PoolManager() #to send post request on slack

#sending notification on slack
def send_slack_notification(subject_value):
    webhook_email=ssm.get_parameter(Name=f'/a2i/prod/slack/power-bi-alerts/channelLink', WithDecryption=False)['Parameter']['Value']
    msg = {
        "channel": "#power-bi-alerts",
        "username": "Power-bi Alert",
        "text": subject_value,
        "icon_emoji": ":loudspeaker:"
    }
    encoded_msg = json.dumps(msg).encode('utf-8')
    resp = http.request('POST',webhook_email, body=encoded_msg)
    print(resp.status)

#sending an email
def send_email(subject_value):
    fromEmail=ssm.get_parameter( Name='/a2i/prod/ses/fromemail', WithDecryption=True)['Parameter']['Value']
    powerBiMailList=ssm.get_parameter(Name="/a2i/prod/power-bi/alert/mailList",WithDecryption=True)['Parameter']['Value'].split(',')
    cc_email = ssm.get_parameter(Name='/a2i/prod/ses/devopsMailList', WithDecryption=False)['Parameter']['Value']
    cc_email = cc_email.replace('[\n','').replace('\n]','').split(',\n')
    subject="prod | power-bi | alert"
    message=f'<p>Hello All,</p> <p>This is to inform you that there is a Refresh failure alert <b>"{subject_value}"</b> from power-bi.<br>Kindly look into it. <br><br>Regards<br>DevOps team</p>'
    ses.send_email(
        Source=fromEmail,
        Destination={ 'ToAddresses': powerBiMailList, 'CcAddresses': cc_email},
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


def lambda_handler(event, context):
    headers=event['Records'][0]['ses']['mail']['headers']
    
    #iterating over headers
    for header in headers :
        
        #checking subject for failure alert
        if header['name'] == 'Subject' :
            subject_value=header['value']
            
            if 'Refresh failed' in subject_value:
                send_slack_notification(subject_value)
                send_email(subject_value)
            break
        