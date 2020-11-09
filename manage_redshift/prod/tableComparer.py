#!/usr/bin/env python

import os
import boto3
import psycopg2
import pandas as pd
from pathlib import Path
import sys
from tabulate import tabulate

#######################################################################
########################### Global Variables ##########################
#######################################################################

hostName=''
portNo=''
dbName=''
redshiftPassword=''
accountID=''
redshiftUserName=''
fromEmail=""
toMail=[]
subject=''

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

def getEmailSSMParameters(l_profile):
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
    # print('To email is ',toMail)
    #toMail.append('yogesh.patil@axiomtelecom.com')
    return fromEmail,toMail

def sendMail(l_data_to_send, l_profile):
    print('Sending mail')
    #print('emailText is ',emailText)
    subject='Redshift table inconsistency in prod and stage environment'
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


def schemaValidator():

    ############################ Production extraction ####################

    profile='prod'
    dbClient='axiom'
    hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile,dbClient)

    schemaNameSQL="select nspname from pg_namespace where nspname not like '%pg_%' and nspname != 'public' and nspname != 'information_schema' and nspname != 'admin' order by 1"
    tableNameSQL="select '"+dbClient+"' || '.' || schemaname || '.' || tablename AS tablelist from pg_tables where schemaname not like '%pg_%' and schemaname not like '%public%' and schemaname not like '%information%' order by tablelist"

    print('Fetching schema list from database')

    prodSchemaListAxiom=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,schemaNameSQL)
    prodTableListAxiom=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,tableNameSQL)

    dbClient='hyke'
    hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile,dbClient)
    tableNameSQL="select '"+dbClient+"' || '.' || schemaname || '.' || tablename AS tablelist from pg_tables where schemaname not like '%pg_%' and schemaname not like '%public%' and schemaname not like '%information%' order by tablelist"
    prodSchemaListHyke=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,schemaNameSQL)
    prodTableListHyke=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,tableNameSQL)

    ############################ Stage extraction #########################

    profile='stage'
    dbClient='axiom'
    hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile,dbClient)

    schemaNameSQL="select nspname from pg_namespace where nspname not like '%pg_%' and nspname != 'public' and nspname != 'information_schema' and nspname != 'admin' order by 1"
    tableNameSQL="select '"+dbClient+"' || '.' || schemaname || '.' || tablename AS tablelist from pg_tables where schemaname not like '%pg_%' and schemaname not like '%public%' and schemaname not like '%information%' order by tablelist"

    print('Fetching schema list from database')

    stageSchemaListAxiom=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,schemaNameSQL)
    stageTableListAxiom=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,tableNameSQL)

def tableValidator():

    dbClient='hyke'
    hostName, portNo, dbName, redshiftUserName, redshiftPassword, accountID=getSSMParameters(profile,dbClient)
    tableNameSQL="select '"+dbClient+"' || '.' || schemaname || '.' || tablename AS tablelist from pg_tables where schemaname not like '%pg_%' and schemaname not like '%public%' and schemaname not like '%information%' order by tablelist"
    stageSchemaListHyke=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,schemaNameSQL)
    stageTableListHyke=executeQueryAndGetResult(hostName,portNo,dbName,redshiftPassword,accountID,redshiftUserName,tableNameSQL)
    stageTableList= (stageTableListAxiom + stageTableListHyke)
    # prodToStageTableDiff.insert(0,'<b> There are '+str(len(prodToStageTableDiff))+' tables which are present in prod but are not there in stage </b>')

    prodToStageTableDiffAxiom=((set(prodTableListAxiom) - set(stageTableListAxiom)))
    prodToStageTableDiffAxiom = list(prodToStageTableDiffAxiom)
    prodToStageTableDiffAxiom.sort()
    prodToStageTableDiffHyke=((set(prodTableListHyke) - set(stageTableListHyke)))
    prodToStageTableDiffHyke = list(prodToStageTableDiffHyke)
    prodToStageTableDiffHyke.sort()


    stageToProdTableDiffAxiom=((set(stageTableListAxiom) - set(prodTableListAxiom)))
    stageToProdTableDiffAxiom = list(stageToProdTableDiffAxiom)
    stageToProdTableDiffAxiom.sort()
    stageToProdTableDiffHyke=((set(stageTableListHyke) - set(prodTableListHyke)))
    stageToProdTableDiffHyke = list(stageToProdTableDiffHyke)
    stageToProdTableDiffHyke.sort()


    from prettytable import PrettyTable
    pt = PrettyTable()
    pt.field_names = ['Env','Database','Schemaname','Tablename']

    for table in prodToStageTableDiffAxiom:
        if(len(table.split('.'))>=3):
            tempList=['prod   ']
            for item in table.split('.'):
                tempList.append(item)
            pt.add_row(tempList)

    for table in prodToStageTableDiffHyke:
        if(len(table.split('.'))>=3):
            tempList=['prod   ']
            for item in table.split('.'):
                tempList.append(item)
            pt.add_row(tempList)

    pt.sortby = "Schemaname"
    #print(pt)

    st = PrettyTable()
    st.field_names = ['Env','Database','Schemaname','Tablename']

    for table in stageToProdTableDiffAxiom:
        if(len(table.split('.'))>=3):
            tempList=['stage   ']
            for item in table.split('.'):
                tempList.append(item)
            st.add_row(tempList)

    for table in stageToProdTableDiffHyke:
        if(len(table.split('.'))>=3):
            tempList=['stage   ']
            for item in table.split('.'):
                tempList.append(item)
            st.add_row(tempList)

    st.sortby = "Schemaname"
    #print(st)

    finalString='<!DOCTYPE html> <html> <body> Hi All,'+"<br><br>"+'<b> There are '+ str(len(prodToStageTableDiffAxiom)+len(prodToStageTableDiffHyke)) +' tables that are present in prod but are not there in stage. <br> Similiarly there are '+ str(len(stageToProdTableDiffAxiom)+len(stageToProdTableDiffHyke)) +' tables which are present in stage but are not the prod. <br><br> Following is a list of tables which are only present in prod </b><br><br>'+ pt.get_html_string() +' <br> <br> <b> Following is a list of tables which are only present in stage </b><br><br>'+ st.get_html_string() +'</body> </html>'

    return finalString

#######################################################################
############################# Main Function ###########################
#######################################################################

profile='prod'
fromEmail,toMail=getEmailSSMParameters(profile)
data_to_send=tableValidator()
sendMail(data_to_send, 'prod')

#######################################################################
############################### Cleanup ###############################
#######################################################################

echo 'Working on cleanup'
