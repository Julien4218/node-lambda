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
    rm deployment-package.zip
fi
zip -r deployment-package.zip .

aws lambda create-function --function-name FUNCTION_NAME \
--zip-file fileb://deployment-package.zip --handler lambda.handler \
--runtime nodejs14.x --role $ROLE_ARN
