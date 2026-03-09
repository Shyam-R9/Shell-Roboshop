#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/payment-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Install Python 3"
dnf install python3 gcc python3-devel -y

echo "Create application User"
useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop

echo "setup an app directory"
mkdir /app 

echo "Download the application code to app directory"
curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip 
cd /app 
unzip /tmp/payment.zip

echo "Download the dependencies"
cd /app 
pip3 install -r requirements.txt

echo "Setup SystemD Payment Service"
cp $SCRIPT_DIRECTORY/payment.service /etc/systemd/system/

echo "Load the service"
systemctl daemon-reload

echo "Enable and Start the service"
systemctl enable payment 
systemctl start payment

