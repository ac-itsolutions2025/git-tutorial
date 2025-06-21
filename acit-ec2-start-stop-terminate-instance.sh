#!/bin/bash

read -p "Enter AWS region (e.g., us-east-1): " REGION

read -p "Do you want to (start/stop/terminate) all instances in $REGION? " ACTION

ACTION=$(echo "$ACTION" | tr '[:upper:]' '[:lower:]')

if [[ "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "terminate" ]]; then
    echo "Invalid action. Please choose 'start', 'stop', or 'terminate'."
    exit 1
fi

# Determine appropriate state to filter by
case "$ACTION" in
    "start")
        STATE_FILTER="stopped"
        ;;
    "stop"|"terminate")
        STATE_FILTER="running"
        ;;
esac

INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --query "Reservations[*].Instances[?State.Name=='$STATE_FILTER'].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "No $STATE_FILTER instances found in $REGION."
    exit 0
fi

echo "Selected action: $ACTION"
echo "Target instances:"
echo "$INSTANCE_IDS"

read -p "Are you sure you want to $ACTION these instances? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Execute the chosen action
case "$ACTION" in
    "start")
        RESPONSE=$(aws ec2 start-instances --region "$REGION" --instance-ids $INSTANCE_IDS --query "StartingInstances[*].[InstanceId,CurrentState.Name]" --output text)
        ;;
    "stop")
        RESPONSE=$(aws ec2 stop-instances --region "$REGION" --instance-ids $INSTANCE_IDS --query "StoppingInstances[*].[InstanceId,CurrentState.Name]" --output text)
        ;;
    "terminate")
        RESPONSE=$(aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS --query "TerminatingInstances[*].[InstanceId,CurrentState.Name]" --output text)
        ;;
esac

echo -e "\nAction '$ACTION' completed. Current state of instances:"
echo "$RESPONSE"

