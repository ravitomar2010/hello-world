import os
import boto3
import psycopg2
import pandas as pd
from pathlib import Path
import subprocess


#######################################################################
########################### Global Variables ##########################
#######################################################################

profile=''
dbClient='axiom'
# username="axiom_stage"
# Port="5439"
# Host="axiom-prod-dwh.hyke.ai"
# secretName="/a2i/infra/redshift_prod/rootpassword"

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

def getSSMParametersOld(l_profile):
    print("Fetching parameters from SSM for ",l_profile, " account")
    session = boto3.Session(profile_name=l_profile)
    client = session.client('ssm')

    print('Fetching Hostname')
    hostName = client.get_parameter(
        Name="/a2i/"+l_profile+"/redshift/host",
        WithDecryption=True
    )['Parameter']['Value']

    #hostName=response['Parameter']['Value']

    print('Fetching portname')
    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/redshift/port",
        WithDecryption=True
    )
    portNo=response['Parameter']['Value']

    print('Fetching dbClient')
    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/redshift/db/"+dbClient,
        WithDecryption=True
    )
    dbName=response['Parameter']['Value']

    print('Fetching master password ')
    response = client.get_parameter(
        Name="/a2i/infra/redshift_"+l_profile+"/rootpassword",
        WithDecryption=True
    )
    redshiftPassword=response['Parameter']['Value']

    print('Fetching account id ')
    accountID = client.get_parameter(
        Name="/a2i/"+l_profile+"/accountid",
        WithDecryption=True
    )
    accountID=response['Parameter']['Value']

    print('Fetching username ')
    if l_profile == 'stage':
        redshiftUserName="axiom_rnd"
    else:
        redshiftUserName="axiom_stage"

    return hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID

def getSSMParameters(l_profile):
    print("Fetching parameters from SSM for ",l_profile, " account")
    session = boto3.Session(profile_name=l_profile)
    client = session.client('ssm')

    print('Fetching Hostname')
    hostName = client.get_parameter(Name="/a2i/"+l_profile+"/redshift/host", WithDecryption=True)['Parameter']['Value']

    print('Fetching portname')
    portNo = client.get_parameter(Name="/a2i/"+l_profile+"/redshift/port",WithDecryption=True)['Parameter']['Value']

    print('Fetching dbName')
    dbName = client.get_parameter(Name="/a2i/"+l_profile+"/redshift/db/"+dbClient,WithDecryption=True)['Parameter']['Value']

    print('Fetching master password ')
    redshiftPassword = client.get_parameter(Name="/a2i/infra/redshift_"+l_profile+"/rootpassword",WithDecryption=True)['Parameter']['Value']

    print('Fetching account id ')
    accountID = client.get_parameter(Name="/a2i/"+l_profile+"/accountid",WithDecryption=True)['Parameter']['Value']

    print('Fetching username ')
    if l_profile == 'stage':
        redshiftUserName="axiom_rnd"
    else:
        redshiftUserName="axiom_stage"

    return hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def getTableListforAxiom(hostName, portNo, dbName, redshiftUserName, redshiftPassword):
    dbName="axiom_stage"
    sql='select "database", "schema", "table","size" from SVV_TABLE_INFO where "table" not like \'%s3%\' order by size desc'
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["database","schemaname", "tablename", "size"]
    data = pd.DataFrame(res, columns=header_list)

    # data['DataBase']='axiom_stage';
    # cols = data.columns.tolist()
    # cols = cols[-1:] + cols[:-1]
    # data = data[cols]
    # print(data)
    # print("Started",SecretKey)
    return conn,data

def getTableListforHyke(hostName, portNo, dbName, redshiftUserName, redshiftPassword):
    dbName="hyke"
    sql='select "database", "schema", "table","size" from SVV_TABLE_INFO where "table" not like \'%s3%\' order by size desc'
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["database","schemaname", "tablename", "size"]

    data = pd.DataFrame(res, columns=header_list)
    # data['DataBase']='hyke';
    # cols = data.columns.tolist()
    # cols = cols[-1:] + cols[:-1]
    # data = data[cols]
    # print(data)
    # print("Started",SecretKey)
    return conn,data

def sendEmailToDevelopers():
    print('Sending email')
    #python3 sendEmailUnusedTables.py
    #subprocess.call("sendEmailUnusedTables.py", shell=True)
    import sendEmailJunkTables


#######################################################################
############################# Main Function ###########################
#######################################################################

print('Setting profile to work ')
profile=setProfile(profile)

hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile)

print('Fetching data for axiom_stage ')
cnn,tableList=getTableListforAxiom(hostName, portNo, dbName, redshiftUserName, redshiftPassword);
print('Filtering results data for axiom_stage ')
f_tables1=(tableList[tableList["tablename"].str.contains("test|sample|bkp|copy|backup|temp|tmp") | tableList["tablename"].str.contains("0|1|2|3|4|5|6|7|8|9")])

print('Fetching data for hyke ')

cnn,tableList=getTableListforHyke(hostName, portNo, dbName, redshiftUserName, redshiftPassword);

print('Filtering results data for hyke ')

f_tables2=(tableList[tableList["tablename"].str.contains("test|sample|bkp|copy|backup|temp|tmp") | tableList["tablename"].str.contains("0|1|2|3|4|5|6|7|8|9")])

print('Preparing final files')
final_tables = pd.concat([f_tables1, f_tables2])
#total_size = final_tables.size.sum();
total_size = sum(final_tables['size'])
final_tables=final_tables.sort_values(by=['size'], ascending=False)
final_tables.to_csv("tmp_junk_tables.csv",index=False)

sendEmailToDevelopers()

#############################
########## CleanUp ##########
#############################

print("Working on CleanUp")
os.remove("./tmp_junk_tables.csv")
