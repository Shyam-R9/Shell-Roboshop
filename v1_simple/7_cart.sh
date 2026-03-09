#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/cart-install.log"

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
useradd --system --home /app --shell /sbin/nologin --comment "service account for cart application" roboshop

echo "Download the application to /tmp folder"
curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip

echo "Downloading dependencies"
cd /app
unzip /tmp/cart.zip
npm install

echo "Creating the cart service"
cp $SCRIPT_DIRECTORY/cart.service /etc/systemd/system/

echo "Load the service, enable and start it"
systemctl daemon-reload
systemctl enable cart.service
systemctl start cart.service

echo "Checking the service status, wait until it is active"
while ! systemctl is-active --quiet cart.service; do
    log "Waiting for service to be in active state"
    sleep 2
done
log "Cart service is now active"