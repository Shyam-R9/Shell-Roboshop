#!/bin/bash
#### steps to cleanup mysql###
#dnf remove mysql-server -y
#rm -rf /var/lib/mysql . previous installation left data in /var/lib/mysql
#dnf install mysql-server -y

MYSQL_ROOT_PASSWORD="RoboShop@1"

# Install MySQL
dnf install mysql-server -y

# Enable & start service
systemctl enable mysqld
systemctl start mysqld

# Wait for MySQL
until mysqladmin ping --silent; do
  echo "Waiting for MySQL to start..."
  sleep 2
done

# Check if root login without password works
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