#!/bin/bash

sts_response=$(aws sts get-session-token --duration-seconds 900)

AWS_ACCESS_KEY_ID=$(echo $sts_response | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $sts_response | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $sts_response | jq -r '.Credentials.SessionToken')

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
