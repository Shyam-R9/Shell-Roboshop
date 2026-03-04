#!/bin/bash
#Script to install shipping micro service
set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/shipping/"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p "$LOG_FOLDER"

#Recording events to the log file
log () {
    local msg=$1
    echo - e "$(date '+%Y-%m-%d %H:%M:%S')" $msg | tee -a $LOG_FILE
}

#Check return code of the most recently executed foreground command
check_status () {
    local status=$1
    local msg=$2
    if [ $status -eq 0 ]; then
        log "${G}$msg: Success${N}"
    else
        log "${R}$msg: Failed${N}"
        exit 1
    fi
}

log "installing maven, which also installs Java"
dnf install maven -y
check_status $? "Installation"

log "Creating service account for shipping application"
useradd --system --home /app --shell /sbin/nologin --comment "shipping account for user application" roboshop
check_status $? "Creation"


log "Download the application to /tmp folder"
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip
check_status $? "Downloading"

log "Downloading dependencies and build the application"
cd /app
unzip /tmp/shipping.zip
mvn clean package
mv target/shipping-1.0.jar shipping.jar 
check_status $? "Downloading dependencies and building the application"

log "Creating the shipping service"
cp $SCRIPT_DIRECTORY/shipping.service /etc/systemd/system/
check_status $? "Creating the shipping service"

log "Load the service, enable and start it"
systemctl daemon-reload
systemctl enable shipping.service
systemctl start shipping.service
check_status $? "Starting the shipping service"

log "Check the service status, wait until it is active"
while ! systemctl is-active --quiet shipping.service; do
    log "Waiting for service to be in active state"
    sleep 2
done
log "shipping service is now active"

log "Loading the database schema to sql server"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/schema.sql
check_status $? "Loading schema"

log "Creating app user to connect to sql"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/app-user.sql
check_status $? "Create user"

log "Load master data to mysql"
mysql -h mysql.studydevops.fun -uroot -pRoboShop@1 < /app/db/master-data.sql
check_status $? "Loading master data"

log "Restart the shipping service"
systemctl restart shipping
check_status $? "Restarting the service"
