#!/bin/bash

# Set default values
S3_BUCKET=${1:-"real-time-chat-lambda-deployment-990064625834"}
STACK_NAME=${2:-"real-time-chat-app"}
REGION=${3:-"us-east-1"}
INSTANCE_TYPE=${4:-"t2.micro"}

echo "Deploying CloudFormation stack with:"
echo "S3 Bucket: $S3_BUCKET"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Instance Type: $INSTANCE_TYPE"

# Create S3 bucket if it doesn't exist
echo "Creating S3 bucket $S3_BUCKET if it doesn't exist..."
aws s3api head-bucket --bucket $S3_BUCKET 2>/dev/null || aws s3 mb s3://$S3_BUCKET --region $REGION

# Package CloudFormation template
echo "Packaging CloudFormation template..."
aws cloudformation package \
    --template-file templates/main.yml \
    --s3-bucket $S3_BUCKET \
    --output-template-file packaged-template.yml

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file packaged-template.yml \
    --stack-name $STACK_NAME \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --parameter-overrides \
        S3BucketName=$S3_BUCKET \
        InstanceType=$INSTANCE_TYPE

# Get outputs
echo "Stack deployment complete. Retrieving outputs..."
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs" \
    --output table

echo "Deployment finished successfully!" 