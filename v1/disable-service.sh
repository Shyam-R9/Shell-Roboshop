#!/bin/bash

hosts=(
  "192.168.146.137" "192.168.146.143" "192.168.146.139"
  "192.168.146.136" "192.168.146.144" "192.168.146.142"
  "192.168.146.140" "192.168.146.141" "192.168.146.145"
  "192.168.146.146" "192.168.146.138"
)

for host in "${hosts[@]}"; do
    echo "Checking firewalld on $host..."
    sshpass -p 'T1t@nEdge' ssh -o StrictHostKeyChecking=no root@"$host" '
        if systemctl is-active --quiet firewalld; then
            echo "firewalld is active, stopping and disabling..."
            systemctl stop firewalld
            systemctl disable firewalld
        else
            echo "firewalld is already inactive."
        fi
    '
done