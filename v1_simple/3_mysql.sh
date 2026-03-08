#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="/var/log/mysql-server-install.log"   # fixed variable name

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

[[ $EUID -eq 0 ]] || { echo "Please run as root"; exit 1; }

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"; }

log "Installing mysql-server"
dnf install -y mysql-server

log "Enabling mysql-server service"
systemctl enable mysqld

log "Starting mysql service"
systemctl start mysqld
until systemctl is-active --quiet mysqld; do
    log "Waiting for mysql service to be active"
    sleep 5
done
log "MySQL service is now active"

# Prompt for root password directly on terminal (not through log pipe)
read -s -p "Enter new MySQL root password: " MYSQL_ROOT_PASSWORD </dev/tty
echo

log "Checking current root authentication plugin"
PLUGIN=$(mysql -u root --skip-password -N -e \
  "SELECT plugin FROM mysql.user WHERE user='root' AND host='localhost';" 2>/dev/null || true)

if [[ "$PLUGIN" == "auth_socket" || -z "$PLUGIN" ]]; then
    log "Root is using auth_socket or inaccessible, switching to password authentication"
    sudo -u mysql mysql --skip-password -e \
      "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
else
    log "Root already uses password authentication, updating password"
    mysql -u root --skip-password -e \
      "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
fi

systemctl is-active --quiet mysqld && log "MySQL is running"