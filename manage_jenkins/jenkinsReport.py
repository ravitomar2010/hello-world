#!/usr/bin/env python

import os
import sys
import requests
import traceback
from bs4 import BeautifulSoup
import boto3
import datetime
from selenium import webdriver
from selenium.webdriver.support.select import Select
from selenium.webdriver.common.by import By
import time
import random
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.chrome.options import Options
import platform

#######################################################################
########################### Global Variables ##########################
#######################################################################

profile='prod'
fromEmail=""
toMail=[]
devopsMailList=[]

options = Options()
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-gpu')
# browser = webdriver.Chrome(chrome_options=options)
print('Check and set chromedriver')
os=platform.platform()
print('OS type detected is ',os)
if 'Linux' in os:
    print('OS detected is of Linux type')
    driver = webdriver.Chrome("./chromedriver-linux",options=options)
else:
    print('OS detected is of mac type')
    driver = webdriver.Chrome("./chromedriver-mac",options=options)

#######################################################################
############################# Generic Code ############################
#######################################################################

def getSSMParameters(l_profile):
    print("Fetching parameters from SSM for ",l_profile, " account")
    session = boto3.Session(profile_name=l_profile)
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
    response = client.get_parameter(
        Name="/a2i/"+l_profile+"/ses/devopsMailList",
        WithDecryption=True
    )
    tmp_devopsMailList=response['Parameter']['Value']
    for item in tmp_devopsMailList.splitlines():
        devopsMailList.append(item)

    return fromEmail,toMail,devopsMailList


#######################################################################
######################### Feature Function Code #######################
#######################################################################

def getJenkinsPassword():
    print("Fetching jenkins password from SSM for jenkins-admin account")
    session = boto3.Session(profile_name='stage')
    client = session.client('ssm')
    response = client.get_parameter(
        Name="/a2i/infra/jenkins/adminpassword",
        WithDecryption=True
    )
    password=response['Parameter']['Value']

    return password

def createSupportFiles():
    print('Creating supporting files')
    f = open("tmpUsersList.txt", "w")
    f.write("\n")
    f.close()

def browserInteraction():
    print('Working on base url')
    baseUrl="http://jenkins-a2i.hyke.ai/login?from=%2F"
    driver.delete_all_cookies()
    driver.maximize_window()
    driver.get(baseUrl)
    driver.implicitly_wait(10)

def login():
    print('logging into system')
    jPassword=getJenkinsPassword()
    driver.find_element_by_id("j_username").send_keys("jenkins-admin")
    driver.find_element_by_name("j_password").send_keys(jPassword)
    driver.find_element_by_name("Submit").click()
    time.sleep(3)

def openView():
    print('Navigating to required View')
    viewURL='http://jenkins-a2i.hyke.ai/view/jobStatus/'
    driver.get(viewURL)
    time.sleep(3)


def extractDetails():
    print('Extracting details from view')
    tableData='<table BORDER=3 BORDERCOLOR=#0000FF BORDERCOLORLIGHT=#33CCFF BORDERCOLORDARK=#0000CC width= 80%>'

    soup = BeautifulSoup(driver.page_source, 'html.parser')

    tableData=tableData+'<tr><td><font face=Arial size=4>Job Name</font></td><td><font face=Arial size=4>Status</font></td><td><font face=Arial size=4>Details</font></td></tr>'

    print('Trying to get failed objects')

    failedObjects=soup.find_all("li", class_="failing basic project widget")

    for obj in failedObjects:
        print(obj.find("header").find("h2").find('a')["title"])
        tableData=tableData+'<tr><td><font face=Comic Sans MS size=3>'+obj.find("header").find("h2").find('a')["title"]+'</font></td><td><font face=Arial color=RED>FAILED</font></td><td><a href="http://jenkins-a2i.hyke.ai/'+obj.find("header").find("h2").find('a')["href"]+'">click me</a></td></tr>'

    print('Trying to get aborted objects')

    abortedObjects=soup.find_all("li", class_="aborted basic project widget")

    for obj in abortedObjects:
        print(obj.find("header").find("h2").find('a')["title"])
        tableData=tableData+'<tr><td><font face=Comic Sans MS size=3>'+obj.find("header").find("h2").find('a')["title"]+'</font></td><td><font face=Arial color=BROWN>ABORTED</font></td><td><a href="http://jenkins-a2i.hyke.ai/'+obj.find("header").find("h2").find('a')["href"]+'">click me</a></td></tr>'

    print('Trying to get unknown objects')

    unknownBasicObjects=soup.find_all("li", class_="unknown basic project widget")

    for obj in unknownBasicObjects:
        print(obj.find("header").find("h2").find('a')["title"])
        tableData=tableData+'<tr><td><font face=Comic Sans MS size=3>'+obj.find("header").find("h2").find('a')["title"]+'</font></td><td><font face=Arial color=ORANGE>UNKNOWN</font></td><td><a href="http://jenkins-a2i.hyke.ai/'+obj.find("header").find("h2").find('a')["href"]+'">click me</a></td></tr>'

    tableData=tableData+'</table>'
    return tableData

def sendNotification(tableData,fromEmail,toMail,devopsMailList):
    session = boto3.Session(profile_name='prod')
    client = session.client('ses','eu-west-1')
    response = client.list_verified_email_addresses()

    headerForHTML='<html> <body> <h4><p>Hi All</p> <p>Please find below list of jenkins jobs which has unstable behavior in last 24 hours. </h4> </p>';

    footerForHTML='<p><h4>Please reach out to devops in case of any issues.<br><br>Thanks and Regards,<br>DevOps Team</h4></p></body></html>'

    dataToSend=(headerForHTML+tableData+footerForHTML)
    # print(dataToSend)

    response = client.send_email(
        Source=fromEmail,
        Destination={
            'ToAddresses': toMail,
            'CcAddresses': devopsMailList
        },
        Message={
            'Subject': {
                'Data': 'A2i | Jenkins job report - '+datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                'Charset': 'UTF-8'
            },
            'Body': {
                    # 'Text': {
                    #     'Data': emailText,
                    #     'Charset': 'UTF-8'
                    # }
                    # ,
                    'Html': {
                        'Data': dataToSend ,
                        'Charset': 'UTF-8'
                    },
            }
        }
    )


def SendError():
    print("I cant find User")

#######################################################################
############################# Main Function ###########################
#######################################################################

browserInteraction()
login()
openView()
tableData=extractDetails()
fromEmail,toMail,devopsMailList=getSSMParameters('prod')
sendNotification(tableData,fromEmail,toMail,devopsMailList)
driver.close()
