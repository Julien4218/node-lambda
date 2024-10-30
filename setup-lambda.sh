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

# Package the lambda function
echo "Creating deployment package..."
zip -r deployment-package.zip . -x ".vscode/*" -x ".git/*" -x "setup*" -x "*test*" -x "node_modules/chai/*" -x "node_modules/mocha/*" -x "node_modules/supertest/*"
echo "Deployment package created."

# Check and remove any previous lambda function
EXIST=$(aws lambda get-function --function-name $FUNCTION_NAME | grep "FunctionName" | grep $FUNCTION_NAME)
if [ -n "$EXIST" ]; then
    # Update the lambda function
    echo "Function $FUNCTION_NAME already exists. Updating..."
    aws lambda update-function-code --function-name $FUNCTION_NAME --region $AWS_REGION --zip-file fileb://deployment-package.zip
else
    # Create the lambda function
    echo "Function $FUNCTION_NAME does not exist."
    echo "Creating function $FUNCTION_NAME..."    
    aws lambda create-function --function-name $FUNCTION_NAME --region $AWS_REGION \
        --zip-file fileb://deployment-package.zip --handler lambda.handler \
        --runtime nodejs20.x --role $ROLE_ARN
    echo "Function $FUNCTION_NAME created."
fi

# Publish new version
MAX_RETRIES=30
RETRY_DELAY_SECONDS=10
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Waiting $RETRY_DELAY_SECONDS seconds for the function to be created or updated before publishing..."
    sleep $RETRY_DELAY_SECONDS
    echo "Attempt $i to publish version..."
    result=$(aws lambda publish-version --function-name $FUNCTION_NAME 2>&1)
    if [[ $result == *"ResourceConflictException"* ]]; then
        echo "Resource conflict detected. Retrying in $RETRY_DELAY_SECONDS seconds..."
        sleep $RETRY_DELAY_SECONDS
    else
        echo "Version published successfully!"
        break
    fi
    if [[ $i -eq $MAX_RETRIES ]]; then
        echo "Max retries reached. Exiting with error."
        exit 1
    fi
done
