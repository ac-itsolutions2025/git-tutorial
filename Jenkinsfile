pipeline {
  agent any

  environment {
    STACK_NAME     = 'acit-vpc-stack'
    TEMPLATE_FILE  = 'acit-vpc-one.yaml'   // Your file name might differ
    REGION         = 'us-east-1'       // Update if deploying elsewhere

    // Template parameters
    ENVIRONMENT         = 'acit-vpc-two'
    VPC_CIDR            = '10.226.232.0/23'
    WEB1_CIDR           = '10.226.232.0/25'
    WEB2_CIDR           = '10.226.232.128/25'
    APP1_CIDR           = '10.226.233.0/25'
    APP2_CIDR           = '10.226.233.128/25'
    INSTANCE_TYPE       = 't2.micro'
    KEY_NAME            = 'us-east-1-key'       // Replace with your EC2 key pair
    RESTRICTED_IP       = '100.16.251.45/32'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout Source') {
      steps {
        echo 'Pulling CloudFormation template'
        checkout scm
      }
    }

    stage('Lint CloudFormation Template') {
      steps {
        echo 'Linting template with cfn-lint'
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          .venv/bin/pip install --upgrade pip cfn-lint
          .venv/bin/cfn-lint "$TEMPLATE_FILE"
        '''
      }
    }

    stage('Deploy ACIT VPC Stack') {
      steps {
        echo '🚀 Deploying CloudFormation stack for ACIT VPC'
        sh '''
          aws cloudformation deploy \
            --stack-name "$STACK_NAME" \
            --template-file "$TEMPLATE_FILE" \
            --region "$REGION" \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides \
              Environment="$ENVIRONMENT" \
              VpcCIDR="$VPC_CIDR" \
              ACITWebSubnet1CIDR="$WEB1_CIDR" \
              ACITWebSubnet2CIDR="$WEB2_CIDR" \
              ACITAPPSubnet1CIDR="$APP1_CIDR" \
              ACITAPPSubnet2CIDR="$APP2_CIDR" \
              InstanceType="$INSTANCE_TYPE" \
              KeyName="$KEY_NAME" \
              RestrictedIP="$RESTRICTED_IP"
        '''
      }
    }

    stage('Describe Outputs') {
      steps {
        echo '📡 Retrieving outputs from stack'
        sh '''
          aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" \
            --output table
        '''
      }
    }
  }

  post {
    always {
      echo 'Cleaning up...'
      sh 'rm -rf .venv'
    }
    success {
      echo '✅ ACIT VPC deployed successfully!'
    }
    failure {
      echo 'Deployment failed. Review logs for details.'
    }
  }
}
