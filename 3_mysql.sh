#!/bin/bash
#Script to install mysql

set -euo pipefail
R="\e[31m" G="\e[32m" Y="\e[33m" N="\e[0m"
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

#Prepare log directory and file
LOG_FOLDER="/var/log/mysql/"
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

log "${Y}Checking if user has root permissions${N}"
if [ $EUID -ne 0 ]; then
    log "${R}Please run this script as root${N}"
    exit 1
fi

log "${Y}Idempotent installation check${N}"
if ! rpm -q mysql &>/dev/null; then
    log "${R}mysql not installed on this server. Proceeding with installation${N}"
    log "${Y}Installing mysql server${N}"
    dnf install mysql-server -y
    check_status $? "Installing mysql server"
    log "${Y}Enable and start the service${N}"
    systemctl enable mysqld
    systemctl start mysqld
    check_status $? "Starting the mysql service"
else
    log "${Y}mysql already installed on this server. Skipping installation. Installed version:${N}"
    rpm -q mysql | tee -a $LOG_FILE
fi

log "${Y}Check the service status, wait until it is active${N}"
while ! systemctl is-active --quiet mysqld; do
    log "${Y}Waiting for service to be in active state${N}"
    sleep 2
done

log "${Y}mysql-server service status${N}"
systemctl status mysqld --no-pager --plain | tee -a "$LOG_FILE"