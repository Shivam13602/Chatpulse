# Chatpulse - Real-Time Chat Application with Sentiment Analysis

A serverless real-time chat application with sentiment analysis capabilities, built using various AWS services. This application allows users to chat in real-time while analyzing the sentiment of messages.

## Architecture Overview

This application uses the following AWS services:

1. **Compute**:
   - **AWS Lambda**: For serverless message processing, connection management, and broadcasting
   - **Amazon EC2**: For sentiment analysis model training

2. **Storage**:
   - **Amazon S3**: For hosting the frontend and storing trained models

3. **Networking and Content Delivery**:
   - **Amazon API Gateway**: For WebSocket API to enable real-time messaging

4. **Database**:
   - **Amazon DynamoDB**: For storing messages and connection information

5. **Application Integration**:
   - **Amazon EventBridge**: For event-driven communication between components

6. **Management and Governance**:
   - **Amazon CloudWatch**: For monitoring, logging, and alerting

## Components

### Frontend
- A simple HTML/JS/CSS single-page application hosted on Amazon S3
- Connects to the WebSocket API to send and receive messages in real-time
- Displays sentiment scores alongside messages
- Features a responsive design suitable for desktop and mobile devices

### Backend
- **Connection Manager Lambda (Python)**: Handles WebSocket connections/disconnections and stores connection IDs
- **Message Processor Lambda (Python)**: Processes incoming messages, performs sentiment analysis, and stores in DynamoDB
- **Broadcast Lambda**: Broadcasts messages to all connected clients

### Data Storage
- **DynamoDB Connections Table**: Stores WebSocket connection IDs
- **DynamoDB Messages Table**: Stores chat messages with sentiment scores

## Features

- **User authentication**: Login with a username and custom color
- **Real-time messaging**: Instant updates via WebSocket
- **Message sentiment analysis**: Automatic analysis of message sentiment
- **Responsive design**: Works on desktop and mobile devices
- **Dark mode**: Toggle between light and dark themes
- **Emoji support**: Insert emojis in messages
- **Typing indicators**: Shows when users are typing
- **Connection status**: Visual indication of connection status

## Deployment

### Prerequisites
- AWS CLI installed and configured
- An AWS account with appropriate permissions
- Python 3.6+ (for local development and Lambda functions)

### Deployment Steps

1. Clone this repository
2. Deploy the CloudFormation stack:

```powershell
.\deploy.ps1 -Region us-west-2 -S3BucketName your-bucket-name -StackName ChatpulseApp
```

3. After deployment, access the application through the S3 website URL provided in the CloudFormation outputs.

## Local Development

To run the frontend locally:

1. Navigate to the `src/frontend` directory
2. Start the Python development server:

```
cd src/frontend
python serve.py
```

3. Open your web browser and navigate to `http://localhost:8080`

## Cleanup

To remove all resources created by this application, run:

```powershell
.\cleanup-demo.ps1
```

This script will delete all AWS resources including the CloudFormation stack, the S3 bucket, and all other resources created by the deployment.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 