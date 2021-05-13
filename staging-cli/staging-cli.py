#!/usr/bin/python3
import sys
import os.path
import os
import shutil
import re
import subprocess

BASE_PATH = os.getcwd()
HOSTNAMES_LIST_FILE = BASE_PATH + "/staging-hostnames-list.txt"
BUILD_HOSTS_FILE = BASE_PATH + "/hosts.staging"
DEFAULT_HOSTS_FILE = BASE_PATH + "/hosts.default"
STATIC_HOSTS_FILE = BASE_PATH + "/staging-static-config.txt"
DEBUG_FLAG = False

if os.path.isfile(HOSTNAMES_LIST_FILE):
    HOSTNAMES_LIST = []
    regPattern = re.compile("[^#]+(.*)")
    with open(HOSTNAMES_LIST_FILE, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if regPattern.match(line):
                HOSTNAMES_LIST.append(line.strip())

def checkRecord(item):
    edgekeyPattern = re.compile("(.*)\.(edgekey|edgesuite)\.net\.$")
    akadnsPattern = re.compile("(.*)\.globalredir\.akadns.net\.$")
    edgePattern = re.compile("(.*)\.akamaiedge\.net\.$")
    if edgekeyPattern.match(item):
        return 'IS_EDGEKEY'
    if akadnsPattern.match(item):
        return 'IS_AKADNS'
    if edgePattern.match(item):
        return 'IS_EDGE'

def usage():
    print("Usage: %s [ apply | build | init | clean | reset ]" % __file__)

def apply():
    print("Applying the built configuration ...")
    if os.path.isfile(STATIC_HOSTS_FILE):
        with open(STATIC_HOSTS_FILE, 'r') as fsrc:
            read_data = fsrc.read()
        with open("/etc/hosts", 'a') as fdst:
            if fdst.writable():
                fdst.write(read_data)
                print("Adding the static configuration into /etc/hosts")
            else:
                print("/etc/hosts is not writable! Are you running this as root?")
    if os.path.isfile(BUILD_HOSTS_FILE):
        with open(BUILD_HOSTS_FILE, 'r') as fsrc:
            read_data = fsrc.read()
        with open("/etc/hosts", 'a') as fdst:
            if fdst.writable():
                fdst.write(read_data)
                print("Adding the built hosts into /etc/hosts")
            else:
                print("/etc/hosts is not writable! Are you running this as root?")
    else:
        print("No configuration has been built yet, you might want to run '%s build' first" % __file__)
        quit()

def init():
    print("Initializing the staging-cli, saving the default hosts file ...")
    shutil.copyfile("/etc/hosts", DEFAULT_HOSTS_FILE)

def reset():
    print("Restoring the hosts file to the default state ...")
    if os.path.isfile(DEFAULT_HOSTS_FILE):
        shutil.copyfile(DEFAULT_HOSTS_FILE, "/etc/hosts")
    else:
        print("Default hosts file has not been saved yet. Please run '%s init' first" % __file__)
        quit()

def clean():
    with open(BUILD_HOSTS_FILE, 'w') as fdst:
        if fdst.writable():
            fdst.write("")
            print("Built hosts file was cleared.")
        else:
            print(BUILD_HOSTS_FILE + " is not writable!")

def build():
    print("Building the configuration ...")
    CNTR = 0
    ARR_LEN = len(HOSTNAMES_LIST)
    finalOutputList = []
    print("Found %d hostnames in the list" % ARR_LEN)
    for hostname in HOSTNAMES_LIST:
        CNTR += 1
        print("%d/%d | %s" % (CNTR, ARR_LEN, hostname), end="")
        digOutput = subprocess.run(["dig", hostname, "+short"], capture_output=True, shell=False, check=True)
        digOutputList = digOutput.stdout.decode("utf-8").split('\n')
        digOutputList.remove('')
        if DEBUG_FLAG:
            print("[DEBUG] " + str(digOutputList))
        mapOutput = list(map(checkRecord, digOutputList))
        if DEBUG_FLAG:
            print("[DEBUG] " + str(mapOutput))

        if 'IS_AKADNS' in mapOutput and 'IS_EDGE' in mapOutput:
            print(" | Akamai with Akadns", end="")
            edge = digOutputList[mapOutput.index('IS_EDGE')]
            edgeStaging = re.sub(r'(akamaiedge)\.net', r'\1-staging.net', edge)
        elif 'IS_EDGEKEY' in mapOutput:
            print(" | Akamai", end="")
            edgekey = digOutputList[mapOutput.index('IS_EDGEKEY')]
            edgeStaging = re.sub(r'(edgekey|edgesuite)\.net', r'\1-staging.net', edgekey)
        else:
            edgeStaging = None
            print(" | skipping", end="")

        if edgeStaging is not None:
            digStagingOutput = subprocess.run(["dig", edgeStaging, "+short"], capture_output=True, shell=False, check=True)
            digStagingOutputList = digStagingOutput.stdout.decode("utf-8").split('\n')
            digStagingOutputList.remove('')
            STAGING_IP_OUT = digStagingOutputList[-1]
            finalOutputList.append("%s\t%s" % (STAGING_IP_OUT, hostname))
            print(" | staging IP address: %s" % STAGING_IP_OUT, end="")

        print(" | done")

    with open(BUILD_HOSTS_FILE, 'a') as fdst:
        fdst.write('\n'.join(finalOutputList))
        fdst.write('\n')

if len(sys.argv) != 2:
    usage()
    quit()

if sys.argv[1] == "apply":
    reset()
    apply()

if sys.argv[1] == "clean":
    clean()

if sys.argv[1] == "init":
    init()
    clean()

if sys.argv[1] == "build":
    clean()
    build()

if sys.argv[1] == "reset":
    reset()
