#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/mysql-server-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_FILE")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

echo "Please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD

echo "Installing mysql server"
dnf install mysql-server -y

echo "Enable  and start mysql-server service"
systemctl enable mysqld
systemctl start mysqld

echo "Waiting until mysql service comes to active state"
while ! systemctl is-active --quiet mysqld; do
    echo "Waiting for mysql service to be active"
    sleep 5
done
echo "mysql service is now active"

mysql_secure_installation --set-root-pass $MYSQL_ROOT_PASSWORD &>>$LOG_FILE
