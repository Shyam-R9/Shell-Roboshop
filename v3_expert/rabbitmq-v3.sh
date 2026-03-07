#!/usr/bin/env bash

############################################
# RabbitMQ Installation Script
# Version: 2.0
# Description:
#   Production-grade RabbitMQ installation
#   with structured logging and safety checks
############################################

set -eEuo pipefail

############################################
# CONFIGURATION
############################################

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

LOG_DIR="/var/log/rabbitmq"
LOG_FILE="$LOG_DIR/rabbitmq-install.log"
FALLBACK_LOG="/tmp/rabbitmq-install.log"

LOCK_FILE="/var/lock/${SCRIPT_NAME}.lock"

RABBITMQ_USER="roboshop"
RABBITMQ_PASSWORD="roboshop123"
RABBITMQ_VHOST="/"

DRY_RUN=false
DEBUG=false

TOTAL_STEPS=7
CURRENT_STEP=0

############################################
# COLORS
############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

############################################
# ARGUMENT PARSING
############################################

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --debug)
            DEBUG=true
            set -x
            ;;
    esac
done

############################################
# LOGGING
############################################

log() {

    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    local color="$RESET"

    case "$level" in
        INFO) color="$BLUE" ;;
        WARN) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        SUCCESS) color="$GREEN" ;;
    esac

    local line="${timestamp} [${level}] ${message}"

    echo -e "${color}${line}${RESET}"

    if [[ -w "$LOG_FILE" || ! -e "$LOG_FILE" && -w "$LOG_DIR" ]]; then
        echo "$line" >> "$LOG_FILE"
    else
        echo "$line" >> "$FALLBACK_LOG"
    fi
}

############################################
# ERROR HANDLER
############################################

error_handler() {

    local exit_code=$?
    local line_no=$1

    log ERROR "Script failed at line ${line_no} (exit code ${exit_code})"
    exit "$exit_code"
}

trap 'error_handler $LINENO' ERR

############################################
# COMMAND WRAPPER
############################################

run_cmd() {

    if $DRY_RUN; then
        log INFO "[DRY-RUN] $*"
        return 0
    fi

    log INFO "Executing: $*"
    "$@"
}

############################################
# RETRY LOGIC
############################################

retry() {

    local retries=$1
    shift
    local count=0

    until "$@"; do

        count=$((count + 1))

        if [[ $count -ge $retries ]]; then
            log ERROR "Command failed after ${retries} attempts: $*"
            return 1
        fi

        log WARN "Retry ${count}/${retries}: $*"
        sleep 5
    done
}

############################################
# STEP FRAMEWORK
############################################

run_step() {

    local description="$1"
    shift

    CURRENT_STEP=$((CURRENT_STEP + 1))

    log INFO "[STEP ${CURRENT_STEP}/${TOTAL_STEPS}] ${description}"

    local start_time
    start_time=$(date +%s)

    if "$@"; then

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log SUCCESS "[STEP ${CURRENT_STEP}/${TOTAL_STEPS}] SUCCESS (${duration}s)"
    else
        log ERROR "[STEP ${CURRENT_STEP}/${TOTAL_STEPS}] FAILED"
        exit 1
    fi
}

############################################
# LOCK FILE
############################################

acquire_lock() {

    if [[ -f "$LOCK_FILE" ]]; then
        log ERROR "Another installation is already running"
        exit 1
    fi

    touch "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

trap release_lock EXIT

############################################
# ROOT CHECK
############################################

check_root() {

    if [[ "$EUID" -ne 0 ]]; then

        logger -p auth.warning \
        "Unauthorized RabbitMQ install attempt by user $(whoami)"

        log ERROR "Script must be run as root"
        exit 1
    fi
}

############################################
# DEPENDENCY CHECK
############################################

check_dependencies() {

    local deps=("dnf" "systemctl" "logger")

    for cmd in "${deps[@]}"; do

        if ! command -v "$cmd" &>/dev/null; then
            log ERROR "Missing dependency: $cmd"
            exit 1
        fi

    done

    log INFO "Dependencies verified"
}

############################################
# OS CHECK
############################################

check_os() {

    if ! grep -q "Rocky\|Alma\|CentOS\|Red Hat" /etc/os-release; then
        log ERROR "Unsupported OS"
        exit 1
    fi

    log INFO "OS validation passed"
}

############################################
# INSTALL RABBITMQ
############################################

install_rabbitmq() {

    if rpm -q rabbitmq-server &>/dev/null; then
        log WARN "RabbitMQ already installed"
        return 0
    fi

    run_cmd cp "$SCRIPT_DIR/rabbitmq.repo" /etc/yum.repos.d/

    retry 3 run_cmd dnf install rabbitmq-server -y

    run_cmd systemctl enable rabbitmq-server
}

############################################
# START SERVICE
############################################

start_rabbitmq() {

    retry 3 run_cmd systemctl start rabbitmq-server
}

############################################
# WAIT FOR SERVICE
############################################

wait_for_rabbitmq() {

    local MAX_WAIT=60
    local INTERVAL=5
    local ELAPSED=0

    while [[ $ELAPSED -lt $MAX_WAIT ]]; do

        if rabbitmqctl status &>/dev/null; then
            log INFO "RabbitMQ is ready"
            return 0
        fi

        log WARN "RabbitMQ not ready (${ELAPSED}/${MAX_WAIT}s)"
        sleep "$INTERVAL"
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    log ERROR "RabbitMQ failed to start"
    return 1
}

############################################
# CREATE USER
############################################

create_user() {

    if rabbitmqctl list_users | grep -q "^${RABBITMQ_USER}"; then
        log WARN "User ${RABBITMQ_USER} already exists"
        return 0
    fi

    retry 3 run_cmd rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"

    retry 3 run_cmd rabbitmqctl set_permissions \
        -p "$RABBITMQ_VHOST" \
        "$RABBITMQ_USER" ".*" ".*" ".*"

    log INFO "User ${RABBITMQ_USER} created"
}

############################################
# HEALTH CHECK
############################################

health_check() {

    rabbitmqctl status >/dev/null

    log INFO "RabbitMQ health check passed"
}

############################################
# MAIN
############################################

main() {

    mkdir -p "$LOG_DIR"

    acquire_lock

    check_root

    log INFO "Starting RabbitMQ installation"

    run_step "Checking dependencies" check_dependencies
    run_step "Validating operating system" check_os
    run_step "Installing RabbitMQ" install_rabbitmq
    run_step "Starting RabbitMQ service" start_rabbitmq
    run_step "Waiting for RabbitMQ readiness" wait_for_rabbitmq
    run_step "Creating application user" create_user
    run_step "Running health check" health_check

    log SUCCESS "RabbitMQ installation completed"
}

main "$@"