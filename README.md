# Real-Time Chat Application with Sentiment Analysis

## Project Overview
This project implements a real-time chat application with sentiment analysis capabilities using AWS services. The application allows users to chat in real-time, with messages analyzed for sentiment and appropriately displayed.

## Architecture
- **Frontend**: Web/Mobile interface
- **CloudFront**: Content delivery
- **API Gateway**: WebSocket API for real-time communication
- **Lambda**: Backend processing for message handling and sentiment analysis
- **DynamoDB**: Database for storing connections and messages
- **EC2**: Model training for sentiment analysis
- **Cognito**: User authentication

## AWS Services Used
- **Compute**: EC2, Lambda
- **Storage**: S3
- **Networking**: API Gateway

## Setup Instructions
1. Ensure you have AWS CLI installed and configured
2. Deploy the CloudFormation stack using the template in the `infrastructure/cloudformation` directory
3. For local development, set up the development environment as described below

## Development Environment
```bash
# Install required dependencies
npm install
pip install -r requirements.txt

# Start local development server
npm start
```

## Project Structure
- `/infrastructure`: CloudFormation templates and infrastructure code
- `/lambda`: Lambda function code
- `/src`: Frontend application code
- `/docs`: Project documentation

## License
MIT 