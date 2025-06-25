#!/bin/bash

output_file="ec2_instances.csv"

# Prompt the user
read -p "Choose output format ([c]sv / [t]able): " format
format=$(echo "$format" | tr '[:upper:]' '[:lower:]')

# Validate format
if [[ "$format" != "csv" && "$format" != "c" && "$format" != "table" && "$format" != "t" ]]; then
  echo "Invalid format. Please enter 'csv' or 'table'."
  exit 1
fi

# Get list of AWS regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

# If CSV selected, write header
if [[ "$format" == "csv" || "$format" == "c" ]]; then
  echo "Region,Instance ID,Name,State,Public IP,Private IP" > "$output_file"
else
  printf "%-15s %-20s %-25s %-12s %-15s %-15s\n" "Region" "Instance ID" "Name" "State" "Public IP" "Private IP"
  echo "------------------------------------------------------------------------------------------------------------"
fi

# Loop through all regions and collect instance data
for region in $regions; do
  instances=$(aws ec2 describe-instances --region "$region" \
    --query 'Reservations[*].Instances[*].{ID:InstanceId, Name:Tags[?Key==`Name`]|[0].Value, State:State.Name, PublicIP:PublicIpAddress, PrivateIP:PrivateIpAddress}' \
    --output json)

  echo "$instances" | jq -c '.[][]' | while read -r instance; do
    id=$(echo "$instance" | jq -r '.ID')
    name=$(echo "$instance" | jq -r '.Name // "N/A"')
    state=$(echo "$instance" | jq -r '.State')
    pub_ip=$(echo "$instance" | jq -r '.PublicIP // "N/A"')
    priv_ip=$(echo "$instance" | jq -r '.PrivateIP // "N/A"')

    if [[ "$format" == "csv" || "$format" == "c" ]]; then
      echo "$region,$id,$name,$state,$pub_ip,$priv_ip" >> "$output_file"
    else
      printf "%-15s %-20s %-25s %-12s %-15s %-15s\n" "$region" "$id" "$name" "$state" "$pub_ip" "$priv_ip"
    fi
  done
done

# Wrap-up message
if [[ "$format" == "csv" || "$format" == "c" ]]; then
  echo "Export complete: $(realpath "$output_file")"
fi

