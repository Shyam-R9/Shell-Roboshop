#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/shipping-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "installing maven, which also installs Java"
dnf install maven -y

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

echo "Download the application to /tmp folder"
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip 
cd /app 
rm -rf /app/*
unzip -o /tmp/dispatch.zip -d /app

echo "download the dependencies & build the application"
cd /app 
mvn clean package 
mv target/shipping-1.0.jar shipping.jar 

echo "Creating the shipping service"
cp $SCRIPT_DIRECTORY/shipping.service /etc/systemd/system/

echo "Load the service, enable and start it"
systemctl daemon-reload
systemctl enable shipping.service
systemctl start shipping.service

echo "Check the service status, wait until it is active"
while ! systemctl is-active --quiet shipping.service; do
    log "Waiting for service to be in active state"
    sleep 2
done

echo "Installing mysql client"
dnf install mysql -y 

echo "Loading the database schema to sql server"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/schema.sql

echo "Creating app user to connect to sql"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/app-user.sql

echo "Load master data to mysql"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/master-data.sql

echo "Restart the shipping service"
systemctl restart shipping

