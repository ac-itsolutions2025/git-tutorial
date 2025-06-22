#!/bin/bash

# ====== Welcome ======
echo "====== EC2 Treasure Hunt Launcher ======"

# Ask for AWS Region first
read -p "Enter AWS Region (e.g., us-east-1): " REGION

# ====== Fetch VPCs ======
echo "Fetching VPCs..."
VPCS=($(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[].VpcId' --output text))
select VPC_ID in "${VPCS[@]}"; do break; done

# ====== Fetch Subnets ======
echo "Fetching Subnets for VPC $VPC_ID..."
SUBNETS=($(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId' --output text))
select SUBNET_ID in "${SUBNETS[@]}"; do break; done

# ====== Fetch Key Pairs ======
echo "Fetching Key Pairs..."
KEYS=($(aws ec2 describe-key-pairs --region "$REGION" \
  --query 'KeyPairs[].KeyName' --output text))
select KEY_NAME in "${KEYS[@]}"; do break; done

# ====== Fetch Security Groups ======
echo "Fetching Security Groups for VPC $VPC_ID..."
SGS=($(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[].GroupId' --output text))
select SECURITY_GROUP_ID in "${SGS[@]}"; do break; done

# ====== Instance Type and AMI ======
read -p "Enter Instance Type (e.g., t2.micro): " INSTANCE_TYPE
read -p "Enter AMI ID (e.g., ami-0abc1234def567890): " AMI_ID
read -p "Enter Name Tag for your EC2 instance: " TAG_NAME

# ====== Launch EC2 Instance ======
echo "Launching EC2 instance..."
aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --iam-instance-profile Name="SSMInstanceProfile" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --user-data '#!/bin/bash
mkdir -p /opt/treasure
mkdir -p /etc/quest
touch /home/ec2-user/.secret

echo "🎉 You made it to the end of your journey!" > /opt/treasure/chest.txt
echo "Level 2 unlocked: Proceed to /etc/quest/next.txt" > /opt/treasure/hint.txt
echo "Signed — Captain Cloud ☁️" > /etc/quest/note.txt
echo "The final code is 42" > /home/ec2-user/.secret

chown ec2-user:ec2-user /home/ec2-user/.secret

cat <<EOF > /etc/motd
🚀 Welcome to the EC2 Treasure Hunt!
Your goal is to uncover secret clues scattered across the system.
Use your command-line skills wisely and enjoy the adventure!
EOF
' \
  --output table

