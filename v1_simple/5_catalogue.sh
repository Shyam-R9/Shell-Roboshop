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

if ! id roboshop &>/dev/null; then
    echo "Creating roboshop user"
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop service account" roboshop
else
    echo "roboshop user already exists, skipping"
fi

if [ ! -d /app ]; then
    echo "Creating app folder"
    mkdir /app
else
    echo "/app folder already exists, skipping"
fi

echo "Downloading catolouge application code to temp folder"
rm -rf /app/*
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip

echo "Installing dependencies"
cd /app
unzip /tmp/catalogue.zip
npm install

if [ ! -f /etc/systemd/system/catalogue.service ]; then
    echo "Copying catalogue.service file"
    cp "$SCRIPT_DIRECTORY"/catalogue.service /etc/systemd/system/
else
    echo "catalogue.service already exists, skipping copy"
fi

echo "Enable catalogue service"
systemctl enable catalogue.service

systemctl enable catalogue.service
systemctl restart catalogue.service
while ! systemctl is-active --quiet catalogue.service; do
    echo "Waiting for Catalogue service to be active"
    sleep 2
done
echo "Catalogue service is now active"

if [ ! -f /etc/yum.repos.d/mongo.repo ]; then
    echo "Copying mongo.repo file"
    cp "$SCRIPT_DIRECTORY"/mongo.repo /etc/yum.repos.d/
else
    echo "mongo.repo already exists, skipping copy"
fi

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