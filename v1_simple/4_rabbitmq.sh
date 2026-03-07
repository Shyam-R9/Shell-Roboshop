#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/rabbitmq-server-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

USER="roboshop"
PASSWORD="roboshop123"

echo "Copying rabbitmq repo to repos directory"
cp "$SCRIPT_DIRECTORY/rabbitmq.repo" /etc/yum.repos.d/

echo "Starting RabbitMQ installation"
dnf install rabbitmq-server -y

echo "Enable  and start rabbitmq-server service"
systemctl enable rabbitmq-server
systemctl start rabbitmq-server

echo "Waiting until rabbitmq service comes to active state"
while ! systemctl is-active --quiet rabbitmq-server; do
    echo "Waiting for rabbitmq-server service to be active"
    sleep 5
done
echo "rabbitmq-server service is now active"

echo "Adding a user rabbitmq to access the database"
rabbitmqctl add_user $USER $PASSWORD
rabbitmqctl set_permissions -p / $USER ".*" ".*" ".*"
rabbitmqctl status

echo "RabbitMQ installation completed"