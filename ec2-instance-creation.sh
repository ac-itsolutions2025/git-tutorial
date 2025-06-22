#!/bin/bash
set -e

# ======== HARD-CODED CONFIG ========
REGION="us-east-1"
VPC_ID="vpc-0gf04656e45f63chgdf"
SUBNET_ID="subnet-03d42a7f417ehff6"
AMI_ID="ami-06971c49acd68h30"
INSTANCE_TYPE="t2.micro"
KEY_NAME="ec2-user"
SECURITY_GROUP_ID="sg-0e68a412d54606875"
PROFILE_NAME="EC2SSMProfile"
ROLE_NAME="EC2SSMRole1"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
TAG_NAME="TreasureHunt-EC2"
# ===================================

echo " Starting EC2 Treasure Hunt launcher in $REGION..."

# Ensure IAM Role exists
if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
  echo "Creating IAM role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }]
    }'
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
fi

# Ensure Instance Profile exists
if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" &> /dev/null; then
  echo "Creating instance profile $PROFILE_NAME..."
  aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
  sleep 10
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --role-name "$ROLE_NAME"
fi

# Launch EC2 Instance
echo " Launching EC2 instance with embedded treasure hunt clues..."
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
echo " You made it to the end of your journey!" > /opt/treasure/chest.txt
echo "Level 2 unlocked: Proceed to /etc/quest/next.txt" > /opt/treasure/hint.txt
echo "Signed — Captain Cloud " > /etc/quest/note.txt
echo "The final code is 42" > /home/ec2-user/.secret
chown ec2-user:ec2-user /home/ec2-user/.secret
cat <<EOF > /etc/motd
 Welcome to the EC2 Treasure Hunt!
Use your command-line skills wisely and enjoy the adventure!
EOF' \
  --output table
