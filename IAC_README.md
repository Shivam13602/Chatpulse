# Infrastructure as Code (IaC) Deployment 

This guide explains how to deploy the Real-Time Chat Application with Sentiment Analysis using AWS CloudFormation.

## Prerequisites

Before you begin, make sure you have:

1. AWS CLI installed and configured with appropriate credentials
2. PowerShell (Windows) or bash (Linux/macOS)
3. Python 3.9+ and pip
4. Node.js 16+ and npm

For AWS Academy Lab users:
- Make sure your AWS Academy Lab is started
- Configure AWS CLI with the credentials provided by AWS Academy

## Deployment Scripts

This project includes the following deployment scripts:

1. `package_lambda.ps1` - Packages Lambda functions into ZIP files
2. `deploy_cloudformation.ps1` - Deploys the CloudFormation stack
3. `upload_frontend.ps1` - Uploads frontend files to the S3 bucket

## Deployment Steps

### Step 1: Package Lambda Functions

Run the Lambda packaging script:

```powershell
./package_lambda.ps1
```

This will create ZIP files for each Lambda function in the `deployment` directory with all necessary dependencies.

### Step 2: Deploy CloudFormation Stack

Run the CloudFormation deployment script:

```powershell
./deploy_cloudformation.ps1 -Region "us-east-1" -S3BucketName "your-unique-bucket-name" -EnvironmentName "Dev" -StackName "RealTimeChat" -UseLabMode $true
```

Parameters:
- `-Region`: AWS region to deploy to (e.g., "us-east-1")
- `-S3BucketName`: Unique S3 bucket name for deployment artifacts and frontend hosting
- `-EnvironmentName`: (Optional) Environment name for resource naming (Default: "Dev")
- `-StackName`: (Optional) Name for the CloudFormation stack (Default: "RealTimeChat")
- `-UseLabMode`: (Optional) Set to $true to use AWS Academy Lab Role (Default: $true)

### Step 3: Upload Frontend Files

After the CloudFormation stack is successfully deployed, upload the frontend files:

```powershell
./upload_frontend.ps1 -S3BucketName "your-unique-bucket-name" -Region "us-east-1"
```

Parameters:
- `-S3BucketName`: S3 bucket created by CloudFormation
- `-Region`: (Optional) AWS region (Default: "us-east-1")
- `-FrontendPath`: (Optional) Path to frontend files (Default: "src/frontend")

## Architecture

The CloudFormation template deploys the following AWS resources:

1. **API Gateway WebSocket API** - Handles real-time chat communication
2. **Lambda Functions**:
   - `connection_manager` - Handles WebSocket connections and disconnections
   - `message_processor` - Processes messages and performs sentiment analysis
   - `default_handler` - Handles unknown WebSocket routes
3. **DynamoDB Tables**:
   - `ConnectionsTable` - Stores active WebSocket connections
   - `MessagesTable` - Stores chat messages with sentiment scores
4. **S3 Bucket** - Hosts the frontend application and deployment artifacts

## For AWS Academy Users

When deploying in AWS Academy, the `UseLabMode` parameter should be set to `$true`. This uses the CloudFormation template that leverages the existing LabRole instead of creating custom IAM roles, which may not be permitted in AWS Academy environments.

## Troubleshooting

### Common Issues:

1. **S3 Bucket Creation Fails**
   - S3 bucket names must be globally unique
   - Try a more unique bucket name

2. **IAM Permissions in AWS Academy**
   - AWS Academy restricts certain IAM operations
   - Ensure `UseLabMode` is set to `$true`

3. **CloudFormation Deployment Fails**
   - Check the AWS CloudFormation console for detailed error messages
   - Review AWS CLI error output for specific issues

4. **Frontend Not Loading**
   - Verify S3 bucket policy and website configuration
   - Check browser console for errors
   - Ensure proper content type was set for index.html

## Manual Verification

After deployment, you can verify the resources in the AWS Management Console:

1. **CloudFormation Stack**:
   - Check the stack status is `CREATE_COMPLETE`
   - Review the outputs for application endpoints

2. **API Gateway**:
   - Verify the WebSocket API routes and integrations
   - Test the API using a WebSocket client

3. **Lambda Functions**:
   - Test the Lambda functions
   - Check CloudWatch logs for any errors

4. **S3 Frontend**:
   - Access the frontend URL provided in the CloudFormation output
   - Verify the website loads correctly 