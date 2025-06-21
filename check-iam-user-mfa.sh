#!/bin/bash

set -euo pipefail

# Color functions
print_red()   { echo -e "\e[31m$1\e[0m"; }
print_green() { echo -e "\e[32m$1\e[0m"; }
print_yellow(){ echo -e "\e[33m$1\e[0m"; }

command -v aws >/dev/null 2>&1 || { print_red "aws CLI is required. Exiting."; exit 1; }
command -v jq  >/dev/null 2>&1 || { print_red "jq is required. Exiting."; exit 1; }

echo "Retrieving all IAM users..."

mapfile -t IAM_USERS < <(aws iam list-users --query 'Users[].UserName' --output text | tr '\t' '\n')

if [ ${#IAM_USERS[@]} -eq 0 ]; then
    print_yellow "No IAM users found in your AWS account."
    exit 0
fi

USERS_WITHOUT_MFA=()

for USER in "${IAM_USERS[@]}"; do
    MFA_COUNT=$(aws iam list-mfa-devices --user-name "$USER" --query 'MFADevices' --output json | jq 'length')
    if [ "$MFA_COUNT" -eq 0 ]; then
        USERS_WITHOUT_MFA+=("$USER")
    fi
done

if [ ${#USERS_WITHOUT_MFA[@]} -eq 0 ]; then
    print_green "All IAM users have at least one MFA device enabled."
else
    print_red "The following IAM users do NOT have MFA enabled:"
    for USER in "${USERS_WITHOUT_MFA[@]}"; do
        echo " - $USER"
    done
fi

