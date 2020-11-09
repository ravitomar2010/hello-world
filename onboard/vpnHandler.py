#!/usr/bin/env python

#######################################################################
########################### Global Variables ##########################
#######################################################################

from selenium import webdriver
from selenium.webdriver.support.select import Select
from selenium.webdriver.common.by import By
import time
import random
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.chrome.options import Options
import platform

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

def getSSMParameters():
    print('Pulling SSM parameters from AWS')

#######################################################################
######################### Feature Function Code #######################
#######################################################################

def createSupportFiles():
    print('Creating supporting files')
    f = open("tmpUsersList.txt", "w")
    f.write("\n")
    f.close()

def browserInteraction():
    print('Working on base url')
    baseUrl="https://a2i-vpn.hyke.ai/login"
    driver.delete_all_cookies()
    driver.maximize_window()
    driver.get(baseUrl)
    driver.implicitly_wait(10)

def login():
    print('logging into system')
    driver.find_element_by_id("username").send_keys("vpn-admin")
    driver.find_element_by_id("password").send_keys("c5ufInliQxbv")
    driver.find_element_by_id("submit").click()
    # createSupportFiles()
    time.sleep(3)

def addUser():
    driver.find_element_by_link_text("Users").click()
    time.sleep(2)

    f = open("tmpUsersList.txt", "r")
    # print(f.read())
    for info in f.readlines():
        driver.refresh()
        time.sleep(2)
        driver.find_element_by_xpath("//button[text()='Add User']").click()
        time.sleep(2)
        print('user is: ',info)
        #name
        name=info.split('@')[0]
        print("Name is :",name)
        driver.find_element_by_xpath("//div[@class='modal-body']/div[1]/input").send_keys(name)


        #email
        email=info
        print('Email is : ',email)
        driver.find_element_by_xpath("//div[@class='modal-body']/div[4]/input").send_keys(email)

        #genrate pin
        pin=random.randint(111111,999999)
        print("Genrate the pin is :",pin)
        driver.find_element_by_xpath("//div[@class='modal-body']/div[5]/input").send_keys(pin)

        ####Select Organization
        element=driver.find_element_by_xpath("//div[@class='modal-body']/div[2]/select")
        ele=Select(element)

        if (email.find("intsof") >= 0):
            organization="intsoft"
            ele.select_by_index("1")
        elif (email.find("axiomtelecom") >= 0):
            organization="axiom"
            ele.select_by_index("0")
        else:
            (email.find("tothenew") >= 0)
            organization="ttn"
            ele.select_by_index("2")
        print("Oraganization value is :", organization)
    #   ele.select_by_value("intsoft")

        #click ADD button
        driver.find_element_by_xpath("//div[@class='modal-footer']/button[2]").click()
        findUser(name,email,pin)

def findUser(name,email,pin):
    userFoundFlag=0;

    while True :
        try:
            element=driver.find_element_by_link_text(name)
            ExtractUserDetail(name,email,pin)
            break;
        except NoSuchElementException:
            print("No element found")
            nextPageFlag=0;
            for path in driver.find_elements_by_xpath("//button[contains(text(),'Next Page')]"):
                #print('Path is:' ,path)

                if (path.is_displayed()):
                    #print('dine')
                    path.click();
                    nextPageFlag=1;
            if ( nextPageFlag == 1):
                print("Next button is clicked")
            else:
                print("None of the Next button is active")
                SendError()

def ExtractUserDetail(name,email,pin):
    driver.find_element_by_xpath("//*[contains(text(),'"+name+"')]/../../div[7]/a[3]").click()
    time.sleep(3)
    link=driver.find_element_by_xpath("//*[@class='otp-link form-group']/a").get_attribute("href")
    time.sleep(2)
    driver.find_element_by_xpath("//button[text()='Close']").click()
    finaloutput=str(email).strip()+' '+link+' '+str(pin)
    # print(finaloutput)
    # finaloutput='Test Script'
    fread = open("tmpUsersList.txt", "r")
    data = (fread.readlines());
    # print(data)
    fread.close()

    print('Replacing string')
    for user in data:
        print('user is ',user)
        if name in user:
            print('index is ',data.index(user))
            data[data.index(user)]=finaloutput + '\n'

    # print(data)

    with open('tmpUsersList.txt', 'w') as f:
        for item in data:
            f.write("%s\n" % item)

def SendError():
    print("I cant find User")

#######################################################################
############################# Main Function ###########################
#######################################################################

browserInteraction()
login()
addUser()
driver.close()
