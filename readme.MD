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
curl -H "Accept: application/json" http://localhost:3000/api/inventory
```

Get a single item

```bash
curl -H "Accept: application/json" http://localhost:3000/api/inventory/3
```

## Deploying to AWS Lambda

### Pre-requesite

Create a policy and a role. The policy JSON should be similar to the one below. Update AWS_REGION, ACCOUNT_ID and FUNCTION_NAME with your parameters.

Once done, copy the role ARN.

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
            "Resource": "arn:aws:lambda:<AWS_REGION>:<ACCOUNT_ID>:function:<FUNCTION_NAME>"
        }
    ]
}    
```

### Deploying

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
  "resource": "/api/inventory/{id}",
  "path": "/api/inventory/3",
  "httpMethod": "GET",
  "pathParameters": {
    "id": "3"
  }
}
```
