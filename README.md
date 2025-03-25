# Real-Time Chat Application with Sentiment Insights

This is a serverless, real-time chat application with sentiment analysis capabilities, built using various AWS services.

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
- A simple HTML/JS single-page application hosted on Amazon S3
- Connects to the WebSocket API to send and receive messages in real-time
- Displays sentiment scores alongside messages

### Backend
- **Connection Manager Lambda (Python)**: Handles WebSocket connections/disconnections and stores connection IDs
- **Message Processor Lambda (Node.js)**: Processes incoming messages, performs sentiment analysis, and stores in DynamoDB
- **Broadcast Lambda (Node.js)**: Broadcasts messages to all connected clients
- **Default Handler Lambda (Node.js)**: Handles default/fallback WebSocket routes
- **EC2 Sentiment Model Training**: Trains and updates the sentiment analysis model

### Data Storage
- **DynamoDB Connections Table**: Stores WebSocket connection IDs
- **DynamoDB Messages Table**: Stores chat messages with sentiment scores

### Event-Driven Architecture
- **EventBridge Event Bus**: Routes events between components
- **Event Types**:
  - MessageCreated: When a new message is sent
  - SentimentAnalysisCompleted: When sentiment analysis is completed
  - ModelTrainingCompleted: When the model is retrained

### Monitoring and Alerting
- **CloudWatch Dashboard**: Displays metrics for Lambda functions, DynamoDB tables, and EC2 instance
- **CloudWatch Alarms**: Alerts on Lambda errors, DynamoDB throttling, and EC2 CPU usage
- **CloudWatch Logs**: Stores logs from all Lambda functions

## Deployment

### Prerequisites
- AWS CLI installed and configured
- An AWS account with appropriate permissions
- Node.js and npm installed (for Lambda packaging)

### Deployment Steps (Windows)

1. Clone this repository
2. Open PowerShell
3. Navigate to the project directory
4. Run the deployment script:

```powershell
.\deploy.ps1 -Region us-west-2 -S3BucketName your-bucket-name -StackName your-stack-name -Environment Prod -AdminEmail your-email@example.com
```

### Deployment Steps (Linux/macOS)

1. Clone this repository
2. Open Terminal
3. Navigate to the project directory
4. Make the deployment script executable:

```bash
chmod +x deploy.sh
```

5. Run the deployment script:

```bash
./deploy.sh us-west-2 your-bucket-name your-stack-name Prod your-email@example.com
```

### Parameters

- **Region**: AWS region to deploy to (default: us-west-2)
- **S3BucketName**: Name for the S3 bucket to create (must be globally unique)
- **StackName**: Name for the CloudFormation stack (default: real-time-chat-app)
- **Environment**: Environment name (default: Prod)
- **AdminEmail**: Email address for CloudWatch alarms

## Usage

After deployment, you'll receive:
- WebSocket URL for client connections
- Frontend URL to access the chat application
- CloudWatch Dashboard URL for monitoring
- EC2 Instance ID for the model training server

1. Open the Frontend URL in a web browser
2. Enter a username
3. Start chatting with others who are connected
4. Notice the sentiment scores next to each message

## Architecture Diagram

```
┌────────────────┐       ┌─────────────────┐
│                │       │                 │
│  Web Browser   │◄─────►│  Amazon S3      │
│  (Frontend)    │       │  (Static Site)  │
│                │       │                 │
└───────┬────────┘       └─────────────────┘
        │
        │ WebSocket
        │
┌───────▼────────┐
│                │
│  API Gateway   │
│  (WebSocket)   │
│                │
└┬──────┬──────┬─┘
 │      │      │
 │      │      │
┌▼──────▼──────▼─┐       ┌─────────────────┐
│                │       │                 │
│  AWS Lambda    │◄─────►│  EventBridge    │
│  Functions     │       │  Event Bus      │
│                │       │                 │
└┬───────────────┘       └────┬────────────┘
 │                            │
 │                            │
┌▼─────────────────┐          │
│                  │          │
│  DynamoDB        │          │
│  Tables          │          │
│                  │          │
└──────────────────┘          │
                              │
┌─────────────────────┐       │
│                     │◄──────┘
│  EC2                │
│  (Model Training)   │
│                     │
└─────────────────────┘
```

## Monitoring and Maintenance

- **CloudWatch Dashboard**: Access it using the URL from the deployment outputs
- **Logs**: Available in CloudWatch Logs under the `/aws/lambda/` log groups
- **Alarms**: Configured to send emails when thresholds are exceeded

## Cleanup

To remove all resources created by this application:

1. Delete the CloudFormation stack:
```
aws cloudformation delete-stack --stack-name your-stack-name --region your-region
```

2. Empty and delete the S3 bucket:
```
aws s3 rm s3://your-bucket-name --recursive
aws s3api delete-bucket --bucket your-bucket-name --region your-region
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 