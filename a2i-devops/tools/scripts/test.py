import boto3
import psycopg2
import os
import config
import metaData

connDict = config.connDict
envDict = connDict[os.environ['environment']]
environment = envDict['environment']
Host = envDict['Host']
bucketName = envDict['bucketName']
Port = envDict['Port']
schemaName=metaData.fetchSchemaName()
secretName = "batch_" + schemaName.lower()
DBName = "axiom_" + environment


def makeConn():
    client = boto3.client('ssm')
    ParameterList = []
    ParameterList.append(secretName)
    param = client.get_parameters(Names=ParameterList, WithDecryption=True)
    SecretKey = [secrets['Value'] for secrets in param['Parameters']][0]
    conn = psycopg2.connect(dbname=DBName, user=secretName, password=SecretKey, port=Port, host=Host)
    ParameterList.clear()
    return conn
