# Real-Time Chat Application Architecture

## System Architecture Diagram

```
+-------------------+    +---------------+    +-------------------+
|                   |    |               |    |                   |
|   Web Client      +---->  CloudFront   +---->  S3 (Static Site) |
|                   |    |               |    |                   |
+--------+----------+    +---------------+    +-------------------+
         |
         | WebSocket Connection
         v
+-------------------+
|                   |
|   API Gateway     |
|   (WebSocket)     |
|                   |
+--------+----------+
         |
         | Invoke
         v
+-------------------+    +-------------------+
|                   |    |                   |
|   Lambda          +---->   DynamoDB        |
|   Functions       |    |   (Connections,   |
|                   |    |    Messages)      |
+--------+----------+    +-------------------+
         |
         | Use model
         v
+-------------------+    +-------------------+
|                   |    |                   |
|   EC2             +---->   S3              |
|   (Model Training)|    |   (Model Storage) |
|                   |    |                   |
+-------------------+    +-------------------+
```

## Component Descriptions

1. **Web Client**: The browser-based interface where users interact with the chat application.

2. **CloudFront**: Content Delivery Network for distributing static assets globally with low latency.

3. **S3 (Static Site)**: Stores and serves the static assets for the frontend.

4. **API Gateway (WebSocket)**: Manages WebSocket connections for real-time communication.

5. **Lambda Functions**:
   - **Connection Manager**: Handles WebSocket connect and disconnect events.
   - **Message Processor**: Processes messages, analyzes sentiment, and broadcasts to clients.

6. **DynamoDB**:
   - **Connections Table**: Stores active WebSocket connections.
   - **Messages Table**: Stores chat messages with sentiment scores.

7. **EC2 (Model Training)**: Periodically retrains the sentiment analysis model.

8. **S3 (Model Storage)**: Stores the trained sentiment analysis model.

## Data Flow

1. Users connect to the application via a web browser.
2. Static content is served from S3 via CloudFront.
3. The client establishes a WebSocket connection to API Gateway.
4. When a user sends a message:
   - The message is sent to API Gateway
   - API Gateway invokes the Message Processor Lambda
   - Lambda analyzes sentiment and stores the message in DynamoDB
   - Lambda broadcasts the message to all connected clients
5. The EC2 instance periodically retrains the sentiment model and updates it in S3.
6. Lambda functions use the latest model for sentiment analysis.

## Key AWS Services Used

- **Compute**: EC2, Lambda
- **Storage**: S3
- **Networking**: API Gateway 