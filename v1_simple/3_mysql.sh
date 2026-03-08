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

echo "Changing MySQL root password"
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"

systemctl is-active --quiet mysqld && echo "MySQL is running"
