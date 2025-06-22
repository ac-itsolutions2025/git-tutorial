#!/bin/bash

set -e

PROFILE_NAME="EC2SSMProfile"
ROLE_NAME="EC2SSMRole"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

echo "====== EC2 Treasure Hunt Launcher ======"

read -p "Enter AWS Region (e.g., us-east-1): " REGION

# Check or create IAM Role
echo "Checking for IAM role $ROLE_NAME..."
if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
  echo "Creating IAM role..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[
        {
          "Effect":"Allow",
          "Principal":{"Service":"ec2.amazonaws.com"},
          "Action":"sts:AssumeRole"
        }
      ]
    }'
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
fi

# Check or create Instance Profile
echo "Checking for instance profile $PROFILE_NAME..."
if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" &> /dev/null; then
  echo "Creating instance profile..."
  aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
  sleep 10  # Wait for propagation
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --role-name "$ROLE_NAME"
fi

# Interactive inputs
VPCS=($(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[].VpcId' --output text))
echo "Select a VPC:"
select VPC_ID in "${VPCS[@]}"; do break; done

SUBNETS=($(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text))
echo "Select a Subnet:"
select SUBNET_ID in "${SUBNETS[@]}"; do break; done

KEYS=($(aws ec2 describe-key-pairs --region "$REGION" --query 'KeyPairs[].KeyName' --output text))
echo "Select a Key Pair:"
select KEY_NAME in "${KEYS[@]}"; do break; done

SGS=($(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[].GroupId' --output text))
echo "Select a Security Group:"
select SECURITY_GROUP_ID in "${SGS[@]}"; do break; done

read -p "Enter Instance Type (e.g., t2.micro): " INSTANCE_TYPE
read -p "Enter AMI ID (e.g., ami-0abc1234def567890): " AMI_ID
read -p "Enter EC2 Name Tag: " TAG_NAME

# Launch EC2
aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --iam-instance-profile Name="$PROFILE_NAME" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --user-data '#!/bin/bash
mkdir -p /opt/treasure /etc/quest
touch /home/ec2-user/.secret
echo "🎉 You made it to the end of your journey!" > /opt/treasure/chest.txt
echo "Level 2 unlocked: Proceed to /etc/quest/next.txt" > /opt/treasure/hint.txt
echo "Signed — Captain Cloud ☁️" > /etc/quest/note.txt
echo "The final code is 42" > /home/ec2-user/.secret
chown ec2-user:ec2-user /home/ec2-user/.secret
cat <<EOF > /etc/motd
🚀 Welcome to the EC2 Treasure Hunt!
Use your command-line skills wisely and enjoy the adventure!
EOF' \
  --output table
