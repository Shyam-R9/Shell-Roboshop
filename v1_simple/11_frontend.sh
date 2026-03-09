#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/frontend-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Disabling default nginx module stream"
dnf module disable nginx -y

echo "Enabling nginx 1.24 version"
dnf module enable nginx:1.24 -y

echo "Install nginx 1.24 version"
dnf install nginx -y

echo "Enabling nginx service"
systemctl enable nginx

echo "Starting nginx service"
systemctl start nginx

echo "Wait till nginx service gets started"
    while ! systemctl is-active --quiet nginx; do
        echo "Waiting for nginx service to start"
        sleep 2
    done

echo "nginx service is now active"

echo "remove the default web content from nginx folder"
rm -rf /usr/share/nginx/html/* 


echo "Download Web Content"
curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip

echo "unzip and copy the web content to the /usr/share/nginx/html"
cd /usr/share/nginx/html
unzip /tmp/frontend.zip

echo "copy the custom nginx.conf file to /etc/nginx/"
cp $SCRIPT_DIR/nginx.conf /etc/nginx/

echo "Restarting nginx service"
systemctl restart nginx

echo"Nginx Session Statistics"
ss -nltpu