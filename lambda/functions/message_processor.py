import json
import boto3
import os
import uuid
import time

# Initialize DynamoDB and API Gateway clients
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE', 'ConnectionsTable'))
messages_table = dynamodb.Table(os.environ.get('MESSAGES_TABLE', 'MessagesTable'))

# This would be replaced with a more sophisticated ML-based solution in production
POSITIVE_WORDS = ['happy', 'great', 'excellent', 'good', 'awesome', 'wonderful', 'best', 'love']
NEGATIVE_WORDS = ['sad', 'bad', 'terrible', 'awful', 'worst', 'hate', 'horrible', 'disappointed']

def analyze_sentiment(text):
    """
    Simple sentiment analysis - counts positive and negative words
    
    Parameters:
    - text: The message text to analyze
    
    Returns:
    - Sentiment score (positive number for positive sentiment, 
      negative number for negative sentiment)
    """
    score = 0
    words = text.lower().split()
    
    for word in words:
        if word in POSITIVE_WORDS:
            score += 1
        elif word in NEGATIVE_WORDS:
            score -= 1
    
    return score

def lambda_handler(event, context):
    """
    Lambda function to handle incoming chat messages.
    Processes messages, analyzes sentiment, stores in DynamoDB, and broadcasts to clients.
    
    Parameters:
    - event: The event data from API Gateway
    - context: The Lambda execution context
    
    Returns:
    - Response with status code and processed message
    """
    connection_id = event['requestContext']['connectionId']
    domain_name = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    
    # Initialize API Gateway Management API client
    api_client = boto3.client('apigatewaymanagementapi', 
                             endpoint_url=f'https://{domain_name}/{stage}')
    
    # Parse the request body
    body = json.loads(event['body'])
    message_text = body.get('message', '')
    
    if not message_text:
        return {
            'statusCode': 400,
            'body': 'Message content is required'
        }
        
    # Analyze sentiment
    sentiment_score = analyze_sentiment(message_text)
    
    # Generate a unique message ID
    message_id = str(uuid.uuid4())
    timestamp = int(time.time() * 1000)
    
    # Create message object
    message = {
        'messageId': message_id,
        'connectionId': connection_id,
        'message': message_text,
        'sentiment': sentiment_score,
        'timestamp': timestamp
    }
    
    # Store message in DynamoDB
    try:
        messages_table.put_item(Item=message)
        print(f"Message {message_id} stored in DynamoDB")
    except Exception as e:
        print(f"Error storing message: {str(e)}")
        return {
            'statusCode': 500,
            'body': 'Failed to process message'
        }
        
    # Broadcast message to all connected clients
    try:
        # Get all connections
        response = connections_table.scan()
        connections = response.get('Items', [])
        
        # Convert message to a serializable format for sending
        payload = json.dumps({
            'messageId': message_id,
            'message': message_text,
            'sentiment': sentiment_score,
            'timestamp': timestamp,
            'connectionId': connection_id
        })
        
        # Send to each connection
        for connection in connections:
            try:
                api_client.post_to_connection(
                    ConnectionId=connection['connectionId'],
                    Data=payload
                )
            except api_client.exceptions.GoneException:
                # If the connection is no longer available, remove it
                connections_table.delete_item(
                    Key={'connectionId': connection['connectionId']}
                )
            except Exception as e:
                print(f"Error sending message to {connection['connectionId']}: {str(e)}")
                
        return {
            'statusCode': 200,
            'body': json.dumps({
                'messageId': message_id,
                'message': message_text,
                'sentiment': sentiment_score
            })
        }
    except Exception as e:
        print(f"Error broadcasting message: {str(e)}")
        return {
            'statusCode': 500,
            'body': 'Failed to broadcast message'
        } 