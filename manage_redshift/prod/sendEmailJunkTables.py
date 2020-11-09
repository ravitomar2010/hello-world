import os
import boto3
import psycopg2
import pandas as pd
from pathlib import Path

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile=""
queryfile='tmp_junk_tables.csv'
filename='temp_email_contents.html'
fromEmail=""
toMail=[]
subject=''
headerForHTML=''
footerForHTML='</body> </html>'

#######################################################################
############################# Generic Code ############################
#######################################################################

def setProfile(l_profile):
    if l_profile == '':
        base_path = str(Path(os.getcwd()))
        l_profile=(base_path.split('/')[-1])
        print('profile is ',l_profile)
        return l_profile
    else:
        print('profile is ',l_profile)
        return l_profile

def getSSMParameters(l_profile):
    print("Fetching parameters from SSM for ",profile, " account")
    session = boto3.Session(profile_name=profile)
    client = session.client('ssm')
    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/ses/fromemail",
        WithDecryption=True
    )
    fromEmail=response['Parameter']['Value']
    #fromEmail=response(['Parameter']['Value'])
    #print('From email is ',fromEmail)

    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/ses/tomail",
        WithDecryption=True
    )
    tmp_toMail=response['Parameter']['Value']
    for item in tmp_toMail.splitlines():
        toMail.append(item)

    ## toMail.append('yogesh.patil@axiomtelecom.com')
    ## toMail.append('ravi.tomar@intsof.com')
    # print('To email is ',toMail)
    return fromEmail,toMail

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def convertCSVToHTML():
    print('Converting CSV to HTML for email')
    data = pd.read_csv(queryfile,sep=",",index_col=False)
    data = data.drop(0)
    data = data.drop(len(data.index));
    #print(data)
    #print(data.to_html());
    emailHTML=(headerForHTML+data.to_html()+footerForHTML);
    #print(emailHTML)
    return emailHTML;

def sendMail(l_data_to_send, l_profile):
    print('Sending mail')
    #print('emailText is ',emailText)
    session = boto3.Session(profile_name=profile)
    client = session.client('ses')
    response = client.send_email(
        Source=fromEmail,
        Destination={
            'ToAddresses': toMail
        },
        Message={
            'Subject': {
                'Data': subject,
                'Charset': 'UTF-8'
            },
            'Body': {
                # 'Text': {
                #     'Data': emailText,
                #     'Charset': 'UTF-8'
                # }
                # ,
                'Html': {
                    'Data': l_data_to_send ,
                    'Charset': 'UTF-8'
                },
            }
        }
    )

#######################################################################
############################# Main Function ###########################
#######################################################################

profile=setProfile(profile)
subject=profile+" | Suspected redshift junk tables"
headerForHTML='<html> <body> <p>Hi All</p> <p>Please find below list of junk tables from redshift for '+profile+' account. Please change these table names to match the coding standards. Please reach out to DevOps If we can delete any of these.</p>'
fromEmail,toMail=getSSMParameters(profile)
data_to_send=convertCSVToHTML()
sendMail(data_to_send, profile)

#############################
########## CleanUp ##########
#############################
