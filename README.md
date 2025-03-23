# Real-Time Chat Application with Sentiment Analysis

This project demonstrates a real-time chat application with sentiment analysis built using serverless AWS services.

## Project Overview

The intended architecture includes:

- Frontend: Static website hosted on Amazon S3
- Backend: AWS API Gateway (WebSocket API), AWS Lambda, and Amazon DynamoDB
- Analysis: Real-time sentiment analysis of chat messages

## AWS Academy Limitations

Due to AWS Academy account limitations, we've created a simplified demo version. The main limitations encountered were:

1. **IAM Role Creation**: AWS Academy student accounts do not have permissions to create IAM roles, which are required for CloudFormation deployments and Lambda function execution.
2. **AWS CLI Issues**: AWS Academy environments may have configuration issues with the AWS CLI Python modules.
3. **CloudFormation Deployment**: Without IAM role creation permissions, the full CloudFormation template cannot be deployed.

## What's Included

This repository contains:

1. **Complete Source Code**: The full implementation including:
   - Lambda functions for connection management and message processing
   - CloudFormation templates for infrastructure deployment
   - Frontend code with WebSocket implementation

2. **Simplified Demo Version**: A static website that demonstrates the UI of the chat application with simulated backend functionality.

3. **Deployment Methods**:
   - `deploy_academy.ps1`: Attempts to deploy using the LabRole in AWS Academy (if available)
   - `deploy_simple.ps1`: Simplified script for deploying just the frontend
   - `deploy_manual.ps1`: Step-by-step guide for manual deployment through the AWS Console

## Deployment Methods

### Method 1: Manual Deployment (Recommended for AWS Academy)

The most reliable method for AWS Academy environments is the manual deployment through the AWS Console:

1. Run the manual deployment guide:
   ```
   ./deploy_manual.ps1
   ```

2. Follow the step-by-step instructions displayed to:
   - Create an S3 bucket in the AWS Console
   - Configure it for static website hosting
   - Set the appropriate bucket policy
   - Upload the frontend files with the correct content type
   - Access your website through the provided URL

### Method 2: Using AWS Academy LabRole (If Available)

If your AWS Academy account has access to the LabRole, you can try the full deployment:

1. Run the academy deployment script:
   ```
   ./deploy_academy.ps1
   ```

2. Enter your AWS Academy credentials when prompted

### Method 3: Simple Frontend Deployment

If you have AWS PowerShell modules installed:

1. Run the simplified deployment script:
   ```
   ./deploy_frontend.ps1
   ```

## Using the Demo Application

1. **Connect to the Chat**:
   - Enter a username in the input field
   - Click "Connect" to join the chat

2. **Send Messages**:
   - Type a message in the input field
   - Press Enter or click "Send"
   
3. **Observe Sentiment Analysis**:
   - Messages are automatically analyzed for sentiment
   - Positive messages appear with a green bar on the left
   - Negative messages appear with a red bar on the left
   - Neutral messages appear with a gray bar on the left
   - A sentiment badge indicates the detected sentiment

4. **Demo Mode Features**:
   - Simulated responses from other users
   - Local sentiment analysis calculation
   - Persistent chat display

## Getting AWS Academy Credentials

To get your AWS Academy credentials:

1. Log in to your AWS Academy course
2. Launch the Learner Lab
3. Click on "AWS Details" 
4. Locate the "AWS CLI" section to find:
   - AWS Access Key ID
   - AWS Secret Access Key
   - AWS Session Token
5. Use these credentials when prompted by any of the deployment scripts

## Architecture Overview

This application implements a serverless architecture leveraging AWS services:

- **Frontend**: HTML/CSS/JavaScript web client hosted in Amazon S3
- **Backend**:
  - Amazon API Gateway WebSocket API for real-time communication
  - AWS Lambda functions for connection management and message processing
  - Amazon DynamoDB for storing connection data and messages

![Architecture Diagram](docs/architecture-diagram.png)

## Features

- **Real-time messaging**: WebSocket-based communication
- **Sentiment Analysis**: Basic sentiment detection for all messages
- **User Management**: Simple user identification and connection tracking
- **Responsive Web Interface**: Mobile-friendly chat interface
- **Offline Mode Detection**: Automatic reconnection attempts
- **Message History**: Persistence of messages in DynamoDB

## Project Structure

```
├── docs/                           # Documentation
├── infrastructure/                  # Infrastructure as Code
│   └── cloudformation/             # CloudFormation templates
│       ├── main-template.yml       # Main CloudFormation template
│       └── main-template-labmode.yml # Template using LabRole
├── lambda/                         # Lambda functions
│   └── functions/                  # Lambda function implementations
│       ├── connection_manager.py   # Manages WebSocket connections
│       ├── message_processor.js    # Processes and broadcasts messages
│       ├── default_handler.js      # Handles unknown routes
│       ├── requirements.txt        # Python dependencies
│       └── package.json            # Node.js dependencies
├── src/                            # Source code
│   └── frontend/                   # Web client
│       └── index.html              # Web client HTML/CSS/JS
├── tests/                          # Test scripts
├── deploy.ps1                      # Full PowerShell deployment script
├── deploy_academy.ps1              # AWS Academy deployment using LabRole
├── deploy_simple.ps1               # Simplified frontend deployment script
├── deploy_manual.ps1               # Manual deployment guide
└── README.md                       # This file
```

## Troubleshooting

If you encounter issues during deployment:

1. **AWS CLI Errors**: If you see Python module errors, use the manual deployment method instead.

2. **Permission Denied Errors**: These usually indicate AWS Academy limitations. Review the error message and switch to the manual deployment method.

3. **Session Token Issues**: AWS Academy session tokens expire. Make sure to get fresh credentials before deployment.

4. **S3 Bucket Naming**: Ensure your S3 bucket name is globally unique. The scripts generate timestamps to help with this.

## Cleanup

To avoid incurring charges, delete the resources when no longer needed:

1. For manual deployments:
   - Follow the cleanup steps in the manual deployment guide
   
2. For script-based deployments:
   - Use the AWS Console to delete the CloudFormation stack
   - Delete any S3 buckets created during deployment

## License

This project is licensed under the MIT License - see the LICENSE file for details. 