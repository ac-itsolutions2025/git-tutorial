pipeline {
  agent any
  
  environment {
    STACK_NAME     = 'acit-vpc-stack'
    TEMPLATE_FILE  = 'acit-vpc.yaml'
    REGION         = 'us-east-1'
    ENV_NAME       = 'acit-vpc-two'
    VPC_CIDR       = '10.226.232.0/23'
    RESTRICTED_IP  = '100.16.251.45/32'
    
    // Subnet CIDRs
    WEB1_CIDR = '10.226.232.0/25'
    WEB2_CIDR = '10.226.232.128/25'
    APP1_CIDR = '10.226.233.0/25'
    APP2_CIDR = '10.226.233.128/25'
    
    // AWS CLI settings
    AWS_DEFAULT_REGION = "${REGION}"
    AWS_DEFAULT_OUTPUT = 'text'
  }
  
  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 30, unit: 'MINUTES')
    ansiColor('xterm')
  }
  
  stages {
    stage('Checkout from Git') {
      steps {
        echo '📦 Pulling latest code from Git'
        checkout scm
      }
    }
    
    stage('Validate Prerequisites') {
      steps {
        echo '🔍 Validating prerequisites and AWS connectivity'
        script {
          // Check if template file exists
          if (!fileExists(env.TEMPLATE_FILE)) {
            error "❌ CloudFormation template file '${env.TEMPLATE_FILE}' not found!"
          }
          
          // Test AWS connectivity
          sh '''
            echo "Testing AWS connectivity..."
            aws sts get-caller-identity --region "$REGION" || {
              echo "❌ AWS CLI not configured or no permissions"
              exit 1
            }
            echo "✅ AWS connectivity verified"
          '''
        }
      }
    }
    
    stage('Setup Virtual Environment') {
      steps {
        echo '⚙️ Creating Python virtual environment and installing cfn-lint'
        sh '''
          # Clean up any existing virtual environment
          rm -rf .venv
          
          # Create new virtual environment
          python3 -m venv .venv
          . .venv/bin/activate
          
          # Upgrade pip and install cfn-lint
          .venv/bin/pip install --upgrade pip
          .venv/bin/pip install cfn-lint boto3
          
          echo "✅ Virtual environment setup complete"
        '''
      }
    }
    
    stage('Validate CloudFormation Template') {
      parallel {
        stage('Lint Template') {
          steps {
            echo '🔍 Linting CloudFormation template'
            sh '''
              . .venv/bin/activate
              .venv/bin/cfn-lint --template "$TEMPLATE_FILE" --format parseable
            '''
          }
        }
        stage('Validate Template Syntax') {
          steps {
            echo '✅ Validating CloudFormation template syntax'
            sh '''
              aws cloudformation validate-template \
                --template-body file://"$TEMPLATE_FILE" \
                --region "$REGION"
            '''
          }
        }
      }
    }
    
    stage('Check Stack Status') {
      steps {
        echo '📊 Checking current stack status'
        script {
          def stackExists = sh(
            script: '''
              aws cloudformation describe-stacks \
                --stack-name "$STACK_NAME" \
                --region "$REGION" \
                --query "Stacks[0].StackStatus" \
                --output text 2>/dev/null || echo "DOES_NOT_EXIST"
            ''',
            returnStdout: true
          ).trim()
          
          if (stackExists != "DOES_NOT_EXIST") {
            echo "📋 Stack exists with status: ${stackExists}"
            env.STACK_EXISTS = "true"
          } else {
            echo "📋 Stack does not exist - will create new stack"
            env.STACK_EXISTS = "false"
          }
        }
      }
    }
    
    stage('Deploy CloudFormation Stack') {
      steps {
        echo '🚀 Deploying ACIT VPC CloudFormation stack...'
        script {
          // Get EC2 key pair name from Jenkins credentials
          withCredentials([string(credentialsId: 'ec2-keypair-name', variable: 'KEY_NAME')]) {
            sh '''
              # Deploy with retry logic
              for i in {1..3}; do
                echo "Deployment attempt $i/3"
                
                if aws cloudformation deploy \
                  --stack-name "$STACK_NAME" \
                  --template-file "$TEMPLATE_FILE" \
                  --region "$REGION" \
                  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
                  --parameter-overrides \
                    Environment="$ENV_NAME" \
                    VpcCIDR="$VPC_CIDR" \
                    ACITWebSubnet1CIDR="$WEB1_CIDR" \
                    ACITWebSubnet2CIDR="$WEB2_CIDR" \
                    ACITAPPSubnet1CIDR="$APP1_CIDR" \
                    ACITAPPSubnet2CIDR="$APP2_CIDR" \
                    KeyName="$KEY_NAME" \
                    RestrictedIP="$RESTRICTED_IP" \
                  --no-fail-on-empty-changeset; then
                  echo "✅ Deployment successful"
                  break
                else
                  echo "❌ Deployment attempt $i failed"
                  if [ $i -eq 3 ]; then
                    echo "❌ All deployment attempts failed"
                    exit 1
                  fi
                  echo "⏳ Waiting 30 seconds before retry..."
                  sleep 30
                fi
              done
            '''
          }
        }
      }
    }
    
    stage('Fetch Stack Outputs') {
      steps {
        echo '📡 Retrieving stack outputs...'
        script {
          sh '''
            echo "📋 Stack Outputs:"
            echo "=================="
            
            # Get all stack outputs
            aws cloudformation describe-stacks \
              --region "$REGION" \
              --stack-name "$STACK_NAME" \
              --query "Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]" \
              --output table
            
            # Try to get specific outputs
            PUBLIC_IP=$(aws cloudformation describe-stacks \
              --region "$REGION" \
              --stack-name "$STACK_NAME" \
              --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
              --output text 2>/dev/null || echo "Not Available")
            
            VPC_ID=$(aws cloudformation describe-stacks \
              --region "$REGION" \
              --stack-name "$STACK_NAME" \
              --query "Stacks[0].Outputs[?OutputKey=='VpcId' || OutputKey=='VPC'].OutputValue" \
              --output text 2>/dev/null || echo "Not Available")
            
            echo ""
            echo "🔑 Key Information:"
            echo "==================="
            echo "🖥️  EC2 Public IP: $PUBLIC_IP"
            echo "🌐 VPC ID: $VPC_ID"
            echo "🗺️  Region: $REGION"
            
            if [ "$PUBLIC_IP" != "Not Available" ]; then
              echo ""
              echo "🔐 SSH Access Commands:"
              echo "======================="
              echo "ssh -i ~/.ssh/\$KEY_NAME.pem ec2-user@$PUBLIC_IP"
              echo "ssh -i ~/.ssh/\$KEY_NAME.pem ubuntu@$PUBLIC_IP"
            fi
          '''
        }
      }
    }
    
    stage('Verify Deployment') {
      steps {
        echo '🔍 Verifying deployment health'
        sh '''
          # Check stack status
          STACK_STATUS=$(aws cloudformation describe-stacks \
            --region "$REGION" \
            --stack-name "$STACK_NAME" \
            --query "Stacks[0].StackStatus" \
            --output text)
          
          echo "📊 Final Stack Status: $STACK_STATUS"
          
          if [[ "$STACK_STATUS" == *"COMPLETE"* ]]; then
            echo "✅ Stack deployment completed successfully"
          else
            echo "❌ Stack deployment may have issues"
            exit 1
          fi
        '''
      }
    }
  }
  
  post {
    always {
      echo '🧹 Cleaning up resources'
      sh '''
        # Clean up virtual environment
        rm -rf .venv
        
        # Clean up any temporary files
        rm -f /tmp/cfn-lint-*.tmp 2>/dev/null || true
      '''
    }
    success {
      echo '✅ ACIT VPC Stack deployed successfully!'
      script {
        // Optional: Send success notification
        if (env.SLACK_WEBHOOK) {
          sh '''
            curl -X POST -H 'Content-type: application/json' \
              --data "{\\"text\\":\\"✅ ACIT VPC Stack '${STACK_NAME}' deployed successfully in ${REGION}\\"}" \
              "$SLACK_WEBHOOK"
          '''
        }
      }
    }
    failure {
      echo '❌ Deployment failed. Check the error output above.'
      script {
        // Get stack events for debugging
        sh '''
          echo "📋 Recent Stack Events (last 10):"
          aws cloudformation describe-stack-events \
            --region "$REGION" \
            --stack-name "$STACK_NAME" \
            --query "StackEvents[0:9].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]" \
            --output table 2>/dev/null || echo "Could not retrieve stack events"
        '''
        
        // Optional: Send failure notification
        if (env.SLACK_WEBHOOK) {
          sh '''
            curl -X POST -H 'Content-type: application/json' \
              --data "{\\"text\\":\\"❌ ACIT VPC Stack '${STACK_NAME}' deployment failed in ${REGION}. Check Jenkins logs.\\"}" \
              "$SLACK_WEBHOOK"
          '''
        }
      }
    }
    unstable {
      echo '⚠️ Deployment completed with warnings'
    }
    cleanup {
      echo '🔄 Pipeline cleanup completed'
    }
  }
}
