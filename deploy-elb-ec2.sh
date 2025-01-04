#!/bin/bash

# AWS credentials required as env variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_REGION" ]; then
    echo "AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION) must be set."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <ec2 keypair name> <ec2 instance type>"
    exit 1
fi
EC2_KEYNAME=$1

if [ -z "$2" ]; then
    echo "Usage: $0 <ec2 keypair name> <ec2 instance type>"
    exit 2
fi
EC2_INSTANCE_TYPE=$2

# Variables
STACK_NAME="deploy-elb-ec2-$(openssl rand -hex 6)"

AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-arm64-gp2" --query 'Images[*].[ImageId,CreationDate]' --output text | sort -k2 -r | head -n 1 | awk '{print $1}')
if [ -z "$AMI_ID" ]; then
  echo "Error: Unable to find the latest Amazon Linux 2 AMI."
  exit 3
fi
echo "Using AMI ID:$AMI_ID on region:$AWS_REGION"

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
if [ -z "$VPC_ID" ]; then
  echo "Error: Unable to find the default VPC."
  exit 4
fi
echo "Using VPC ID:$VPC_ID"

SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text  | tr '\t' ',')
if [ -z "$SUBNET_IDS" ]; then
  echo "Error: Unable to find the subnets in the default VPC."
  exit 5
fi
echo "Using Subnet IDs:$SUBNET_IDS"

# Create a temporary file for the CloudFormation template with a unique name
TEMPLATE_FILE="./deploy-elb-ec2-cf.json"
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: CloudFormation template file $TEMPLATE_FILE does not exist."
  exit 6
fi

NEW_RELIC_LICENSE_KEY_PATH="/newrelic/node-lambda/license_key"
if [ -n "$NEW_RELIC_LICENSE_KEY" ]; then
  echo "Storing New Relic license key in Parameter Store..."
  aws ssm put-parameter \
    --name "$NEW_RELIC_LICENSE_KEY_PATH" \
    --value "$NEW_RELIC_LICENSE_KEY" \
    --type "SecureString" \
    --overwrite
  if [ $? -eq 0 ]; then
    echo "New Relic license key stored successfully."
  else
    echo "Failed to store New Relic license key."
    exit 7
  fi
else
  echo "NEW_RELIC_LICENSE_KEY environment variable is not set, skipping."
fi

echo "Deploying CloudFormation stack $STACK_NAME with template $TEMPLATE_FILE..."
# Deploy the CloudFormation stack with inline template
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file $TEMPLATE_FILE \
  --region $AWS_REGION \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides KeyName=$EC2_KEYNAME InstanceType=$EC2_INSTANCE_TYPE VpcIc=$VPC_ID SubnetIds=$SUBNET_IDS AmiId=$AMI_ID NewRelicLicenseKeyPath=$NEW_RELIC_LICENSE_KEY_PATH NewRelicAppName=$STACK_NAME

# Check the status of the stack deployment
if [ $? -eq 0 ]; then
  echo "Stack deployment started successfully!"

  # Wait for stack creation to complete
  aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

  if [ $? -eq 0 ]; then
    echo "Stack deployment completed successfully!"
  else
    echo "Stack deployment failed."
  fi
else
  echo "Stack deployment initiation failed."
fi
