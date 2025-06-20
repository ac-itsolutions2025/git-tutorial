#!/bin/bash

set -euo pipefail

print_red()   { echo -e "\e[31m$1\e[0m"; }
print_green() { echo -e "\e[32m$1\e[0m"; }
print_yellow(){ echo -e "\e[33m$1\e[0m"; }

command -v aws >/dev/null 2>&1 || { print_red "aws CLI is required. Exiting."; exit 1; }
command -v jq  >/dev/null 2>&1 || { print_red "jq is required. Exiting."; exit 1; }

read -rp "Enter AWS region: " REGION

if ! [[ "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
    print_red "Invalid region format. Example: us-east-1"
    exit 1
fi

echo "Retrieving EC2 instances in region $REGION..."

# Use mapfile -t to ensure each line is a single array element
mapfile -t INSTANCE_IDS < <(aws ec2 describe-instances --region "$REGION" --query "Reservations[].Instances[].InstanceId" --output text | tr '\t' '\n')

if [ ${#INSTANCE_IDS[@]} -eq 0 ]; then
    print_yellow "No EC2 instances found in region $REGION."
    exit 0
fi

UNTAGGED_INSTANCES=()

echo "Checking EC2 instances in region $REGION for tags..."

for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    # Remove leading/trailing whitespace
    INSTANCE_ID_CLEAN=$(echo "$INSTANCE_ID" | xargs)
    if [ -z "$INSTANCE_ID_CLEAN" ]; then
        continue
    fi
    TAG_COUNT=$(aws ec2 describe-tags --region "$REGION" \
        --filters "Name=resource-id,Values=$INSTANCE_ID_CLEAN" \
        --query "Tags" --output json | jq 'length')
    if [ "$TAG_COUNT" -eq 0 ]; then
        UNTAGGED_INSTANCES+=("$INSTANCE_ID_CLEAN")
    fi
done

if [ ${#UNTAGGED_INSTANCES[@]} -eq 0 ]; then
    print_green "All EC2 instances in region $REGION are tagged."
else
    print_red "The following EC2 instances have NO tags:"
    for ID in "${UNTAGGED_INSTANCES[@]}"; do
        echo " - [$ID]"  # Brackets help see if there is any whitespace in the ID
    done

    read -rp "Do you want to tag these instances now with unique tags? (y/n): " ANSWER
    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
        for ((i=0; i<${#UNTAGGED_INSTANCES[@]}; i++)); do
            ID="${UNTAGGED_INSTANCES[$i]}"
            # Extra cleaning for safety
            ID_CLEAN=$(echo "$ID" | xargs)
            echo ""
            print_yellow "Tagging instance $((i+1)) of ${#UNTAGGED_INSTANCES[@]}: [$ID_CLEAN]"
            read -rp "  Enter Name tag value: " NAME
            read -rp "  Enter Environment tag value: " ENV
            read -rp "  Enter Purpose tag value: " PURPOSE
            # Final safety check
            echo "About to tag instance: [$ID_CLEAN]"
            if aws ec2 create-tags --region "$REGION" --resources "$ID_CLEAN" \
                --tags Key=Name,Value="$NAME" Key=Environment,Value="$ENV" Key=Purpose,Value="$PURPOSE"; then
                print_green "  Tagged $ID_CLEAN with Name=$NAME, Environment=$ENV, Purpose=$PURPOSE"
            else
                print_red "  Failed to tag $ID_CLEAN"
            fi
        done
    else
        print_yellow "No tags were added."
    fi
fi

