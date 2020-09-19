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


def queryResultParser(result):
    print('Parsing Results ')
    for item in result:
        if (len(item)==1):
            length=1
        else:
            length=len(item)
            break;

    tmpRes=[]

    if (length==1):
        for item in result:
            tmpRes.append(str(item).replace("'","").replace(',','').replace('(','').replace(')',''))
    else:
        for item in result:
            tmpRes.append(str(item).replace("'","").replace('(','').replace(')',''))
    return tmpRes

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def getTableListforAxiom(hostName, portNo, dbName, redshiftUserName, redshiftPassword):
    dbName="axiom_stage"
    sql='select schemaname +  \'.\' + tablename as tablelist from pg_tables where schemaname != \'pg_catalog\' and schemaname != \'information_schema\' and schemaname != \'public\' ;'
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    res=queryResultParser(res)
    res.sort()
    res = [element.lower() for element in res] ; res
    return res

def getTableListforHyke(hostName, portNo, dbName, redshiftUserName, redshiftPassword):
    dbName="hyke"
    sql='select schemaname +  \'.\' + tablename as tablelist from pg_tables where schemaname != \'pg_catalog\' and schemaname != \'information_schema\' and schemaname != \'public\'  '
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    res=queryResultParser(res)
    res.sort()
    #res.lower()
    res = [element.lower() for element in res] ; res
    return res

def getQueryLogs(hostName, portNo, dbName, redshiftUserName, redshiftPassword):
    dbName="axiom_stage"
    sql='select querytxt from stl_query where ( database = \'axiom_stage\' or database = \'hyke\' ) and label not like \'%maintenance%\' and label != \'metrics\' and label != \'health\' '
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    new_res=[]

    header_list = ["querytxt"]
    data = pd.DataFrame(res, columns=header_list)
    data=data['querytxt'].str.strip()
    data.to_csv("tmp_unused_tables_logs.csv",index=False)

    # Using readlines()
    file1 = open('tmp_unused_tables_logs.csv', 'r')
    Lines = file1.readlines()

    for line in Lines:
        new_res.append(line.lower().strip())

    return new_res

def sendEmailToDevelopers():
    print('Sending email')
    #python3 sendEmailUnusedTables.py
    #subprocess.call("sendEmailUnusedTables.py", shell=True)
    import sendEmailUnusedTables

def validator(tableList,logs):
    l_unusedTables=[]
    tablefound=0;
    for table in tableList:
        print('Checking for ',table)
        tablefound=0;
        for logEntry in logs:
            if table in logEntry:
                print('Found entry for ',table)
                tablefound=tablefound+1;
                break;
        if tablefound == 0:
            print('Adding ',table,' into the list of unused tables')
            l_unusedTables.append(table)

    return l_unusedTables

#######################################################################
############################# Main Function ###########################
#######################################################################

print('Setting profile to work ')
profile=setProfile(profile)

hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile)

print('Fetching data for axiom_stage ')
tableListAxiom=getTableListforAxiom(hostName, portNo, dbName, redshiftUserName, redshiftPassword);
# print(tableListAxiom)

print('Fetching data for hyke ')
tableListHyke=getTableListforHyke(hostName, portNo, dbName, redshiftUserName, redshiftPassword);
print(tableListHyke)
# for table in tableListHyke:
#     print(table)

print('Fetching Query logs from database')
logs=getQueryLogs(hostName, portNo, dbName, redshiftUserName, redshiftPassword);
# #print(logs);
#

tableList=(tableListAxiom+tableListHyke)

unusedTables=validator(tableList,logs)
print('Final List of Unused tables is ')
print(unusedTables)

f = open("unusedTables.csv", "w")
for table in unusedTables:
    f.write(table)
    f.write("\n")
f.close()

sendEmailToDevelopers()

#############################
########## CleanUp ##########
#############################

# print("Working on CleanUp")
# os.remove("./tmp_unused_tables.csv")
# os.remove("./tmp_unused_tables_logs.csv")
