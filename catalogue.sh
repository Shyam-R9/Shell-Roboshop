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
    echo -e "${G}$(date '+%Y-%m-%d %H:%M:%S')${N} $msg" | tee -a $LOG_FILE
}

log "${G}Disabling the default version of nodejs download${N}"
dnf module disable nodejs -y

log "${G}enable nodejs 20 download stream${N}"
dnf module enable nodejs:20 -y

log "${G}install NodeJS 20${N}"
dnf install nodejs -y

log "${G}Create roboshop user${N}"
useradd --system --home /app --shell /sbin/nologin --comment "roboshop service account" roboshop

log "${G}create application folder${N}"
mkdir /app

log "${G}Download application code${N}"
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip

log "${G}Install dependencies${N}"
cd /app
unzip /tmp/catalogue.zip
npm install

log "${G}create catalogue service file and copy services folder${N}"
cp catalogue.service /etc/systemd/system/

log "${G}Enable and Start service${N}"
systemctl enable catalogue.service
systemctl start catalogue.service

log "${G}Create mongodb repo and install Mongo client${N}"
cp mongodb.repo /etc/yum.repos.d/mongo.repo
dnf install mongodb-mongosh -y

log "${G}Load master data${N}"
mongosh --host MONGODB </app/db/master-data.js