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
TEMPLATE_FILE=$(mktemp /tmp/template.${STACK_NAME}.XXXXXXXX.yaml)

# Inline CloudFormation template (YAML format)
cat > $TEMPLATE_FILE << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation template to provision an EC2 instance with a Node.js application deployed from GitHub and an ELB to route traffic

Parameters:
  KeyName:
    Description: Name of an existing EC2 KeyPair to enable SSH access to the instance
    Type: String

  InstanceType:
    Description: EC2 instance type
    Type: String
    Default: t4g.nano
    AllowedValues:
      - t4g.nano
      - t4g.micro
      - t4g.small
    ConstraintDescription: Must be a valid Graviton instance type.

  VpcIc:
    Description: The ID of the default VPC
    Type: AWS::EC2::VPC::Id

  SubnetIds:
    Description: The subnets in the default VPC
    Type: String

  AmiId:
    Description: The ID of the AMI to use for the EC2 instance
    Type: String

Resources:
  EC2Instance:
    Type: 'AWS::EC2::Instance'
    Properties:
      InstanceType: !Ref InstanceType
      KeyName: !Ref KeyName
      ImageId: !Ref AmiId
      IamInstanceProfile: !Ref Ec2NodeInstanceProfile
      SecurityGroupIds:
        - !Ref InstanceSecurityGroup
      SubnetId: !Select [0, !Split [",", !Ref SubnetIds]]
      UserData:
        Fn::Base64:
          !Sub |
            #!/bin/bash
            yum update -y

            curl -sL https://rpm.nodesource.com/setup_14.x | bash -

            yum install -y nodejs git httpd

            cd /home/ec2-user
            git clone https://github.com/Julien4218/node-lambda.git node-service
            cd node-service
            npm install

            cat << EOF > /etc/systemd/system/node-service.service
            [Unit]
            Description=Node.js Inventory Application
            After=network.target

            [Service]
            ExecStart=/usr/bin/node /home/ec2-user/node-service/local.mjs
            Restart=always
            User=ec2-user
            Environment=PATH=/usr/bin:/usr/local/bin
            WorkingDirectory=/home/ec2-user/node-service

            [Install]
            WantedBy=multi-user.target
            EOF

            systemctl daemon-reload
            systemctl enable node-service.service
            systemctl start node-service.service

  InstanceSecurityGroup:
    Type: 'AWS::EC2::SecurityGroup'
    Properties:
      GroupDescription: Enable SSH and HTTP access
      VpcId: !Ref VpcIc
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 3000
          ToPort: 3000
          CidrIp: 0.0.0.0/0

  Ec2NodeInstanceProfile:
    Type: 'AWS::IAM::InstanceProfile'
    Properties:
      Roles:
        - !Ref EC2Role

  EC2Role:
    Type: 'AWS::IAM::Role'
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - ec2.amazonaws.com
            Action:
              - sts:AssumeRole

  LoadBalancer:
    Type: 'AWS::ElasticLoadBalancing::LoadBalancer'
    Properties:
      CrossZone: true
      Listeners:
        - LoadBalancerPort: '80'
          InstancePort: '3000'
          Protocol: 'HTTP'
      HealthCheck:
        Target: 'HTTP:3000/status'
        HealthyThreshold: '3'
        UnhealthyThreshold: '5'
        Interval: '30'
        Timeout: '5'
      SecurityGroups:
        - !Ref LoadBalancerSecurityGroup
      Subnets: !Split [",", !Ref SubnetIds]
      Instances:
        - !Ref EC2Instance

  LoadBalancerSecurityGroup:
    Type: 'AWS::EC2::SecurityGroup'
    Properties:
      GroupDescription: Enable HTTP access to the load balancer
      VpcId: !Ref VpcIc
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 3000
          CidrIp: 0.0.0.0/0

Outputs:
  InstanceId:
    Description: Instance ID of the newly created EC2 instance
    Value: !Ref EC2Instance

  LoadBalancerDNSName:
    Description: DNS name of the load balancer
    Value: !GetAtt LoadBalancer.DNSName
EOF
echo "CloudFormation template created: $TEMPLATE_FILE"

# Deploy the CloudFormation stack with inline template
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file $TEMPLATE_FILE \
  --region $AWS_REGION \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides KeyName=$EC2_KEYNAME InstanceType=$EC2_INSTANCE_TYPE VpcIc=$VPC_ID SubnetIds=$SUBNET_IDS AmiId=$AMI_ID

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

rm $TEMPLATE_FILE
