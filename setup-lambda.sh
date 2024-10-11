#!/bin/bash

# AWS credentials required as env variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SESSION_TOKEN) must be set."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <role-arn>"
    exit 1
fi
ROLE_ARN=$1

if [ -z "$2" ]; then
    echo "Usage: $0 <role-arn> <function-name>"
    exit 1
fi
FUNCTION_NAME=$2

if [ -f deployment-package.zip ]; then
    echo "Removing old deployment package..."
    rm deployment-package.zip
fi

echo "Creating deployment package..."
zip -r deployment-package.zip . -x ".vscode/*" -x ".git/*" -x "setup*" -x "*test*" -x "node_modules/chai/*" -x "node_modules/mocha/*" -x "node_modules/supertest/*"
echo "Deployment package created."

EXIST=$(aws lambda get-function --function-name $FUNCTION_NAME | grep "FunctionName" | grep $FUNCTION_NAME)
if [ -n "$EXIST" ]; then
    echo "Function $FUNCTION_NAME already exists. Deleting..."
    aws lambda delete-function --function-name $FUNCTION_NAME --region $AWS_REGION
fi
echo "Creating function $FUNCTION_NAME..."    
aws lambda create-function --function-name $FUNCTION_NAME \
--zip-file fileb://deployment-package.zip --handler lambda.handler \
--runtime nodejs20.x --role $ROLE_ARN --region $AWS_REGION
echo "Function $FUNCTION_NAME created."
