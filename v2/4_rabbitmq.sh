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

log "Checking if the user has privileges to install the application"
if [ "$EUID" -eq 0 ]; then
    log "${G}You have privileges to install the application${N}"
else
    log "${R}Error: You don't have privileges to install the application${N}"
    exit 1
fi

# --- Trap handlers ---
# Log unexpected errors with line number
trap 'log "${R}Unexpected error at line $LINENO${N}"' ERR

# Cleanup on exit (success or failure)
trap 'log "${Y}Script exited. Cleaning up temporary files...${N}"
      rm -f /tmp/rabbitmq-install.tmp 2>/dev/null || true' EXIT

# Handle Ctrl+C (SIGINT)
trap 'log "${R}Installation interrupted by user (Ctrl+C). Exiting...${N}"
      exit 130' INT
# ---------------------
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


log "${Y}Idempotent installation check. Checking if rabbitmq is already installed${N}"
if ! rpm -q rabbitmq-server &>/dev/null; then
    log "creating rabbitmq repo file to download rabbitmq"
    cp "$SCRIPT_DIRECTORY/rabbitmq.repo" /etc/yum.repos.d/
    check_status $? "rabbitmq repo"

    log "install rabbitmq"
    dnf install rabbitmq-server -y
    check_status $? "installation of rabbitmq"

    log "enable and start rabbitmq service"
    systemctl enable rabbitmq-server
    systemctl start rabbitmq-server
    check_status $? "Starting the rabbitmq-server service"

else
    log "${Y}rabbitmq is already installed on this server. Installed version: ${N}"
    rpm -q rabbitmq-server
fi

log "Check the service status, wait until it is active"
while ! systemctl is-active --quiet rabbitmq-server; do
    log "Waiting for service to be in active state"
    sleep 5
done

log "rabbitmq-server service is active"

log "${Y}Idempotent installation check. Checking if roboshop user is already available${N}"
if ! rabbitmqctl list_users | grep -q '^roboshop'; then
    rabbitmqctl add_user roboshop roboshop123
    rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
else
    log "roboshop RabbitMQ user already exists"
fi