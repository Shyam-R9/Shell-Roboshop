#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/redis-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

echo "Disabling default redis download version"
dnf module disable redis -y

echo "Enabling redis version:7"
dnf module enable redis:7 -y

echo "Installing mongodb-server"
dnf install redis -y

echo "Enabling redis service"
systemctl enable redis

echo "Starting redis service and waiting until it comes to active state"
systemctl start redis
while ! systemctl is-active --quiet redis; do
    echo "Waiting for redis service to be active"
    sleep 5
done
echo "redis service is now active"

echo "Configuring redis server to accept connections from all hosts and setting protected-mode to No"
sed -i \
    -e 's/127.0.0.1/0.0.0.0/g' \
    -e '/protected-mode/ c protected-mode no' \
    /etc/redis/redis.conf

echo "Restarting mongodb service"
systemctl restart redis

echo "Mongodb service status"
systemctl status redis


