#!/bin/bash

#EC2 Specs

AMI_ID="ami-0220d79f3f480ecf5"
INSTANCE_TYPE="t2.micro"
SG_ID="sg-0d2808590c55c9bdc"
SUBNET_ID="subnet-0a5d1290d3bae7537"
REGION="us-east-1"
ZONE_ID="Z0507828DY30BPSS03KO"
DOMAIN_NAME="studydevops.fun"

#Helper function
check_status() {
  if [ $? != 0 ]; then
    echo "Error: $1 failed. Exiting ..."
    exit 1
  fi
}

#Check if instance already exists
instance_exists() {
  local instance=$1
  EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text --region $REGION)

  if [[ -n "$EXISTING_INSTANCE" ]]; then
    echo "Instance '$instance' already exists with ID: $EXISTING_INSTANCE. Skipping creation."
    return 0
  else
    return 1
  fi
}

#Create EC2 Instances
create_instance() {
  local instance=$1
  echo "Launching EC2 instance: $instance"
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query "Instances[0].InstanceId" \
    --output text)
  check_status "$instance creation"
  
  echo "Waiting for $instance ($INSTANCE_ID) to be running"
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

  echo "$instance creation successful with instance id: $INSTANCE_ID"
}

#Get IP address
get_ip_address() {
  local instance=$1
  if [[ $instance != "frontend" ]]; then
    IP_ADDR=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text --region $REGION)
    RECORD_NAME=$instance.$DOMAIN_NAME
  else
    # Loop until Public IP is assigned
    while true; do
      IP_ADDR=$(aws ec2 describe-instances --instance-ids $instance_id \
        --query 'Reservations[*].Instances[*].PublicIpAddress' \
        --output text --region $REGION)
      if [[ -n "$IP_ADDR" && "$IP_ADDR" != "None" ]]; then
        break
      fi
      echo "Waiting for Public IP..."
      sleep 5
    done
    RECORD_NAME=$DOMAIN_NAME
  fi

  check_status "Retrieval of the IP Address of the instance: $instance"
  echo "IP Address of the $instance: $IP_ADDR"
}
#Update Hosted Zone records
update_dns_records() {
  local RECORD_NAME=$1
  local IP_ADDR=$2
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$RECORD_NAME\",
          \"Type\": \"A\",
          \"TTL\": 60,
          \"ResourceRecords\": [{\"Value\": \"$IP_ADDR\"}]
        }
      }
    ]
  }"
  check_status "Updating the $RECORD_NAME with its IP $IP_ADDR"
  echo "Updating the $RECORD_NAME with its IP $IP_ADDR is successful"
}

#MAIN SCRIPT
if [ $# -eq 0 ]; then
  echo "Script Usage: $0 <instance1 name> <instance2 name> ..."
  echo "Example: $0 mongodb mysql cart ...."
  exit 1
fi

for instance in "$@"; do
  create_instance $instance
  get_ip_address $instance
  update_dns_records $RECORD_NAME $IP_ADDR
done
