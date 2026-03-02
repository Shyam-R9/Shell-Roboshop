#!/bin/bash

#set color code
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"

#Create log file
LOG_FOLDER="/var/log/catalogue"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p $LOG_FOLDER

#Settingup structured log
log () {
    local msg=$1
    echo -e "$$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a $LOG_FILE
}

check_status() {
    local status=$1
    local message=$2
    if $status -eq 0; then
        log "${G}$message is success${N}"
    else
        log "${R}$message is failed${N}"
        exit 1
    fi
}

log "${G}Disabling the default version of nodejs download${N}"
dnf module disable nodejs -y
check_status $? "Disabling is"

log "${G}enabling the nodejs 20 download stream${N}"
dnf module enable nodejs:20 -y
check_status $? "Enabling NodeJS20 is"

log "${G}install NodeJS 20${N}"
dnf install nodejs -y
check_status $? "Installation of NodeJs"

log "${G}Checking if the roboshop user already exists${N}"
if id -u roboshop &>/dev/null; then
    log "${Y}roboshop user already exists, skipping user creation${N}"
else
    log "${G}roboshop user doesn't exist, proceeding with user creation${N}"
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop service account" roboshop
    check_status $? "Roboshop user creation "
fi

log "${G}Checking if the application folder already exists${N}"
if [ -d /app ]; then
    log "${Y}/app folder already exists, skipping folder creation${N}"
else
    log "${G}/app folder doesn't exist, proceeding with folder creation${N}"
    mkdir /app
    check_status $? "/app folder creation "
fi

log "${G}Downloading catolouge application code to temp folder${N}"
rm -rf /app/*
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip
check_status $? "Downloading of catalogue.zip"

log "${G}Installing dependencies${N}"
cd /app
unzip /tmp/catalogue.zip
npm install
check_status $? "Installing dependencies"

log "${G}Copy the catalogue.service file to the systemd unit files director${N}"
cp catalogue.service /etc/systemd/system/
check_status $? "Copy of catalogue.service file"

log "${G}Enable catalogue service${N}"
systemctl enable catalogue.service

log "${G}Start Catalogue service${N}"
systemctl start catalogue.service
while ! systemctl is-active --quiet catalogue.service; do
    echo "Waiting for Catalogue service to be active"
    sleep 2
done
log "${G}Catalogue service is now active${N}"

log "${G}Copy mongo repo file${N}"
cp mongo.repo /etc/yum.repos.d/
check_status $? "Copy of the mongo repo file"

log "${G}Install mongo client${N}"
dnf install mongodb-mongosh -y
check_status $? "Istallation of mongo"

log "${G}Load master data${N}"
mongosh --host MONGODB </app/db/master-data.js
check_status $? "Loading of the master data to mongo db"
