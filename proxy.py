#!/usr/bin/python3

"""
created by :
Nityananda Gohain
School of Engineering, Tezpur University
27/10/17
Modified by Ericom for Ericom Shield
"""

"""
Three files will be modified
1) /etc/apt/apt.conf
2) /etc/environment
3) /etc/bash.bashrc
4) /etc/systemd/system/docker.service.d/http-proxy.conf
"""

# This files takes the location as input and writes the proxy authentication

import getpass  # for taking password input
import shutil  # for copying file
import sys
import os
import subprocess
from os import getuid

# run it as sudo
if getuid() != 0:
    print("Please run this program as Super user(sudo)\n")
    sys.exit()

apt_ = r'/etc/apt/apt.conf'
apt_backup = r'./.backup_proxy/apt.txt'
bash_ = r'/etc/bash.bashrc'
bash_backup = r'./.backup_proxy/bash.txt'
env_ = r'/etc/environment'
env_backup = r'./.backup_proxy/env.txt'
docker_ = r'/etc/systemd/system/docker.service.d/http-proxy.conf'
docker_backup = r'./.backup_proxy/docker.txt'
docker_path = r'/etc/systemd/system/docker.service.d'
docker_systemd_link = r'/etc/systemd/system/multi-user.target.wants/docker.service'
restore_script = r'/etc/bash.restore'

# This function directly writes to the apt.conf file
# Fist deletes the lines containning ::proxy 
def writeToApt(proxy, port, username, password, flag):
    # find and delete line containing ::proxy
    if os.path.exists(apt_):
        with open(apt_, "r+") as opened_file:
            lines = opened_file.readlines()
            opened_file.seek(0)  # moves the file pointer to the beginning
            for line in lines:
                if r"::proxy" not in line:
                    opened_file.write(line)
            opened_file.truncate()

    # writing starts
    if not flag:
        with open(apt_, "a+") as opened_file:
            opened_file.write('Acquire::http::proxy "{}";\n'.format(make_proxy_url_string(proxy, port, username, password)))
            opened_file.write('Acquire::https::proxy  "{}";\n'.format(make_proxy_url_string(proxy, port, username, password, 'https')))
            opened_file.write('Acquire::ftp::proxy  "{}";\n'.format(make_proxy_url_string(proxy, port, username, password, 'ftp')))
            opened_file.write('Acquire::socks::proxy  "{}";\n'.format(make_proxy_url_string(proxy, port, username, password, 'socks')))

    # if apt.conf is NULL, delete the file
    if os.path.exists(apt_):
        if os.path.getsize(apt_) == 0:
            os.remove(apt_)


# This function writes to the environment file
# Fist deletes the lines containng _proxy=, _PROXY=
def writeToEnv(proxy, port, username, password, exceptions, flag):
    # find and delete line containing _proxy=, _PROXY=
    if os.path.exists(env_):
        with open(env_, "r+") as opened_file:
            lines = opened_file.readlines()
            opened_file.seek(0)  # moves the file pointer to the beginning
            for line in lines:
                if r"_proxy=" not in line and r"_PROXY=" not in line:
                    opened_file.write(line)
            opened_file.truncate()

    # writing starts
    if not flag:
        with open(env_, "a+") as opened_file:
            opened_file.write('http_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password)))
            opened_file.write('https_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'https')))
            opened_file.write('ftp_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'ftp')))
            opened_file.write('socks_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'socks')))
            opened_file.write('HTTP_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password)))
            opened_file.write('HTTPS_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'https')))
            opened_file.write('FTP_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'ftp')))
            opened_file.write('SOCKS_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'socks')))
            if len(exceptions) > 0:
                opened_file.write('no_proxy="{}"\n'.format(exceptions))
                opened_file.write('NO_PROXY="{}"\n'.format(exceptions))


# This function will write to the bashcr file
# Fist deletes the lines containng _proxy=, _PROXY=
def writeToBashrc(proxy, port, username, password, exceptions, flag):
    # find and delete _proxy=, _PROXY=
    if os.path.exists(bash_):
        with open(bash_, "r+") as opened_file:
            lines = opened_file.readlines()
            opened_file.seek(0)
            for line in lines:
                if r"_proxy=" not in line and r"_PROXY=" not in line:
                    opened_file.write(line)
            opened_file.truncate()

    # writing starts
    if not flag:
        with open(bash_, "a+") as opened_file:
            opened_file.write('export http_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password)))
            opened_file.write('export https_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'https')))
            opened_file.write('export ftp_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'ftp')))
            opened_file.write('export socks_proxy="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'socks')))
            opened_file.write('export HTTP_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password)))
            opened_file.write('export HTTPS_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'https')))
            opened_file.write('export FTP_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'ftp')))
            opened_file.write('export SOCKS_PROXY="{}"\n'.format(make_proxy_url_string(proxy, port, username, password, 'socks')))
            if len(exceptions) > 0:
                opened_file.write('export no_proxy="{}"\n'.format(exceptions))
                opened_file.write('export NO_PROXY="{}"\n'.format(exceptions))

# This function will write to the bashcr file
# Fist deletes the file
def writeDockerServiceConfig(proxy, port, username, password, exceptions, flag):
    if os.path.exists(docker_):
        os.remove(docker_)

    if not os.path.exists(docker_path):
        os.makedirs(docker_path)

    # writing starts
    if not flag:
        with open(docker_, "w") as opened_file:
            opened_file.write("[Service]\n")
            http_url = make_proxy_url_string(proxy, port, username, password)
            https_url = make_proxy_url_string(proxy, port, username, password, 'https')
            conf_str = 'Environment="HTTP_PROXY={0}" "HTTPS_PROXY={1}"'.format(http_url, https_url)
            if len(exceptions) > 0:
                conf_str += ' "NO_PROXY={}"\n'.format(exceptions)
            else:
                conf_str += '\n'
            opened_file.write(conf_str)

    # If docker is installed, restart the service.
    if os.path.islink(docker_systemd_link):
        print("reload and restart docker....")
        subprocess.run("systemctl daemon-reload", shell=True)
        subprocess.run("systemctl restart docker", shell=True)


def set_proxy(flag):
    proxy, port, username, password, exceptions = "", "", "", "", ""
    if not flag:
        proxy = input("Enter proxy : ")
        port = input("Enter port : ")
        exceptions = input("Enter IPs separated by ',' for direct access : ")
        username = input("Enter username (if you need) : ")
        password = getpass.getpass("Enter password (if you need) : ")

        if username == '':
            username = None

        if password == '':
            password = None

    writeToApt(proxy, port, username, password, flag)
    writeToEnv(proxy, port, username, password, exceptions, flag)
    writeToBashrc(proxy, port, username, password, exceptions, flag)
    writeDockerServiceConfig(proxy, port, username, password, exceptions, flag)


def make_proxy_url_string(proxy, port, username=None, password=None, protocol='http'):
    if not username is None and not password is None:
        return "http://{0}:{1}@{2}:{3}".format(username, password.replace('$', '\$'), proxy, port)
    else:
        return "http://{0}:{1}".format(proxy, port)


def restore_default():
    if os.path.isdir("./.backup_proxy"):
        # copy from backup to main
        if os.path.exists(apt_backup):
            shutil.copy2(apt_backup, apt_)
        else:
            if os.path.exists(apt_):
                os.remove(apt_)
        if os.path.exists(env_backup):
            shutil.copy2(env_backup, env_)
        if os.path.exists(bash_backup):
            shutil.copy2(bash_backup, bash_)
        if os.path.exists(docker_backup):
            shutil.copy2(docker_backup, docker_)
        else:
            if os.path.exists(docker_):
                os.remove(docker_)
        if os.path.islink(docker_systemd_link):
            print("reload and restart docker....")
            subprocess.run("systemctl daemon-reload", shell=True)
            subprocess.run("systemctl restart docker", shell=True)
    else:
        print("No backup data...")
        sys.exit()

def backup_default():
    # create backup     if not present
    if not os.path.isdir("./.backup_proxy"):
        os.makedirs("./.backup_proxy")
        if os.path.exists(apt_):
            shutil.copy2(apt_, apt_backup)
        if os.path.exists(env_):
            shutil.copy2(env_, env_backup)
        if os.path.exists(bash_):
            shutil.copy2(bash_, bash_backup)
        if os.path.exists(docker_):
            shutil.copy2(docker_, docker_backup)

def ref_env():
    # Generate a script that reflects environment variables with shell currently in use
    with open(restore_script, "w") as opened_file:
        opened_file.write('#!/bin/bash\n')
        opened_file.write('\n')
        opened_file.write('# Once all delet\n')
        opened_file.write('unset http_proxy\n')
        opened_file.write('unset https_proxy\n')
        opened_file.write('unset ftp_proxy\n')
        opened_file.write('unset socks_proxy\n')
        opened_file.write('unset no_proxy\n')
        opened_file.write('unset HTTP_PROXY\n')
        opened_file.write('unset HTTPS_PROXY\n')
        opened_file.write('unset FTP_PROXY\n')
        opened_file.write('unset SOCKS_PROXY\n')
        opened_file.write('unset NO_PROXY\n')
        opened_file.write('\n')
        opened_file.write('# If it exists, reset the existing definition of env.\n')
        with open(env_, "r") as fileporinter:
            lines = fileporinter.readlines()
            for line in lines:
                if r"_proxy=" in line or r"_PROXY=" in line:
                    opened_file.write('export {}\n'.format(line))
        opened_file.write('\n')
        opened_file.write('# Re-execute bashrc to reflect the existing settings, if exists.\n')
        opened_file.write("source /etc/bash.bashrc\n")

def end_message(flag):
    if not flag:
        print("DONE!")
        print("Plese run the command '$ source /etc/bash.bashrc'.")
    else:
        print("DONE!")
        print("Plese run the command '$ source /etc/bash.restore'.")


if __name__ == "__main__":

    # choice
    print("----------------------------------------------------------------------------------------------------------------------")
    print(" If the './.backup_proxy' directory does not exist,the settings before execution are automatically saved as a backup.")
    print(" If the directory exists, it will not overwrite the backup.")
    print("----------------------------------------------------------------------------------------------------------------------")
    print("1:) Set Proxy")
    print("2:) Remove Proxy")
    print("3:) Restore Backup file")
    print("4:) Exit")
    choice = int(input("\nchoice (1/2/3/4) : "))

    if (choice == 1):
        backup_default()
        set_proxy(flag=0)
        end_message(flag=0)
    elif (choice == 2):
        backup_default()
        set_proxy(flag=1)
        ref_env()
        end_message(flag=1)
    elif (choice == 3):
        restore_default()
        ref_env()
        end_message(flag=1)
    else:
        sys.exit()


