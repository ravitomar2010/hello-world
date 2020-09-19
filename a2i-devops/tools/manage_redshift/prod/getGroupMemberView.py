#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import os
import boto3
import psycopg2
import pandas as pd


profileName="prod"
username="axiom_stage"
Port="5439"
Host="axiom-prod-dwh.hyke.ai"
secretName="/a2i/infra/redshift_prod/rootpassword"


def getUserListforRND():
    print("Getting users information")
    DBName="axiom_stage"
    session = boto3.Session(profile_name=profileName)
    client = session.client('ssm')
    #client = boto3.client('ssm')
    ParameterList = []
    ParameterList.append(secretName)
    param = client.get_parameters(Names=ParameterList, WithDecryption=True)
    SecretKey = [secrets['Value'] for secrets in param['Parameters']][0]
    sql="select usename, usesysid from pg_user;"
    conn = psycopg2.connect(dbname=DBName, user=username, password=SecretKey, port=Port, host=Host)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["username", "userid"]
    data = pd.DataFrame(res, columns=header_list)
    #print(data)
    #print("Started",SecretKey)
    return conn,data

def getGroupListforRND():
    print("Getting group information")
    DBName="axiom_stage"
    session = boto3.Session(profile_name=profileName)
    client = session.client('ssm')
    #client = boto3.client('ssm')
    ParameterList = []
    ParameterList.append(secretName)
    param = client.get_parameters(Names=ParameterList, WithDecryption=True)
    SecretKey = [secrets['Value'] for secrets in param['Parameters']][0]
    sql="select * from pg_group;"
    conn = psycopg2.connect(dbname=DBName, user=username, password=SecretKey, port=Port, host=Host)
    cur = conn.cursor();
    cur.execute(sql)
    res = cur.fetchall()
    header_list = ["groupname", "groupid", "grouplist"]
    data = pd.DataFrame(res, columns=header_list)
    #print(data)
    #print("Started",SecretKey)
    return conn,data

# gList=groupList
# uList=userList
# fList=[]
#print(type(gList));
def createUserGroupMapping(uList, gList):
    print("Preparing final list")
    f=open("groupMemberView.txt","w+")
    for ind in gList.index:
         #print(gList['groupname'][ind], gList['grouplist'][ind])
         tempGroupMemberLists=(gList['grouplist'][ind])
         tempGroupMemberListsToWrite=[]
         #print("Group name is ",gList['groupname'][ind]," and members are ",tempGroupMemberLists)
         if tempGroupMemberLists == None:
            #print("Group ",gList['groupname'][ind]," is empty")
            f.write(gList['groupname'][ind])
            f.write(" ")
            f.write(" None ")
            f.write("\n")
         else:
            f.write(gList['groupname'][ind])
            f.write(" ")
            #print("Group ",gList['groupname'][ind])
            for member in tempGroupMemberLists:
                #print(member)
                for ind in uList.index:
                    #print(uList['username'][ind], uList['userid'][ind])
                    if uList['userid'][ind] == member:
                        #print(uList['username'][ind])
                        tempGroupMemberListsToWrite.append(uList['username'][ind])
                        #print(tempGroupMemberListsToWrite)
            f.write(', '.join(tempGroupMemberListsToWrite))
            #f.write(str(tempGroupMemberListsToWrite))
            f.write("\n")

    f.close()
    #sort "groupMemberView.txt"
    shopping = open('groupMemberView.txt')
    lines = shopping.readlines()
    lines.sort()
    f=open("groupMemberView.txt","w+")
    for item in lines:
        f.write(item)
    f.close()

###############################################################################
################################ Initiation ###################################
###############################################################################

print("Initiation")
cnn,userList=getUserListforRND();
cnn,groupList=getGroupListforRND();
createUserGroupMapping(userList,groupList);
print("Done !!!")
