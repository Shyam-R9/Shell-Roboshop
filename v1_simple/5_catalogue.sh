#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/catalogue-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Disabling the default version of nodejs download"
dnf module disable nodejs -y

echo "enabling the nodejs 20 download stream"
dnf module enable nodejs:20 -y

echo "install NodeJS20"
dnf install nodejs -y

echo "Creating roboshop user"
useradd --system --home /app --shell /sbin/nologin --comment "roboshop service account" roboshop

echo "Creating app folder"
mkdir /app

echo "Downloading catolouge application code to temp folder"
rm -rf /app/*
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip

echo "Installing dependencies"
cd /app
unzip /tmp/catalogue.zip
npm install

echo "Copy the catalogue.service file to the systemd unit files directory"
cp "$SCRIPT_DIRECTORY"/catalogue.service /etc/systemd/system/

echo "Enable catalogue service"
systemctl enable catalogue.service

echo "Start Catalogue service"
systemctl start catalogue.service
while ! systemctl is-active --quiet catalogue.service; do
    echo "Waiting for Catalogue service to be active"
    sleep 2
done
echo "Catalogue service is now active"

echo "Copy mongo repo file"
cp "$SCRIPT_DIRECTORY"/mongo.repo /etc/yum.repos.d/

echo "Install mongo client"
dnf install mongodb-mongosh -y

echo "Load master data"
mongosh --host mongodb.studydevops.fun </app/db/master-data.js

COUNT=$(mongosh --quiet --host mongodb.studydevops.fun --eval "use catalogue; db.products.countDocuments()")
if [ "$COUNT" -eq 0 ]; then
  echo "Master data not loaded. Run master-data.js"
  exit 1
else
  echo "Master data verified. Products count: $COUNT"
fi