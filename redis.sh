#!/bin/bash
#Bash Script to install redis
set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/redis/"
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

log "Disabling default redis version"
dnf module disable redis -y
check_status $? "Disabling"

log "Enabling redis version 7"
dnf module enable redis:7 -y
check_status $? "Enabling"

log "Installing redis 7"
dnf install redis -y
check_status $? "Installing redis 7"

log "Taking backup of the redis.conf file"
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak

log "Configuring redis to accept connections from all hosts and changing the protected mode to no"
sed -i \
    -e 's/127.0.0.1/0.0.0.0/g' \
    -e '/protected-mode/ c protected-mode no' \
    /etc/redis/redis.conf
check_status $? "Modifications to redis.conf file"

log "Enable redis service"
systemctl enable redis
check_status $? "Enabling"

log "Start redis service"
systemctl start redis
check_status $? "Starting"






