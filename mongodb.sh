#!/bin/bash

#Script to install and configure mongodb

#Set color coding
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"

#Set logging
LOG_FOLDER="/var/log/mongodb"
SCRIPT_NAME=(basename "$0" .sh)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p "$LOG_FOLDER"

#Structured logging function
log () {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a $LOG_FILE
}

#Check return code of the most recently executed foreground command
check_return_code() {
    local rcode="$1"
    local msg="$2"
    if [ "$rcode" -ne 0 ]; then
        log "$RError: $msg failed$N"
        exit 1
    else
        log "$G $msg success $N"
    fi
}

log "$Y Script Execution started at $(date)$N"

#Check user privilages
if [ $(id -u) -ne 0 ]; then
   log "$R Error: You do not have privilages to install the software $N"
    exit 1
else
    log "$G You have necessary permissions to install the software $N"
fi

#copy mongodb file to repos
cp mongodb.repo /etc/yum.repos.d/mongodb.repo
check_return-code $? "copy of mongodb file to repos"

## Idempotent installation check
if command -v mongod &>/dev/null; then
    log "$R mongodb is already installed. Skipping the installation $N"
else
    log "$Y installing mongod $N"
    dnf install mongodb-org -y 
    check_return-code $? "installation of mongodb"
fi

#Enable mongodb service
systemctl enable mongod


#Start mongodb service
systemctl start mongod

#Modify mongodb config file accept connection from all hosts
sed -i '/s/127.0.0.1/0.0.0.0/g' /etc/mongod.conf

#restart service
log "$Y restarting the service $N"
systemctl restart mongod
check_return-code $? "restart of mongodb service"

#check session statistics
log "$G check session statistics $N"
ss -nltpu


