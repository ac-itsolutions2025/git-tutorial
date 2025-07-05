pipeline {
  agent any

  environment {
    STACK_NAME     = 'acit-vpc-stack'
    TEMPLATE_FILE  = 'acit-vpc.yaml'
    REGION         = 'us-east-1'
    ENV_NAME       = 'acit-vpc-two'
    VPC_CIDR       = '10.226.232.0/23'
    KEY_NAME       = 'ec2-user'       // <-- Replace with your EC2 key pair
    RESTRICTED_IP  = '100.16.251.45/32'

    # Subnet CIDRs
    WEB1_CIDR = '10.226.232.0/25'
    WEB2_CIDR = '10.226.232.128/25'
    APP1_CIDR = '10.226.233.0/25'
    APP2_CIDR = '10.226.233.128/25'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {

    stage('Lint Template') {
      steps {
        echo '🔍 Linting CloudFormation template...'
        sh 'cfn-lint $TEMPLATE_FILE'
      }
    }

    stage('Deploy Stack') {
      steps {
        echo '🚀 Deploying ACIT VPC CloudFormation stack...'
        sh """
          aws cloudformation deploy \
            --stack-name $STACK_NAME \
            --template-file $TEMPLATE_FILE \
            --region $REGION \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides \
              Environment=$ENV_NAME \
              VpcCIDR=$VPC_CIDR \
              ACITWebSubnet1CIDR=$WEB1_CIDR \
              ACITWebSubnet2CIDR=$WEB2_CIDR \
              ACITAPPSubnet1CIDR=$APP1_CIDR \
              ACITAPPSubnet2CIDR=$APP2_CIDR \
              KeyName=$KEY_NAME \
              RestrictedIP=$RESTRICTED_IP
        """
      }
    }

    stage('Fetch Public IP') {
      steps {
        echo '📡 Retrieving EC2 public IP...'
        sh """
          IP=$(aws cloudformation describe-stacks \
            --region $REGION \
            --stack-name $STACK_NAME \
            --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
            --output text)

          echo "🖥️  EC2 Public IP: \$IP"
          echo "🔐 Connect via: ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@\$IP"
        """
      }
    }
  }

  post {
    success {
      echo '✅ ACIT VPC Stack deployed successfully!'
    }
    failure {
      echo '❌ Deployment failed. Check logs and parameters.'
    }
  }
}
