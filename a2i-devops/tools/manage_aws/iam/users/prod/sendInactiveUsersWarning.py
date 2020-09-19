import boto3
import datetime
import re

################################### VARIABLE DECLARATION #######################################

from_email=''
profile='prod'
all_users_list=list()
warning_users=""
cc_email = ''

session = boto3.Session(profile_name=profile)

iam = session.client('iam')   #Fetch all users
ses = session.client('ses')   #Send warning email
ssm = session.client('ssm')   #Create ssm parameter

################################### GET PARAMETER ###############################################

def GetParameter() :
    global from_email, cc_email
    from_email = ssm.get_parameter( Name=f'/a2i/{profile}/ses/fromemail', WithDecryption=False)['Parameter']['Value']
    cc_email = ssm.get_parameter(Name=f'/a2i/{profile}/ses/devopsMailList', WithDecryption=False)['Parameter']['Value']
    cc_email = cc_email.replace('[\n','').replace('\n]','').split(',\n')

################################### CHECK FOR VALID EMAIL ADDRESS  ###############################################

def IsEmail(username) :
    regex = r'^[a-z0-9]+[\._]?[a-z0-9]+[@]\w+[.]\w{2,3}$'
    if(re.search(regex,username)):
        return True
    else:
        return False

################################### SEND EMAIL ###############################################

def SendNotification(username,last_activity) :
    #extracting user's name
    user = username.split('.')[0]
    if len(user) <=1 :
        user = username.split('@')[0]

    if last_activity == -1:
        message=f'<p>Hello {user},</p> \
                <p>This is to notify that you haven\'t done any activity from your <b>A2i {profile} AWS account</b>.\
                If you do not access your account in next 5 days, it\'ll be deleted. <br><br> \
                Please reach out to devops in case of any concern.\
                <br><br>Regards<br>DevOps team</p>'
    else :
        message=f'<p>Hello {user},</p> \
                <p>This is to notify that you haven\'t done any activity from your <b>A2i {profile} AWS account</b> from {last_activity} days.\
                If you do not access your account in next 5 days, it\'ll be deleted. <br><br> \
                Please reach out to devops in case of any concern.\
                <br><br>Regards<br>DevOps team</p>'
                
    subject=f'Inactive A2i | {profile} |AWS account'
    ses.send_email(
        Source=from_email,
        Destination={ 'ToAddresses': [username], 'CcAddresses': cc_email },
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
    print(f"Email sent to {username}")


################################### FETCH ALL USERS #######################################

def FetchAllUsers() :
    global all_users_list, warning_users

    #Fetch all users
    all_users_list=iam.list_users()['Users']

    ################################### FOR EACH USER #######################################

    for user in all_users_list :

        username = user['UserName']

        ################################### CONSOLE ACCESS #######################################

        #Variable to hold inactivity days for console access. Initially last console access is set to None(-1)
        last_console_access = -1
        #Get password last used date from user info
        password_last_used=user.get('PasswordLastUsed')

        if password_last_used != None :
            #get password last used in days
            last_console_access=(datetime.datetime.now(password_last_used.tzinfo) - password_last_used).days

        ################################### PROGRAMATIC ACCESS  #######################################

        #Variable to hold inactivity days for programatic access. Initially set to None (-1)
        last_programatic_access = -1
        #It'll store inactivity days for all access keys as list
        access_keys_inactivity_days_list=list()

        #Get current user's access keys metadata. Metadata holds access key id which is used to extract when the key was last used
        access_keys_metadata = iam.list_access_keys(UserName=username)['AccessKeyMetadata']

        #for each access key
        for metadata in access_keys_metadata:

            access_key_id = metadata['AccessKeyId']
            access_key_last_used_date = iam.get_access_key_last_used(AccessKeyId=access_key_id)['AccessKeyLastUsed'].get('LastUsedDate')

            ################################ Finding days for latest access key used  ###########################

            if access_key_last_used_date != None :
                    access_keys_inactivity_days_list.append((datetime.datetime.now(access_key_last_used_date.tzinfo) - access_key_last_used_date).days)
                    last_programatic_access = min(access_keys_inactivity_days_list)

        if last_console_access == -1 and last_programatic_access == -1 :
            last_activity = -1
        elif last_console_access == -1 and last_programatic_access > -1 :
            last_activity = last_programatic_access
        elif last_programatic_access == -1 and last_console_access > -1 :
            last_activity=last_console_access
        else :
            last_activity = min(last_programatic_access,last_console_access)

        if IsEmail(username) and (last_activity > 90 or last_activity == -1):
            warning_users += f'{username},'
            print(f"Sending warning email to {username}")
            SendNotification(username,last_activity)

def CreateSsmParameter() :
    global warning_users
    #Creating SSM Parameter
    if len(warning_users) > 0 :
        #removing trailing comma
        warning_users=warning_users[:-1]
        ssm.put_parameter(
            Name = f"/a2i/{profile}/iam/users/inactiveUsers",
            Description = 'Holds usernames for inactive AWS accounts',
            Value = warning_users,
            Type = 'String',
            Overwrite = True,
            Tier = 'Standard',
            DataType = 'text'
        )
        print("SSM Paramter created")


################################ MAIN CODE ###########################

GetParameter()
FetchAllUsers()
CreateSsmParameter()