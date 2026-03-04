#!/bin/bash
#Bash Script to install rabbitmq
set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/rabbitmq/"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
mkdir -p "$LOG_FOLDER"

#Recording events in a log file
log () {
    local msg=$1
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a "$LOG_FILE"
}

check_status () {
    local status=$1
    local msg=$2
    if [ $status -eq 0 ]; then
        log "${G}$msg :Successful${N}"
    else
        log "${R}$msg :Failed${N}"
        exit 1
    fi    
}

log "creating rabbitmq repo file to download rabbitmq"
cp SCRIPT_DIRECTORY/rabbitmq.repo etc/yum.repos.d/
check_status $? "rabbitmq repo"

log "install rabbitmq"
dnf install rabbitmq-server -y
check_status $? "installation of rabbitmq"

log "enable and start rabbitmq service"
systemctl enable rabbitmq-server
systemctl start rabbitmq-server
check_status $? "Starting the rabbitmq-server service"

log "Check the service status, wait until it is active"
while ! systemctl is-active --quiet rabbitmq-server; do
    log "Waiting for service to be in active state"
    sleep 2
done
log "rabbitmq-server service is now active"

log "Create rabbitmq user and assign permissions"
rabbitmqctl add_user roboshop roboshop123
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
check_status $? "Create rabbitmq user and assign permissions"
