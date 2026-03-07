#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_FILE="/var/log/rabbitmq-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0 }' | tee -a $LOG_File)
exec 2>&1

USER="roboshop"
PASSWORD="roboshop123"

echo "Starting RabbitMQ installation"

cp "$SCRIPT_DIRECTORY/rabbitmq.repo" /etc/yum.repos.d/

dnf install rabbitmq-server -y

systemctl enable rabbitmq-server
systemctl start rabbitmq-server

rabbitmqctl add_user $USER $PASSWORD

rabbitmqctl set_permissions -p / $USER ".*" ".*" ".*"

rabbitmqctl status

echo "RabbitMQ installation completed"