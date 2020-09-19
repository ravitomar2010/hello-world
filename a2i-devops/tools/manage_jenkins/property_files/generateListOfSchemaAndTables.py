#!/usr/bin/env python
import os
import boto3
import psycopg2
import pandas as pd
from pathlib import Path
import sys

#######################################################################
########################### Global Variables ##########################
#######################################################################


profile=sys.argv[1]
#profile='prod'
dbClient=sys.argv[2]
#client='axiom'
hostName=''
portNo=''
dbName=''
redshiftPassword=''
accountID=''
redshiftUserName=''
baseDir='/data/extralibs/redshift'
#baseDir='./'

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

def getSSMParameters(l_profile,dbClient):
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

def executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,sql):
    print('Executing query ')
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    res=queryResultParser(res)
    return res

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

def createTextFile(result,filename):

    file_path=''
    file_name=''
    if '/' in filename:
        tmp_path=filename.split('/')
        for i in range(0,(len(tmp_path))):
            if (i==0):
                file_path=tmp_path[i]
            elif (i==(len(tmp_path)-1)):
                filename=tmp_path[i]
            else:
                file_path=file_path+'/'+tmp_path[i]

    print('Creating supporting directories')
    Path(file_path).mkdir(parents=True, exist_ok=True)
    f = open((file_path+'/'+filename), "w")

    for i in range(0,len(result)):
        #print(result[i])
        f.write((result[i]))
        if (i < (len(result)-1)):
            f.write('\n')

    f.close()

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def executeQueryAndGetTableList(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,sql):
    print('Executing query ')
    conn = psycopg2.connect(dbname=dbName, user=redshiftUserName, password=redshiftPassword, port=portNo, host=hostName)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    #res=queryResultParser(res)
    header_list = ["schemaname", "tablename"]
    data = pd.DataFrame(res, columns=header_list)
    return data


def createTableTextFile(result,filename):

    file_path=''
    file_name=''
    if '/' in filename:
        tmp_path=filename.split('/')
        for i in range(0,(len(tmp_path))):
            if (i==0):
                file_path=tmp_path[i]
            elif (i==(len(tmp_path)-1)):
                filename=tmp_path[i]
            else:
                file_path=file_path+'/'+tmp_path[i]

    #print('Creating supporting directories  ')
    Path(file_path).mkdir(parents=True, exist_ok=True)
    f = open((file_path+'/'+filename), "w")

    f.write((result))

    f.close()

#######################################################################
############################# Main Function ###########################
#######################################################################

#profile=setProfile(profile)

hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile,dbClient)

schemaNameSQL="select nspname from pg_namespace where nspname not like '%pg_%' and nspname != 'public' and nspname != 'information_schema' and nspname != 'admin' order by 1"

print('Fetching schema list from database')

result=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,schemaNameSQL)

filename=baseDir+'/'+profile+'/'+dbClient+'-schemaList.txt'

print('creating schema list files')

createTextFile(result,filename)

print('Fetching table list from database')
tableNameSQL="select schemaname, tablename from pg_tables where schemaname!='public' and schemaname!='pg_catalog' and schemaname!='information_schema' order by tablename"

result=executeQueryAndGetTableList(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,tableNameSQL)

#result.style.set_properties(**{'text-align': 'right'})
print('creating table list files')

for schema in result.schemaname.unique():
    tableListToSave = (result[result.schemaname==schema].tablename.to_string(index=False))
    tableListToSave=(tableListToSave.replace(' ',''))
    tmpFilename =baseDir+'/'+profile+'/'+dbClient+'/'+schema+'/tableList.txt'
    createTableTextFile(tableListToSave,tmpFilename)

#######################################################################
############################# Clean - up  #############################
#######################################################################

print ('Working on cleanup ')

print ('Done ...!!')
