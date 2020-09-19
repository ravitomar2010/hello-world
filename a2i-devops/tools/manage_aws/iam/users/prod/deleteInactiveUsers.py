import boto3
import datetime

################################### VARIABLE DECLARATION #######################################

from_email = ''
cc_email = ''
users = list()
profile='prod'

session = boto3.Session(profile_name=profile)

iam = session.client('iam')   #Fetch user details
ses = session.client('ses')   #Send email
ssm = session.client('ssm')   #Get/Delete ssm parameter

################################### GET SSM PARAMETER #######################################

def GetParameters() :
    global from_email, cc_email, users
    from_email = ssm.get_parameter( Name=f'/a2i/{profile}/ses/fromemail', WithDecryption=False)['Parameter']['Value']
    cc_email = ssm.get_parameter(Name=f'/a2i/{profile}/ses/devopsMailList', WithDecryption=False)['Parameter']['Value']
    cc_email = cc_email.replace('[\n','').replace('\n]','').split(',\n')
    try :
        users = ssm.get_parameter(Name=f'/a2i/{profile}/iam/users/inactiveUsers',WithDecryption=True)['Parameter']['Value'].split(',')
    except :
        print('No users with warning')
        exit()


################################### SEND NOTIFICATION TO USER #######################################

def SendNotification(user,last_activity):
    #extracting user's name
    name = user.split('.')[0]
    if len(name) <= 1 :
        name = user.split('@')[0]

    if last_activity == -1 :
        message=f'<p>Hello {name},</p> \
                <p>This is to notify you that your <b>A2i {profile} AWS account</b> is being deleted due to inactivity.\
                <br><br> \
                Please reach out to devops in case of any concern.\
                <br><br>Regards<br>DevOps team</p>'
    else :
        message=f'<p>Hello {name},</p> \
                <p>This is to notify you that your <b>A2i {profile} AWS account</b> is being deleted due to inactivity from {last_activity} days.\
                <br><br> \
                Please reach out to devops in case of any concern.\
                <br><br>Regards<br>DevOps team</p>'

    subject=f'Deleting A2i | {profile} | AWS account'
    response = ses.send_email(
        Source=from_email,
        Destination={ 'ToAddresses': [user], 'CcAddresses': cc_email},
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

################################### DELETE IAM USER #######################################

def DeleteIAMUser(user):
    #deleting user's login profile
    try: 
        iam.delete_login_profile( UserName=user)
    except Exception:
        pass

    #deleting access keys
    access_keys_metadata = iam.list_access_keys(UserName=user)['AccessKeyMetadata']
    for metadata in access_keys_metadata:
        iam.delete_access_key( UserName=user, AccessKeyId=metadata['AccessKeyId'])

    #delete signing certificates
    signing_certificates= iam.list_signing_certificates(UserName=user)['Certificates']
    for certificate in signing_certificates :
        iam.delete_signing_certificate(UserName=user, CertificateId=certificate['CertificateId'])

    #delete ssh public key
    ssh_public_keys = iam.list_ssh_public_keys(UserName=user)['SSHPublicKeys']
    for ssh_public_key in ssh_public_keys:
        iam.delete_ssh_public_key(UserName=user, SSHPublicKeyId=ssh_public_key['SSHPublicKeyId'])

    #delete git credentials
    service_specific_credentials = iam.list_service_specific_credentials(UserName=user)['ServiceSpecificCredentials']
    for service_specific_credential in service_specific_credentials:
        iam.delete_service_specific_credential(UserName=user, ServiceSpecificCredentialId=service_specific_credential['ServiceSpecificCredentialId'])

    #deactivating Multi-factor authentication
    # mfa_devices = iam.list_mfa_devices(UserName=user)['MFADevices']
    # for mfa_device in mfa_devices:
    #     iam.deactivate_mfa_device(UserName=user, SerialNumber=mfa_device['SerialNumber'])

    #delete mfa device
    # virtual_mfa_devices = iam.list_virtual_mfa_devices(AssignmentStatus='Unassigned')['VirtualMFADevices']
    # for virtual_mfa_device in virtual_mfa_devices:
    #     iam.delete_virtual_mfa_device(SerialNumber=virtual_mfa_device['SerialNumber'])

    #delete user policies
    user_policies = iam.list_user_policies(UserName=user)['PolicyNames']
    for user_policy in user_policies:
        iam.delete_user_policy(UserName=user, PolicyName=user_policy)

    #delete Attached managed policies
    attached_user_policies = iam.list_attached_user_policies(UserName=user)['AttachedPolicies']
    for attached_user_policy in attached_user_policies:
        iam.detach_user_policy(UserName=user, PolicyArn=attached_user_policy['PolicyArn'])

    #Remove user from groups
    groups_for_user = iam.list_groups_for_user(UserName=user)['Groups']
    for group_for_user in groups_for_user:
        iam.remove_user_from_group(UserName=user, GroupName=group_for_user['GroupName'])

    response=iam.delete_user(UserName=user)
    print(response)

################################### FETCH USERS LAST ACTIVITY #######################################

def FetchUsersLastActivity():

    for user in users :

        ################################### CONSOLE ACCESS #######################################

        #Variable to hold inactivity days for console access. Initially set last console access to None(-1)
        last_console_access = -1

        #Continue with loop if user doesn't exist
        try :
            user_info = iam.get_user(UserName=user)
        except Exception :
            print(f'{user} doesn\'t exist')
            continue

        password_last_used=user_info['User'].get('PasswordLastUsed')

        if password_last_used != None :
            last_console_access=(datetime.datetime.now(password_last_used.tzinfo) - password_last_used).days

        ################################### PROGRAMATIC ACCESS  #######################################

        #Variable to hold inactivity days for programatic access. Initially set to None (-1)
        last_programatic_access = -1
        #It'll store inactivity days for all access keys as list
        access_keys_inactivity_days_list=list()

        #Get current user's access keys metadata. Metadata holds access key id which is used to extract when the key was last used
        access_keys_metadata = iam.list_access_keys(UserName=user)['AccessKeyMetadata']

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

        if last_activity > 5 or last_activity == -1:
            print(f"Sending email to {user}")
            SendNotification(user,last_activity)

            print(f"Deleting the iam user: {user}")
            DeleteIAMUser(user)
            print("Deleted the user")

################################### DELETE SSM PARAMETER #######################################

def DeleteSsmParameter():
    print("Deleting SSM Parameter")
    ssm.delete_parameter( Name = f"/a2i/{profile}/iam/users/inactiveUsers")

################################### MAIN CODE #######################################

GetParameters()
FetchUsersLastActivity()
DeleteSsmParameter()