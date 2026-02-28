#!/bin/bash

log "$G********Script to install and configure mongodb***********$N"

#Set color coding
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"

#Set logging
LOG_FOLDER="/var/log/mongodb"
SCRIPT_NAME=$(basename "$0" .sh)
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

log "$YScript Execution started at $(date)$N"

log "$YChecking user privilages to install the software$N"
if [ $(id -u) -ne 0 ]; then
   log "$R Error: You do not have privilages to install the software $N"
    exit 1
else
    log "$G You have necessary permissions to install the software $N"
fi

log "$Ycopying mongodb file to repos$N"
cp mongodb.repo /etc/yum.repos.d/mongodb.repo

## Idempotent installation check
if command -v mongod &>/dev/null; then
    log "$G mongodb is already installed. Skipping the installation $N"
else
    log "$Y installing mongod $N"
    dnf install mongodb-org -y 
    check_return_code $? "installation of mongodb"
fi

log "$Yenabling mongod service$N"
systemctl enable mongod

log "$Ystarting mongod service$N"
systemctl start mongod

log "$YModifying mongodb config file accept connection from all hosts$N"
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf

log "$Y restarting the service $N"
systemctl restart mongod

log "$Ycheck session statistics$N"
ss -nltpu


