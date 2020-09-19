#!/usr/bin/env python
# coding: utf-8

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

options = Options()
# options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-gpu')
# browser = webdriver.Chrome(chrome_options=options)
driver = webdriver.Chrome("./chromedriver",options=options)

#######################################################################
############################# Generic Code ############################
#######################################################################

def browserinteraction():
    print('Working on base url')
    baseUrl="https://a2i-vpn.hyke.ai/login"
    driver.delete_all_cookies()
    # driver.maximize_window()
    driver.get(baseUrl)
    driver.implicitly_wait(10)

def login():
    print('logging into system')
    driver.find_element_by_id("username").send_keys("vpn-admin")
    driver.find_element_by_id("password").send_keys("c5ufInliQxbv")
    driver.find_element_by_id("submit").click()
    time.sleep(2)
    driver.find_element_by_link_text("Users").click()

def searchUser():
    #username="test.2@intsoft.com"
    print('Get username')

    f = open("users_list.txt", "r")
    username=f.readline()
    f.close()

    name=username.split('@')[0]
    print("Name is:", name)

    #Userfind
    userFoundFlag=0;
    time.sleep(2)

    print('Refreshing the window')
    driver.refresh()
    time.sleep(2)
    while True :
        try:
            element=driver.find_element_by_link_text(name)
            print("User is found")
            deleteUser(name)
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
                print(Error)
                break;

def deleteUser(name):
    print('Searching for supporting parameters for ',name)
    driver.find_element_by_xpath("//*[contains(text(),'"+name+"')]/../../div[1]").click()
    time.sleep(2)
    print('Click on delete selected')
    driver.find_element_by_xpath("//button[text()='Delete Selected']").click()
    time.sleep(2)
    print('Verifying user entries')
    temp_user=driver.find_element_by_xpath("//ul[@class='modal-user-list']/li").text
    print("User in dialog box is" ,temp_user)
    if (name == temp_user):
        print ('Found Valid User - Moving ahead')
        driver.find_element_by_xpath("//button[@class='btn btn-primary ok']").click()
        print('User ',name,' deleted successfully from VPN portal')
    else:
        print('User is not valid - Cancelling')
        driver.find_element_by_xpath("//button[@class='btn btn-default cancel']").click()
        print('User ',name,' can not be deleted from VPN portal')

#######################################################################
############################# Main Function ###########################
#######################################################################

browserinteraction()
login()
searchUser()