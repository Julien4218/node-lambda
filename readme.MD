# Inventory API

This project is a Node.js application that provides an API for managing inventory items. It can be run locally for development and testing, and it can be deployed to AWS Lambda.

## Installation

Install the dependencies:

```bash
npm install
```

## Running Tests

To run the unit tests, use the following command:

```bash
npm test
```

## Running the Server Locally

To start the server locally for development testing, use the following command:

```bash
npm start
```

The server will be running on http://localhost:3000.

### Examples

Retrieve all items

```bash
curl -H "Accept: application/json" http://localhost:3000/inventory
```

Get a single item

```bash
curl -H "Accept: application/json" http://localhost:3000/inventory/3
```

## Deploying to AWS Lambda and API Gateway

### Pre-requesite

Create a policy and a role. The policy JSON should be similar to the one below. Update AWS_REGION, ACCOUNT_ID and FUNCTION_NAME with your parameters.

Once done, copy the role ARN.

Permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:<AWS_REGION>:<ACCOUNT_ID>:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:<AWS_REGION>:<ACCOUNT_ID>:log-group:/aws/lambda/<FUNCTION_NAME>:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "lambda:InvokeFunction",
            "Resource": "arn:aws:lambda:<AWS_REGION>:<ACCOUNT_ID>:function:<FUNCTION_NAME>:*"
        }
    ]
}    
```

Trust allowing lambda and api gateway
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "apigateway.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Deploying Lambda

To deploy the application to AWS Lambda, follow these steps:

Ensure you have the necessary AWS credentials set as environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN. If needed run the [set-aws-env.sh](./set-aws-env.sh).

Run the [setup-lambda.sh](./setup-lambda.sh) script with the appropriate arguments:

1. <role-arn>: The ARN of the IAM role that the Lambda function will assume.
2. <function-name>: The name of the Lambda function to create or update.

Update the region with what you used to set the policy and role above.

```bash
AWS_REGION=<region-matching-role> ./setup-lambda.sh <role-arn> <function-name>
```

### Test Event

Using AWS Lambda Test with the following payload to fetch a single inventory item.

```json
{
  "resource": "/inventory/{id}",
  "path": "/inventory/3",
  "httpMethod": "GET",
  "pathParameters": {
    "id": "3"
  }
}
```

### Deploying API Gateway

Run the [setup-api-gateway.sh](./setup-api-gateway.sh) script with the appropriate arguments:

1. <function-name>: The name of the Lambda function to create or update.

Update the region with what you used to set the policy and role above.

```bash
AWS_REGION=<region-matching-role> ./setup-api-gateway.sh <function-name>
```

This will create an API gateway deployment with a `production` stage, and require an `x-api-key` in the request header.

### Test

Once deploy, gather the api key using the AWS console, and the URL from the API Gateway stage. 

Use a curl command in the form:

```bash
curl -H "X-API-KEY: <API_KEY_VALUE>" -X GET "https://<STAGE_HASH>.execute-api.<AWS_REGION>.amazonaws.com/production/inventory/5"
```
