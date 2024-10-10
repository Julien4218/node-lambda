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

To deploy the application to AWS Lambda, follow these steps:

Ensure you have the necessary AWS credentials set as environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SESSION_TOKEN

Run the setup-lambda.sh script with the appropriate arguments:

1. <role-arn>: The ARN of the IAM role that the Lambda function will assume.
2. <function-name>: The name of the Lambda function to create or update.

```bash
./setup-lambda.sh <role-arn> <function-name>
```
