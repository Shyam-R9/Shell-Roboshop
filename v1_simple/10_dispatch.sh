#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/dispatch-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Install GoLang"
dnf install golang -y

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

echo "Download the application code to app directory"
curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip 
rm -rf /app/*
unzip -o /tmp/dispatch.zip -d /app

echo "Download the dependencies & build the software"
cd /app 
go mod init dispatch
go get 
go build

echo "Setup SystemD Payment Service"
cp $SCRIPT_DIRECTORY/dispatch.service /etc/systemd/system/

echo "Load the service"
systemctl daemon-reload

echo "Enable and Start the service"
systemctl enable dispatch 
systemctl start dispatch