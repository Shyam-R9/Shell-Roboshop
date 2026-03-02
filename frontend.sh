#!/bin/bash
#Script to configure frontend server for e-commerce app

R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"

LOG_FOLDER="/var/log/frontend"
SCRIPT_NAME=$(basename $0 .sh)
LOGFILE_NAME="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p $LOG_FOLDER

log () {
    local msg=$1
    echo -e "$(date '+%Y-%m-%d +%H-%M-%S') $msg" | tee -a $LOGFILE_NAME
}

check_status () {
    local exit_code=$1
    local msg=$2
    if [ $exit_code -eq 0 ]; then
        log "$msg is ${G}Successful${N}"
    else
        log "$msg is ${R}failed${N}"
        exit 1
    fi
}

if [ "$EUID" -ne 0 ]; then
    log "Please run as root"
    exit 1
fi

log "Disabling default nginx module stream"
dnf module disable nginx -y
check_status $? "Disabling"

log "Enabling nginx 1.24 version"
dnf module enable nginx:1.24 -y
check_status $? "Enabling"

log "Install nginx 1.24 version"
dnf install nginx -y
check_status $? "Installing"

log "Enabling nginx service"
systemctl enable nginx
check_status $? "Enabling service"

log "Starting nginx service"
systemctl start nginx
check_status $? "Starting service"

log "Wait till service gets started"
    while ! systemctl is-active --quiet nginx; do
        echo "Waiting for nginx service to start"
        sleep 2
    done

log "nginx service is now active"

log "remove the default web content from nginx folder"
rm -rf /usr/share/nginx/html/* 
check_status $? "removing"

log "Download Web Content"
curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip
check_status $? "Downloading"

log "unzip and copy the web content to the /usr/share/nginx/html"
cd /usr/share/nginx/html
unzip /tmp/frontend.zip
check_status $? "Copying"

log "copy the custom nginx.conf file to /etc/nginx/"
cp /root/Shell-Roboshop/nginx.conf /etc/nginx/
check_status $? "copying of nginx.conf file"

log "Restarting nginx service"
systemctl restart nginx
check_status $? "Restarting service"





