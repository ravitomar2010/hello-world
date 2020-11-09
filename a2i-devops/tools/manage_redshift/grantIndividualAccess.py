import os
import sys
from validate_email import validate_email
import subprocess
from pathlib import Path
import boto3
import time

#######################################################################
########################### Global Variables ##########################
#######################################################################


email=sys.argv[1]
permission=sys.argv[2]
dbClient=sys.argv[3]
schemaNames=sys.argv[4]
profile=sys.argv[5]
toMail=[]
devopsMailList=[]
leadsMailList=[]
groupName=''

############################# Test Parameters ########################

# email='yogesh.patil@axiomtelecom.com'
# print('Email is ',email)
# profile="stage"
# permission='READ'
# dbClient='hyke'
# schemaNames='wms_dbo,wms_stage'

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

def checkIfEmailIsValid(email_id):
    if validate_email(email_id):
        print('Email format is valid')
        if ('@axiomtelecom.com' in email_id) or ('@tothenew.com' in email_id) or ('@intsof.com' in email_id):
            print('Email exists in org')
        else:
            print('Email is not part of org please correct it')
            exit(1)
    else:
        print('Please check your email id')
        exit(1)

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
        Name="/a2i/"+l_profile+"/ses/devopsMailList",
        WithDecryption=True
    )
    tmp_toMail=response['Parameter']['Value']
    for item in tmp_toMail.splitlines():
        devopsMailList.append(item)
    print('To devops email is ',devopsMailList)

    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/ses/leadsMailList",
        WithDecryption=True
    )

    tmp_toMail2=response['Parameter']['Value']
    for item in tmp_toMail2.splitlines():
        leadsMailList.append(item)
    print('To leads email is ',leadsMailList)

    toMail.append(email)

    return fromEmail,toMail

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def getGroupNameAsPerOrg(email_id,permission):
    if ('axiomtelecom' in email_id) and (permission == 'READ'):
        groupName='read_axiom'
    elif ('tothenew' in email_id) and (permission == 'READ'):
        groupName='read_ttn'
    elif ('intsof' in email_id) and (permission == 'READ'):
        groupName='read_intsoft'
    elif ('axiomtelecom' in email_id) and (permission == 'READWRITE'):
        groupName='read_write_axiom'
    elif ('tothenew' in email_id) and (permission == 'READWRITE'):
        groupName='read_write_ttn'
    elif ('intsof' in email_id) and (permission == 'READWRITE'):
        groupName='read_write_intsoft'
    return groupName

#####################

def checkIfUserIsAlreadyMemberOfGroup(email_id,groupName):
    print("Member extraction",groupName)
    userName=email_id.split('@')[0]
    userName=userName.split('.')[0]+'_'+userName.split('.')[1]
    with open('./'+profile+'/groupMemberView.txt') as f:
        datafile = f.readlines()
    for line in datafile:
        if groupName in line:
            print("group members are ",line)
            if (userName in line):
                print('User ',userName, ' is in group ',groupName)
            elif (userName.split('_')[0] in line):
                print('User ',userName, ' is in group ',groupName)
                userName=userName.split('_')[0]
            else:
                print('User ',userName, ' is not in group ',groupName)
                modifyGroupsToAddUser(userName,groupName)
    return userName

#####################

def modifyGroupsToAddUser(userName,groupName):
    base_path = str(Path(os.getcwd()))
    print('Updating modify_groups.txt file')
    file_to_update=str(base_path+'/modify_groups.txt')
    print(file_to_update)
    f = open(file_to_update, "a")
    f.write('\n')
    f.write(groupName+' '+userName)
    f.write('\n')
    f.close()
    print('Executing modify_groups.sh')
    base_path = str(Path(os.getcwd()))
    print('Executing modify_groups.sh')
    command_to_run=str('/bin/bash '+base_path+'/modify_groups.sh')
    print(command_to_run)
    os.system(command_to_run)

#####################

def grantAccess(groupName, permission, profile, schemaNames):
    base_path = str(Path(os.getcwd()))
    print('Executing access.sh')
    if dbClient == 'axiom':
        command_to_run=str('/bin/bash '+base_path+'/access.sh modifyIndividual@'+dbClient+' '+groupName+'@'+permission+' '+profile+' '+schemaNames)
        print(command_to_run)
        os.system(command_to_run)
    elif dbClient == 'hyke':
        command_to_run=str('/bin/bash '+base_path+'/access.sh modifyIndividual@'+dbClient+' '+groupName+'@'+permission+' '+profile+' '+schemaNames)
        print(command_to_run)
        os.system(command_to_run)
    else:
        print('Unrecognised db client ',dbClient)
        exit(1)

#####################

def sendNotification(l_data_to_send,profile):
    print('Sending mail to individual')
    #print('emailText is ',emailText)
    session = boto3.Session(profile_name=profile)
    client = session.client('ses')
    response = client.send_email(
        Source=fromEmail,
        Destination={
            'ToAddresses': toMail,
            'CcAddresses': devopsMailList
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

#####################

def sendNotificationToLeads(l_data_to_send,profile):
    print('Sending mail to leads')
    #print('emailText is ',emailText)
    session = boto3.Session(profile_name=profile)
    client = session.client('ses')
    response = client.send_email(
        Source=fromEmail,
        Destination={
            'ToAddresses': leadsMailList,
            'CcAddresses': devopsMailList
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
fromEmail,toMail=getSSMParameters(profile)
checkIfEmailIsValid(email)
groupName=getGroupNameAsPerOrg(email,permission)
print('The group name is ',groupName)
print('Email is ',email,' permission is ',permission,' schemaNames is ',schemaNames,' dbClient is ',dbClient)
userName=checkIfUserIsAlreadyMemberOfGroup(email,groupName)
grantAccess(groupName, permission, profile, schemaNames)

subject=profile+" | Redshift access request status "
user=email.split('.')[0].capitalize()
l_data_to_send='Hi '+user+', <br> <br> You have been assigned with the <b>'+permission+'</b> permission for <b>'+schemaNames+'</b> schema from <b>'+dbClient+'</b> database in <b>'+profile+'</b> environment. <br><br> Regards, <br> DevOps Team'
sendNotification(l_data_to_send,profile)
time.sleep(5)
l_data_to_send='Hi All, <br> <br> This is to notify you that <b>'+user+'</b> have granted himself <b>'+permission+'</b> permission for <b>'+schemaNames+'</b> schema from <b>'+dbClient+'</b> database in <b>'+profile+'</b> environment. <br><br> Regards, <br> DevOps Team'
sendNotificationToLeads(l_data_to_send,profile)

#############################
########## CleanUp ##########
#############################

print('Working on cleanup')
# os.remove('temp_access.sh')
# os.remove('temp_access_list.txt')
