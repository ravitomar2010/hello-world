import os
import boto3
import psycopg2
import pandas as pd

profileName="stage"
username="axiom_rnd"
Port="5439"
Host="axiom-rnd-dwh.hyke.ai"
secretName="/a2i/infra/redshift_stage/rootpassword"

def getTableListforRND():
    DBName="axiom_rnd"
    session = boto3.Session(profile_name=profileName)
    client = session.client('ssm')
    #client = boto3.client('ssm')
    ParameterList = []
    ParameterList.append(secretName)
    param = client.get_parameters(Names=ParameterList, WithDecryption=True)
    SecretKey = [secrets['Value'] for secrets in param['Parameters']][0]
    sql="select schemaname,tablename,tableowner from pg_tables where schemaname not like 'pg_catalog' and schemaname not like 'information_schema' and schemaname not like 'public'"
    conn = psycopg2.connect(dbname=DBName, user=username, password=SecretKey, port=Port, host=Host)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["schemaname", "tablename", "tableowner"]
    data = pd.DataFrame(res, columns=header_list)
    #print(data)
    #print("Started",SecretKey)
    return conn,data

def getTableListforHyke():
    DBName="hyke"
    session = boto3.Session(profile_name=profileName)
    client = session.client('ssm')
    #client = boto3.client('ssm')
    ParameterList = []
    ParameterList.append(secretName)
    param = client.get_parameters(Names=ParameterList, WithDecryption=True)
    SecretKey = [secrets['Value'] for secrets in param['Parameters']][0]
    sql="select schemaname,tablename,tableowner from pg_tables where schemaname not like 'pg_catalog' and schemaname not like 'information_schema' and schemaname not like 'public'"
    conn = psycopg2.connect(dbname=DBName, user=username, password=SecretKey, port=Port, host=Host)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["schemaname", "tablename", "tableowner"]
    data = pd.DataFrame(res, columns=header_list)
    #print(data)
    #print("Started",SecretKey)
    return conn,data

print("Initiation")

cnn,tableList=getTableListforRND();
#print(tableList)
f_table=(tableList[tableList["tablename"].str.contains("test|sample|bkp|copy") | tableList["tablename"].str.contains("0|1|2|3|4|5|6|7|8|9")])
# print(len(f_table))
# print(f_table)
f_table.to_csv("output.csv",index=False)

cnn,tableList=getTableListforHyke();
#print(tableList)
f_table2=(tableList[tableList["tablename"].str.contains("test|sample|bkp|copy") | tableList["tablename"].str.contains("0|1|2|3|4|5|6|7|8|9")])
# print(len(f_table))
# print(f_table)
f_table2.to_csv("output2.csv",index=False)
