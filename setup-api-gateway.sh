#!/bin/bash

# AWS credentials required as env variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SESSION_TOKEN) must be set."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <lambda-function-name>"
    exit 1
fi
LAMBDA_FUNCTION_NAME=$1

# Validate lambda function exists
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
if [ -z "$LAMBDA_FUNCTION_ARN" ]; then
    echo "Lambda function $LAMBDA_FUNCTION_NAME not found."
    exit 1
fi
LAMBDA_FUNCTION_ROLE_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query 'Configuration.Role' --output text)
if [ -z "$LAMBDA_FUNCTION_ROLE_ARN" ]; then
    echo "Lambda function $LAMBDA_FUNCTION_ROLE_ARN not found."
    exit 1
fi
echo "Lambda function $LAMBDA_FUNCTION_NAME found with ARN: $LAMBDA_FUNCTION_ARN and Role ARN: $LAMBDA_FUNCTION_ROLE_ARN"

API_NAME="$LAMBDA_FUNCTION_NAME-Api"
API_KEY_NAME="$API_NAME-Key"
USAGE_PLAN_NAME="$API_NAME-UsagePlan"
STAGE_NAME="production"

# Find or create API Gateway API
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)
if [ -z "$API_ID" ]; then
    API_ID=$(aws apigateway create-rest-api --name $API_NAME --query 'id' --output text)
    echo "Created new API with ID: $API_ID"
else
    echo "Found existing API with ID: $API_ID"
fi

# Find or create root resource
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text)
if [ -z "$ROOT_ID" ]; then
    ROOT_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $API_ID --path-part "/" --query 'id' --output text)
    echo "Created new root resource with ID: $ROOT_ID"
else
    echo "Found existing root resource with ID: $ROOT_ID"
fi

# Find or create resource for lambda function
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/$LAMBDA_FUNCTION_NAME'].id" --output text)
if [ -z "$RESOURCE_ID" ]; then
    RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part $LAMBDA_FUNCTION_NAME --query 'id' --output text)
    echo "Created new resource with ID: $RESOURCE_ID"
else
    echo "Found existing resource with ID: $RESOURCE_ID"
fi
# Check if the method already exists
METHOD_EXISTS=$(aws apigateway get-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method GET --query 'httpMethod' --output text 2>/dev/null)
if [ "$METHOD_EXISTS" == "GET" ]; then
    echo "Method GET already exists for resource $RESOURCE_ID"
else
    aws apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method GET --authorization-type "NONE" --api-key-required
    echo "Created GET method for resource $RESOURCE_ID"
fi
# Check if the integration already exists
INTEGRATION_URI=$(aws apigateway get-integration --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method GET --query 'uri' --output text 2>/dev/null)
if [ "$INTEGRATION_URI" == "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations" ]; then
    echo "Integration already exists for resource $RESOURCE_ID"
else
    aws apigateway put-integration --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method GET --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations" --credentials $LAMBDA_FUNCTION_ROLE_ARN
    echo "Created integration for resource $RESOURCE_ID"
fi

# Create resource for fetching item by ID
INVENTORY_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/$LAMBDA_FUNCTION_NAME/{id}'].id" --output text)
if [ -z "$INVENTORY_RESOURCE_ID" ]; then
    INVENTORY_RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $RESOURCE_ID --path-part "{id}" --query 'id' --output text)
    echo "Created new resource for inventory with ID: $INVENTORY_RESOURCE_ID"
else
    echo "Found existing resource for inventory with ID: $INVENTORY_RESOURCE_ID"
fi
# Create method for fetching item by ID
METHOD_EXISTS=$(aws apigateway get-method --rest-api-id $API_ID --resource-id $INVENTORY_RESOURCE_ID --http-method GET --query 'httpMethod' --output text 2>/dev/null)
if [ "$METHOD_EXISTS" == "GET" ]; then
    echo "Method GET already exists for inventory resource $INVENTORY_RESOURCE_ID"
else
    aws apigateway put-method --rest-api-id $API_ID --resource-id $INVENTORY_RESOURCE_ID --http-method GET --authorization-type "NONE" --api-key-required
    echo "Created GET method for inventory resource $INVENTORY_RESOURCE_ID"
fi
# Create integration for fetching item by ID
INTEGRATION_URI=$(aws apigateway get-integration --rest-api-id $API_ID --resource-id $INVENTORY_RESOURCE_ID --http-method GET --query 'uri' --output text 2>/dev/null)
if [ "$INTEGRATION_URI" == "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations" ]; then
    echo "Integration already exists for inventory resource $INVENTORY_RESOURCE_ID"
else
    aws apigateway put-integration --rest-api-id $API_ID --resource-id $INVENTORY_RESOURCE_ID --http-method GET --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations" --credentials $LAMBDA_FUNCTION_ROLE_ARN
    echo "Created integration for inventory resource $INVENTORY_RESOURCE_ID"
fi

# Check if deployment already exists
DEPLOYMENT_EXISTS=$(aws apigateway get-deployments --rest-api-id $API_ID --query "items[?stageName=='$STAGE_NAME'].id" --output text)
if [ -z "$DEPLOYMENT_EXISTS" ]; then
    aws apigateway create-deployment --rest-api-id $API_ID --stage-name $STAGE_NAME
    echo "Created new deployment for stage $STAGE_NAME"
else
    echo "Deployment already exists for stage $STAGE_NAME"
fi

# Check if API Key already exists
API_KEY_ID=$(aws apigateway get-api-keys --name-query $API_KEY_NAME --query "items[?name=='$API_KEY_NAME'].id" --output text)
if [ -z "$API_KEY_ID" ]; then
    API_KEY_ID=$(aws apigateway create-api-key --name $API_KEY_NAME --enabled --query 'id' --output text)
    echo "Created new API Key with ID: $API_KEY_ID"
else
    echo "Found existing API Key with ID: $API_KEY_ID"
fi

# Create Usage Plan
USAGE_PLAN_ID=$(aws apigateway get-usage-plans --query "items[?name=='$USAGE_PLAN_NAME'].id" --output text)
if [ -z "$USAGE_PLAN_ID" ]; then
    USAGE_PLAN_ID=$(aws apigateway create-usage-plan --name $USAGE_PLAN_NAME --throttle burstLimit=10,rateLimit=10 --api-stages apiId=$API_ID,stage=$STAGE_NAME --query 'id' --output text)
    echo "Created new Usage Plan with ID: $USAGE_PLAN_ID"
else
    echo "Found existing Usage Plan with ID: $USAGE_PLAN_ID"
    aws apigateway update-usage-plan --usage-plan-id $USAGE_PLAN_ID --patch-operations op=replace,path=/throttle/burstLimit,value=10 op=replace,path=/throttle/rateLimit,value=10
    echo "Updated existing Usage Plan with ID: $USAGE_PLAN_ID"
fi

# Check if the API Key is already associated with the Usage Plan
USAGE_PLAN_KEY_EXISTS=$(aws apigateway get-usage-plan-keys --usage-plan-id $USAGE_PLAN_ID --query "items[?id=='$API_KEY_ID'].id" --output text)
if [ -z "$USAGE_PLAN_KEY_EXISTS" ]; then
    USAGE_PLAN_OUTPUT=$(aws apigateway create-usage-plan-key --usage-plan-id $USAGE_PLAN_ID --key-type API_KEY --key-id $API_KEY_ID)
    echo "Associated API Key with Usage Plan"
else
    echo "API Key is already associated with the Usage Plan"
fi

