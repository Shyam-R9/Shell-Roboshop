#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/mongodb-server-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Installing mysql-server"
dnf install mysql-server -y

echo "Enabling mysql-server service"
systemctl enable mysqld

echo "Starting mongodb-service and waiting until it comes to active state"
systemctl start mysqld
while ! systemctl is-active --quiet mysqld; do
    echo "Waiting for mysql service to be active"
    sleep 5
done
echo "mysql service is now active"

# Prompt for root password
read -s -p "Enter new MySQL root password: " MYSQL_ROOT_PASSWORD
echo

log "Checking current root authentication plugin"
PLUGIN=$(mysql -u root --skip-password -N -e "SELECT plugin FROM mysql.user WHERE user='root' AND host='localhost';" || true)

if [[ "$PLUGIN" == "auth_socket" || -z "$PLUGIN" ]]; then
    log "Root is using auth_socket or inaccessible, switching to password authentication"
    # Run ALTER USER via socket login
    sudo -u mysql mysql --skip-password -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
else
    log "Root already uses password authentication, updating password"
    mysql -u root --skip-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
fi

systemctl is-active --quiet mysqld && log "MySQL is running"
