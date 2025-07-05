pipeline {
  agent any

  environment {
    STACK_NAME     = 'acit-vpc-stack'
    TEMPLATE_FILE  = 'acit-vpc.yaml'
    REGION         = 'us-east-1'
    ENV_NAME       = 'acit-vpc-two'
    VPC_CIDR       = '10.226.232.0/23'
    KEY_NAME       = 'ec2-user'       // 🔑 Replace with your EC2 key pair
    RESTRICTED_IP  = '100.16.251.45/32'

    // Subnet CIDRs
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

    stage('Install cfn-lint via virtualenv') {
      steps {
        echo '⚙️ Setting up virtual environment for cfn-lint...'
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate && pip install --upgrade pip && pip install cfn-lint
        '''
      }
    }

    stage('Lint CloudFormation Template') {
      steps {
        echo '🔍 Running cfn-lint...'
        sh '''
          . .venv/bin/activate
          .venv/bin/cfn-lint "$TEMPLATE_FILE"
        '''
      }
    }

    stage('Deploy CloudFormation Stack') {
      steps {
        echo '🚀 Deploying ACIT VPC stack via AWS CLI...'
        sh """
          aws cloudformation deploy \
            --stack-name $STACK_NAME \
            --template-file $TEMPLATE_FILE \
            --region $REGION \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides \\
              Environment=$ENV_NAME \\
              VpcCIDR=$VPC_CIDR \\
              ACITWebSubnet1CIDR=$WEB1_CIDR \\
              ACITWebSubnet2CIDR=$WEB2_CIDR \\
              ACITAPPSubnet1CIDR=$APP1_CIDR \\
              ACITAPPSubnet2CIDR=$APP2_CIDR \\
              KeyName=$KEY_NAME \\
              RestrictedIP=$RESTRICTED_IP
        """
      }
    }

    stage('Show EC2 Public IP') {
      steps {
        echo '📡 Fetching EC2 public IP from stack outputs...'
        sh """
          IP=$(aws cloudformation describe-stacks \
            --region $REGION \
            --stack-name $STACK_NAME \
            --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
            --output text)

          echo ""
          echo "🖥️  EC2 Public IP: $IP"
          echo "🔐 SSH Access: ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$IP"
        """
      }
    }
  }

  post {
    always {
      echo '🧹 Cleaning up virtual environment...'
      sh 'rm -rf .venv'
    }
    success {
      echo '✅ Deployment completed successfully!'
    }
    failure {
      echo '❌ Deployment failed. Check error messages above.'
    }
  }
}
