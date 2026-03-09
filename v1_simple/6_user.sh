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

echo "Disabling default nodejs version from installing"
dnf module disable nodejs -y

echo "Enabling nodejs version 20"
dnf module enable nodejs:20 -y

echo "Installing nodejs version 20"
dnf install nodejs -y

echo "Creating app folder"
mkdir /app

echo "Creating service account for user application"
useradd --system --home /app --shell /sbin/nologin --comment "service account for user application" roboshop

echo "Download the application to /tmp folder"
curl -L -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip

echo "Downloading dependencies"
cd /app
unzip /tmp/user.zip
npm install

echo "Creating the user service"
cp $SCRIPT_DIRECTORY/user.service /etc/systemd/system/

echo "Load the service, enable and start it"
systemctl daemon-reload
systemctl enable user.service
systemctl start user.service

echo "Check the service status, wait until it is active"
while ! systemctl is-active --quiet user.service; do
    log "Waiting for service to be in active state"
    sleep 2
done

echo "User service is now active"