# Real-Time Chat Application Deployment Guide

This guide provides instructions for deploying the Real-Time Chat Application with Sentiment Analysis in AWS Academy environments.

## Overview

The Real-Time Chat Application is a web-based chat application that analyzes sentiment in messages in real-time. The application is built using AWS services:

- **AWS API Gateway WebSocket API**: For real-time communication
- **AWS Lambda**: For serverless processing of messages and connections
- **Amazon DynamoDB**: For storing messages and connection data
- **Amazon S3**: For hosting the frontend files

## Deployment Options

There are two deployment options available:

1. **Manual Deployment**: Recommended for AWS Academy environments, this approach involves manual steps through the AWS Console.
2. **Automated Deployment**: Requires configured AWS CLI credentials, this approach uses script automation.

## Prerequisites

- AWS Academy account
- AWS CLI (if using automated deployment)
- PowerShell 5.0 or later

## Deployment Method 1: Manual Deployment (Recommended for AWS Academy)

The manual deployment approach is the simplest and most reliable method for AWS Academy environments:

1. Run the manual deployment script:
   ```powershell
   ./deploy_manual.ps1
   ```

2. Follow the instructions in the script:
   - Log in to AWS Academy
   - Create an S3 bucket
   - Enable static website hosting
   - Set bucket permissions
   - Upload the frontend files
   - Access the website

This approach deploys the frontend in "demo mode", which simulates the backend functionality.

## Deployment Method 2: Automated Deployment (For Configured AWS CLI)

If you have AWS CLI properly configured with the necessary credentials, you can use the automated deployment approach:

### Step 1: Package Lambda Functions

The Lambda functions have already been packaged and placed in the `deployment` directory:

- `connection_manager.zip`: Python Lambda for managing WebSocket connections
- `message_processor.zip`: Node.js Lambda for processing and analyzing messages
- `default_handler.zip`: Node.js Lambda for handling default routes

### Step 2: Upload Lambda Functions

Use the provided script to upload the Lambda function packages to an S3 bucket:

```powershell
./upload_lambda_functions.ps1 -S3BucketName "your-unique-bucket-name" -Region "us-east-1"
```

### Step 3: Deploy CloudFormation Stack

Deploy the CloudFormation stack using the provided script:

```powershell
./deploy_cloudformation.ps1 -Region "us-east-1" -S3BucketName "your-unique-bucket-name" -UseLabMode $true
```

The `-UseLabMode` parameter ensures compatibility with AWS Academy by using the LabRole for permissions.

### Step 4: Upload Frontend Files

Upload the frontend files to the S3 bucket:

```powershell
./upload_frontend_simple.ps1 -S3BucketName "your-unique-bucket-name" -Region "us-east-1"
```

## Testing the Application

After deployment, you can test the application by:

1. Opening the frontend URL in a web browser (provided in the script output)
2. Entering a username
3. Sending messages to see sentiment analysis in action

## Troubleshooting

### Common Issues:

1. **AWS CLI Credential Issues**:
   - If you encounter credential errors, follow the manual deployment approach.

2. **S3 Bucket Already Exists**:
   - S3 bucket names are globally unique; choose a different name if you encounter this error.

3. **Permission Errors**:
   - AWS Academy has restrictions on some IAM operations; ensure you're using the `-UseLabMode $true` parameter with `deploy_cloudformation.ps1`.

4. **Frontend Not Loading**:
   - Ensure static website hosting is enabled on the S3 bucket.
   - Check that the bucket policy allows public read access.
   - Verify that index.html has the correct content type (text/html).

## Project Structure

```
├── deployment/                     # Packaged Lambda functions
│   ├── connection_manager.zip
│   ├── message_processor.zip
│   └── default_handler.zip
├── infrastructure/                 # CloudFormation templates
│   └── cloudformation/
│       ├── main-template.yml
│       └── main-template-labmode.yml
├── lambda/                         # Lambda function source code
│   └── functions/
│       ├── connection_manager.py
│       ├── message_processor.js
│       ├── default_handler.js
│       ├── requirements.txt
│       └── package.json
├── lambda_packages/                # Temporary packaging directory
├── src/                            # Source code
│   └── frontend/
│       └── index.html
├── deploy_cloudformation.ps1       # CloudFormation deployment script
├── deploy_manual.ps1               # Manual deployment guide script
├── package_lambda.ps1              # Lambda packaging script
├── upload_frontend_simple.ps1      # Frontend upload script
├── upload_lambda_functions.ps1     # Lambda function upload script
└── DEPLOYMENT_README.md            # This file
```

## Notes for AWS Academy Users

Due to AWS Academy Lab environment restrictions:
- Limited IAM permissions may prevent certain automated deployments
- Some AWS CLI operations may fail due to credential configuration
- The manual deployment approach is recommended for most AWS Academy users

## Additional Resources

- See `IAC_README.md` for Infrastructure as Code details
- See `TESTING_GUIDE.md` for testing instructions 