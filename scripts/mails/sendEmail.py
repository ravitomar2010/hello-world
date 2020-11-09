import os, sys, boto3
from botocore.exceptions import ClientError
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile=sys.argv[1]
SENDER = ""
RECIPIENT = ""

#######################################################################
############################# Generic Code ############################
#######################################################################

def getSSMParameters(l_profile):
    fromEmail=''
    toMail=[]
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
        Name="/a2i/"+l_profile+"/ses/qa_report_to_mail",
        WithDecryption=True
    )
    tmp_toMail=response['Parameter']['Value']
    for item in tmp_toMail.splitlines():
        toMail.append(item)
    # print('To email is ',toMail)
    return fromEmail,toMail

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def prepareAttachment():
    print("Preparing attachment")

def mailSend(l_profile):

    # The subject line for the email.
    SUBJECT = "Test Report | "+l_profile

    # The full path to the file that will be attached to the email.
    ATTACHMENT = "./reports/report.html"

    # The email body for recipients with non-HTML email clients.
    BODY_TEXT = "Hi All,\r\nPlease see the attached report file for a test execution."

    # The HTML body of the email.
    BODY_HTML = """\
    <html>
    <head></head>
    <body>
    <h4>Hi All,</h4>
    <p>Please see the attached file for a test reports.</p>
    </body>
    </html>
    """

    # The character encoding for the email.
    CHARSET = "utf-8"

    # Create a new SES resource and specify a region.
    session = boto3.Session(profile_name=l_profile)
    client = session.client('ses')
    #client = boto3.client('ses',region_name=AWS_REGION)

    # Create a multipart/mixed parent container.
    msg = MIMEMultipart('mixed')
    # Add subject, from and to lines.
    msg['Subject'] = SUBJECT
    msg['From'] = SENDER
    if len(RECIPIENT) > 1:
        print('no of recepients are more than 1')
        tmpadd=''
        for count in range(0,len(RECIPIENT)):
            print(RECIPIENT[count])
            if count == 0:
                tmpadd=RECIPIENT[count]
            else:
                tmpadd=tmpadd+','+RECIPIENT[count]
        msg['To']=tmpadd
    else:
        msg['To'] = RECIPIENT[0]

    print('To is ',msg['To'])

    # Create a multipart/alternative child container.
    msg_body = MIMEMultipart('alternative')

    # Encode the text and HTML content and set the character encoding. This step is
    # necessary if you're sending a message with characters outside the ASCII range.
    textpart = MIMEText(BODY_TEXT.encode(CHARSET), 'plain', CHARSET)
    htmlpart = MIMEText(BODY_HTML.encode(CHARSET), 'html', CHARSET)

    # Add the text and HTML parts to the child container.
    msg_body.attach(textpart)
    msg_body.attach(htmlpart)

    # Define the attachment part and encode it using MIMEApplication.
    att = MIMEApplication(open(ATTACHMENT, 'rb').read())

    # Add a header to tell the email client to treat this part as an attachment,
    # and to give the attachment a name.
    att.add_header('Content-Disposition','attachment',filename=os.path.basename(ATTACHMENT))

    # Attach the multipart/alternative child container to the multipart/mixed
    # parent container.
    msg.attach(msg_body)

    # Add the attachment to the parent container.
    msg.attach(att)
    #print(msg)
    try:
        #Provide the contents of the email.
        response = client.send_raw_email(
            Source=SENDER,
            Destinations=#[
                RECIPIENT
            #]
            ,
            RawMessage={
                'Data':msg.as_string(),
            },
            #ConfigurationSetName=CONFIGURATION_SET
        )
    # Display an error if something goes wrong.
    except ClientError as e:
        print(e.response['Error']['Message'])
    else:
        print("Email sent! Message ID:"),
        print(response['MessageId'])

#######################################################################
############################# Main Function ###########################
#######################################################################

print('profile is',profile)
SENDER,RECIPIENT=getSSMParameters(profile)
#mailSend(profile)



#############################
########## CleanUp ##########
#############################
