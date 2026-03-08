#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/mysql-server-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

echo "Installing mysql-server"
dnf install mysql-server -y

echo "Enabling mysql-server service"
systemctl enable mysqld

echo "Starting mysql service and waiting until it comes to active state"
systemctl start mysqld
while ! systemctl is-active --quiet mysqld; do
    echo "Waiting for mysql service to be active"
    sleep 5
done
echo "mysql service is now active"

echo "Please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD

echo "Change the default root password"
mysql_secure_installation --set-root-pass $MYSQL_ROOT_PASSWORD

echo "mysql service status:
systemctl status mysqld