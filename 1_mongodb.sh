#!/bin/bash
#Bash Script to install mongodb
set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/mongodb/"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p "$LOG_FOLDER"

#Recording events in a log file
log () {
    local msg=$1
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a "$LOG_FILE"
}

check_status () {
    local status=$1
    local msg=$2
    if [ $status -eq 0 ]; then
        log "${G}$msg :Successful${N}"
    else
        log "${R}$msg :Failed${N}"
        exit 1
    fi    
}

log "${Y}Checking user has privileges to install the software${N}"
if [ $(id -u) -ne 0 ]; then
   log "${R}Error: You do not have privileges to install the software${N}"
    exit 1
else
    log "${G}You have privileges to install the software. Proceeding with the installation${N}"
fi

log "${Y}Copying mongodb file to repos${N}"
cp "$SCRIPT_DIRECTORY"/mongo.repo /etc/yum.repos.d/
check_status $? "Copying"

## Idempotent installation check
if command -v mongod &>/dev/null; then
    log "${G}mongodb is already installed. Skipping the installation${N}"
else
    log "${Y}installing mongod${N}"
    dnf install mongodb-org -y 
    check_status $? "installation of mongodb"
fi

log "${Y}Enabling and starting the service${N}"
systemctl enable mongod
systemctl start mongod
check_status $? "Starting the Mongodb service"

log "${Y}Checking the service status, wait until it is active${N}"
while ! systemctl is-active --quiet mongod; do
    log "Waiting for service to be in active state"
    sleep 2
done
log "${G}Mongod service is now active${N}"

log "${Y}Modifying mongodb config file accept connection from all hosts${N}"
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf

log "${Y}Restarting the service${N}"
systemctl restart mongod

log "${Y}Displaying session statistics${N}"
sleep 2
ss -nltpu


