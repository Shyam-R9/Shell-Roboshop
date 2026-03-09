#!/bin/bash
#### steps to cleanup mysql###
#dnf remove mysql-server -y
#rm -rf /var/lib/mysql . previous installation left data in /var/lib/mysql
#dnf install mysql-server -y
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/mysql-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

MYSQL_ROOT_PASSWORD="RoboShop@1"

echo "Installing MySQL"
dnf install mysql-server -y

echo "Enable & start service"
systemctl enable mysqld
systemctl start mysqld

echo "Waiting for MySQL to start"
until mysqladmin ping --silent; do
  echo "Waiting for MySQL to start..."
  sleep 2
done

echo "Check if root login without password works"
if mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    echo "Setting MySQL root password..."

    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    echo "Root password configured."
else
    echo "Root password already set. Skipping."
fi