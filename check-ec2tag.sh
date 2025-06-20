#!/bin/bash

# Script to check EC2 instances for tags in a given AWS region

read -p "Enter AWS region: " REGION

# Get all instance IDs in the region
INSTANCE_IDS=$(aws ec2 describe-instances --region "$REGION" --query "Reservations[].Instances[].InstanceId" --output text)

UNTAGGED_INSTANCES=()

echo "Checking EC2 instances in region $REGION for tags..."

for INSTANCE_ID in $INSTANCE_IDS; do
    TAG_COUNT=$(aws ec2 describe-tags --region "$REGION" --filters "Name=resource-id,Values=$INSTANCE_ID" --query "Tags" --output json | jq 'length')
    if [ "$TAG_COUNT" -eq 0 ]; then
        UNTAGGED_INSTANCES+=("$INSTANCE_ID")
    fi
done

if [ ${#UNTAGGED_INSTANCES[@]} -eq 0 ]; then
    echo "All EC2 instances in region $REGION are tagged."
else
    echo "The following EC2 instances are not tagged:"
    for ID in "${UNTAGGED_INSTANCES[@]}"; do
        echo "$ID"
    done

    read -p "Do you want to tag these instances now? (y/n): " ANSWER
    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
        read -p "Enter tag key: " TAG_KEY
        read -p "Enter tag value: " TAG_VALUE
        for ID in "${UNTAGGED_INSTANCES[@]}"; do
            aws ec2 create-tags --region "$REGION" --resources "$ID" --tags Key="$TAG_KEY",Value="$TAG_VALUE"
            echo "Tagged $ID with $TAG_KEY=$TAG_VALUE"
        done
    else
        echo "No tags were added."
    fi
fi