#!/bin/bash
#Script to install cart micro service
set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/cart/"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p "$LOG_FOLDER"

#Recording events to the log file
log () {
    local msg=$1
    echo - e "$(date '+%Y-%m-%d %H:%M:%S')" $msg | tee -a $LOG_FILE
}

#Check return code of the most recently executed foreground command
check_status () {
    local status=$1
    local msg=$2
    if [ $status -eq 0 ]; then
        log "${G}$msg: Success${N}"
    else
        log "${R}$msg: Failed${N}"
        exit 1
    fi
}

log "Disabling default nodejs version from installing"
dnf module disable nodejs -y
check_status $? "Disabling"

log "Enabling nodejs version 20"
dnf module enable nodejs:20 -y
check_status $? "Enabling"

log "Installing nodejs version 20"
dnf install nodejs -y
check_status $? "Installing"


log "Creating app folder"
mkdir /app
check_status $? "Creation"

log "Creating service account for user application"
useradd --system --home /app --shell /sbin/nologin --comment "service account for cart application" roboshop
check_status $? "Creation"


log "Download the application to /tmp folder"
curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip
check_status $? "Downloading"

log "Downloading dependencies"
cd /app
unzip /tmp/user.zip
npm install
check_status $? "Downloading dependencies"

log "Creating the cart service"
cp $SCRIPT_DIRECTORY/cart.service /etc/systemd/system/
check_status $? "Creating the cart service"

log "Load the service, enable and start it"
systemctl daemon-reload
systemctl enable cart.service
systemctl start cart.service
check_status $? "Starting the cart service"

log "Check the service status, wait until it is active"
while ! systemctl is-active --quiet cart.service; do
    log "Waiting for service to be in active state"
    sleep 2
done
log "Cart service is now active"


