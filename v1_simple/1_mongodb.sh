#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)

LOG_File="/var/log/mongodb-server-install.log"

exec > >(awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a "$LOG_File")
exec 2>&1

echo "Copying mongo repo to repos directory"
cp "$SCRIPT_DIRECTORY/mongo.repo" /etc/yum.repos.d/mongo.repo

echo "Installing mongodb-server"
dnf install mongodb-org -y

echo "Enabling mongodb-server service"
systemctl enable mongod

echo "Starting mongodb-service and waiting until it comes to active state"
systemctl start mongod
while ! systemctl is-active --quiet mongod; do
    echo "Waiting for mongodb service to be active"
    sleep 5
done
echo "mongodb service is now active"

echo "Configuring mongodb server to accept connections from all hosts"
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf

echo "Restarting mongodb service"
systemctl restart mongod

echo "Mongodb service status"
systemctl status mongod


