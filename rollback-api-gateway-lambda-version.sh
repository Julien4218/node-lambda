#!/bin/bash

# AWS credentials required as env variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SESSION_TOKEN) must be set."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <api-name> <stage-name> <path> <method>"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Usage: $0 <api-name> <stage-name> <path> <method>"
    exit 1
fi

if [ -z "$3" ]; then
    echo "Usage: $0 <api-name> <stage-name> <path> <method>"
    exit 1
fi

if [ -z "$4" ]; then
    echo "Usage: $0 <api-name> <stage-name> <path> <method>"
    exit 1
fi
API_NAME=$1
STAGE_NAME=$2
PATH_NAME=$3
METHOD_NAME=$4

# Find API ID
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)
if [ -z "$API_ID" ]; then
    echo "API_ID not found with APINAME:$API_NAME"
    exit 2
else
    echo "Found existing API with ID: $API_ID"
fi

RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='$PATH_NAME'].id" --output text)
if [ -z "$RESOURCE_ID" ]; then
    echo "RESOURCE_ID not found with API_ID:$API_ID, PATH:$PATH_NAME"
    exit 3
else
    echo "Found existing resource with ID: $RESOURCE_ID"
fi

METHOD_INTEGRATION_URI=$(aws apigateway get-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method $METHOD_NAME --query "methodIntegration.uri" --output text)
if [ -z "$METHOD_INTEGRATION_URI" ]; then
    echo "Method Integration URI not found with API_ID:$API_ID, RESOURCE_ID:$RESOURCE_ID, METHOD_NAME:$METHOD_NAME"
    exit 4
else
    echo "Found existing Method Integration URI: $METHOD_INTEGRATION_URI"
fi

LAMBDA_FUNCTION_NAME=$(echo $METHOD_INTEGRATION_URI | awk -F/ '{print $4}' | awk -F: '{print $7}')
if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
    echo "LAMBDA_FUNCTION_NAME not found with METHOD_INTEGRATION_URI:$METHOD_INTEGRATION_URI"
    exit 5
else
    echo "Found existing LAMBDA_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"
fi
LAMBDA_FUNCTION_VERSION=$(echo $METHOD_INTEGRATION_URI | awk -F/ '{print $4}' | awk -F: '{print $8}')
if [ -z "$LAMBDA_FUNCTION_VERSION" ]; then
    echo "LAMBDA_FUNCTION_VERSION not found with METHOD_INTEGRATION_URI:$METHOD_INTEGRATION_URI"
    exit 6
else
    echo "Found existing LAMBDA_FUNCTION_VERSION: $LAMBDA_FUNCTION_VERSION"
fi

PREVIOUS_LAMBDA_FUNCTIONS=$(aws lambda list-versions-by-function --function-name $LAMBDA_FUNCTION_NAME --query "Versions[?Version!='\$LATEST' && Version!='$LAMBDA_FUNCTION_VERSION'].{FunctionArn:FunctionArn, Version:Version}")
if [ -z "$PREVIOUS_LAMBDA_FUNCTIONS" ]; then
    echo "PREVIOUS_LAMBDA_FUNCTIONS not found with LAMBDA_FUNCTION_NAME:$LAMBDA_FUNCTION_NAME, LAMBDA_FUNCTION_VERSION:$LAMBDA_FUNCTION_VERSION"
    exit 7
else
    echo "Found existing PREVIOUS_LAMBDA_FUNCTIONS: $PREVIOUS_LAMBDA_FUNCTIONS"
fi

PREVIOUS_LAMBDA_FUNCTION_VERSION=$(echo $PREVIOUS_LAMBDA_FUNCTIONS | jq -r '.[0].Version')
if [ -z "$PREVIOUS_LAMBDA_FUNCTION_VERSION" ]; then
    echo "PREVIOUS_LAMBDA_FUNCTION_VERSION not found with PREVIOUS_LAMBDA_FUNCTIONS:$PREVIOUS_LAMBDA_FUNCTIONS"
    exit 8
else
    echo "Found existing PREVIOUS_LAMBDA_FUNCTION_VERSION: $PREVIOUS_LAMBDA_FUNCTION_VERSION"
fi

NEW_METHOD_INTEGRATION_URI=$(echo $METHOD_INTEGRATION_URI | sed "s/$LAMBDA_FUNCTION_NAME:$LAMBDA_FUNCTION_VERSION/$LAMBDA_FUNCTION_NAME:$PREVIOUS_LAMBDA_FUNCTION_VERSION/")
if [ -z "$NEW_METHOD_INTEGRATION_URI" ]; then
    echo "NEW_METHOD_INTEGRATION_URI not found with METHOD_INTEGRATION_URI:$METHOD_INTEGRATION_URI, LAMBDA_FUNCTION_NAME:$LAMBDA_FUNCTION_NAME, LAMBDA_FUNCTION_VERSION:$LAMBDA_FUNCTION_VERSION, PREVIOUS_LAMBDA_FUNCTION_VERSION:$PREVIOUS_LAMBDA_FUNCTION_VERSION"
    exit 9
else
    echo "Found existing NEW_METHOD_INTEGRATION_URI: $NEW_METHOD_INTEGRATION_URI"
fi

# Update the integration with previous version
aws apigateway update-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method $METHOD_NAME \
    --patch-operations "[{\"op\":\"replace\",\"path\":\"/uri\",\"value\":\"$NEW_METHOD_INTEGRATION_URI\"}]"
echo "Integration updated successfully with URI: $NEW_METHOD_INTEGRATION_URI"

# Redeploy the API
aws apigateway create-deployment --rest-api-id $API_ID --stage-name $STAGE_NAME
echo "Deployment created successfully with API_ID: $API_ID, STAGE_NAME: $STAGE_NAME"
