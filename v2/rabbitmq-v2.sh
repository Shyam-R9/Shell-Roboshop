#!/usr/bin/env bash
# RabbitMQ Installation Script

set -eEuo pipefail

########################################
# CONFIGURATION
########################################

LOG_DIR="/var/log/rabbitmq"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}.log"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$LOG_DIR"

########################################
# COLOR CODES (Terminal only)
########################################

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

########################################
# LOGGING FUNCTION
########################################

log() {

    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)  color=$G ;;
        WARN)  color=$Y ;;
        ERROR) color=$R ;;
        *)     color=$N ;;
    esac

    # Terminal (colored)
    echo -e "${timestamp} ${color}[$level]${N} ${message}"

    # Log file (plain)
    echo "${timestamp} [$level] ${message}" >> "$LOG_FILE"
}

########################################
# ERROR HANDLING
########################################

error_handler() {
    local exit_code=$?
    local line_no=$1
    log ERROR "Script failed at line ${line_no} with exit code ${exit_code}"
}

cleanup() {
    rm -f "$LOCK_FILE"
    log INFO "Script finished execution"
}

trap 'error_handler $LINENO' ERR
trap cleanup EXIT
trap 'log ERROR "Script interrupted by user"; exit 1' INT TERM

########################################
# LOCK FILE (prevent parallel runs)
########################################

if [[ -f "$LOCK_FILE" ]]; then
    log ERROR "Another instance of the script is running"
    exit 1
fi

touch "$LOCK_FILE"

########################################
# ROOT CHECK
########################################

log INFO "Checking root privileges"

if [[ $EUID -ne 0 ]]; then
    log ERROR "Please run the script as root"
    exit 1
fi

log INFO "Root privileges verified"

########################################
# RETRY FUNCTION
########################################

retry() {

    local retries=$1
    shift
    local count=0

    until "$@"; do

        exit_code=$?
        count=$((count + 1))

        if [[ $count -ge $retries ]]; then
            log ERROR "Command failed after ${retries} attempts: $*"
            return $exit_code
        fi

        log WARN "Retry ${count}/${retries} for command: $*"
        sleep 3
    done
}

########################################
# INSTALL RABBITMQ
########################################

log INFO "Checking if RabbitMQ is already installed"

if ! rpm -q rabbitmq-server &>/dev/null; then

    log INFO "Copying RabbitMQ repository"

    cp "$SCRIPT_DIR/rabbitmq.repo" /etc/yum.repos.d/

    log INFO "Installing RabbitMQ"

    retry 3 dnf install rabbitmq-server -y

    log INFO "Enabling RabbitMQ service"

    systemctl enable rabbitmq-server

    log INFO "Starting RabbitMQ service"

    retry 3 systemctl start rabbitmq-server

else

    installed_version=$(rpm -q rabbitmq-server)

    log WARN "RabbitMQ already installed: ${installed_version}"

fi

########################################
# WAIT FOR SERVICE
########################################

log INFO "Checking RabbitMQ service status"

for i in {1..12}; do

    if systemctl is-active --quiet rabbitmq-server; then
        log INFO "RabbitMQ service is active"
        break
    fi

    log WARN "Waiting for RabbitMQ service..."
    sleep 5

done

########################################
# CREATE APPLICATION USER
########################################

log INFO "Checking if roboshop user exists"

if ! rabbitmqctl list_users | grep -q '^roboshop'; then

    log INFO "Creating roboshop RabbitMQ user"

    rabbitmqctl add_user roboshop roboshop123

    rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"

    log INFO "roboshop user created successfully"

else

    log WARN "roboshop RabbitMQ user already exists"

fi

########################################
# HEALTH CHECK
########################################

log INFO "Running RabbitMQ health check"

rabbitmqctl status >/dev/null

log INFO "RabbitMQ installation completed successfully"