#!/bin/bash

set -euo pipefail

# Color functions
print_red()   { echo -e "\e[31m$1\e[0m"; }
print_green() { echo -e "\e[32m$1\e[0m"; }
print_yellow(){ echo -e "\e[33m$1\e[0m"; }

command -v aws >/dev/null 2>&1 || { print_red "aws CLI is required. Exiting."; exit 1; }
command -v jq  >/dev/null 2>&1 || { print_red "jq is required. Exiting."; exit 1; }

# Variables
ROLE_NAME="EC2_SSM_Access_Role"
PROFILE_NAME="EC2_SSM_Instance_Profile"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

read -rp "Enter AWS region: " REGION

if ! [[ "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
    print_red "Invalid region format. Example: us-east-1"
    exit 1
fi

# Step 1: Create IAM role if not exists
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    print_yellow "Creating IAM Role: $ROLE_NAME"
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }'
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
else
    print_green "IAM Role $ROLE_NAME already exists."
fi

# Step 2: Create Instance Profile if not exists
if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null 2>&1; then
    print_yellow "Creating Instance Profile: $PROFILE_NAME"
    aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
    aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME"
else
    print_green "Instance Profile $PROFILE_NAME already exists."
fi

# Step 3: List all EC2 instances in region
echo "Listing EC2 instances in region $REGION..."
mapfile -t INSTANCE_IDS < <(aws ec2 describe-instances --region "$REGION" --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' '\n')

if [ ${#INSTANCE_IDS[@]} -eq 0 ]; then
    print_yellow "No EC2 instances found in region $REGION."
    exit 0
fi

# Step 4: Loop over each instance and check profile
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    PROFILE_ATTACHED=$(aws ec2 describe-instances --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
        --output text 2>/dev/null || echo "None")

    if [ "$PROFILE_ATTACHED" == "None" ] || [ -z "$PROFILE_ATTACHED" ]; then
        print_yellow "Instance $INSTANCE_ID: No IAM profile attached."
        aws ec2 associate-iam-instance-profile --region "$REGION" \
            --instance-id "$INSTANCE_ID" \
            --iam-instance-profile Name="$PROFILE_NAME"
        print_green "  Attached $PROFILE_NAME to $INSTANCE_ID."
    else
        PROFILE_NAME_ATTACHED=$(basename "$PROFILE_ATTACHED")
        if [ "$PROFILE_NAME_ATTACHED" != "$PROFILE_NAME" ]; then
            print_yellow "Instance $INSTANCE_ID: Profile '$PROFILE_NAME_ATTACHED' attached. Replacing with '$PROFILE_NAME'."
            # Get association ID
            ASSOC_ID=$(aws ec2 describe-iam-instance-profile-associations --region "$REGION" \
                --filters Name=instance-id,Values="$INSTANCE_ID" \
                --query 'IamInstanceProfileAssociations[0].AssociationId' --output text)
            # Replace profile
            aws ec2 replace-iam-instance-profile-association --region "$REGION" \
                --association-id "$ASSOC_ID" \
                --iam-instance-profile Name="$PROFILE_NAME"
            print_green "  Replaced IAM profile with $PROFILE_NAME for $INSTANCE_ID."
        else
            print_green "Instance $INSTANCE_ID: Already has $PROFILE_NAME attached."
        fi
    fi
done

print_green "Script completed. All EC2 instances are now SSM-enabled."

