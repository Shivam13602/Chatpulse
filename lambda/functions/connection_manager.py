import json
import boto3
import time
import os
import logging
import urllib.parse

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE', 'ConnectionsTable'))

def lambda_handler(event, context):
    """
    Lambda function to handle WebSocket API connect and disconnect events.
    
    Args:
        event (dict): Event data from API Gateway
        context (object): Lambda context
        
    Returns:
        dict: Response with statusCode
    """
    try:
        connection_id = event['requestContext']['connectionId']
        event_type = event['requestContext']['eventType']
        
        # Log detailed information about the event
        logger.info(f"Processing {event_type} event for connection ID: {connection_id}")
        logger.info(f"Full event data: {json.dumps(event)}")
        
        if event_type == 'CONNECT':
            # Extract user data from query string if available
            user_data = {}
            if 'queryStringParameters' in event and event['queryStringParameters']:
                logger.info(f"Query string parameters: {json.dumps(event['queryStringParameters'])}")
                
                # Extract user ID if provided
                user_id = event['queryStringParameters'].get('userId', f'anonymous-{connection_id[:8]}')
                user_data['userId'] = user_id
                
                # Extract any other relevant parameters
                if 'username' in event['queryStringParameters']:
                    user_data['username'] = event['queryStringParameters']['username']
                
                # Extract client information
                if 'client' in event['queryStringParameters']:
                    user_data['client'] = event['queryStringParameters']['client']
            
            # Store the connection in DynamoDB with timestamp and metadata
            connection_item = {
                'connectionId': connection_id,
                'connectedAt': int(time.time()),
                'status': 'CONNECTED',
                'lastActivityAt': int(time.time())
            }
            
            # Add user data if available
            if user_data:
                connection_item.update(user_data)
            
            # Save to DynamoDB
            response = connections_table.put_item(Item=connection_item)
            
            logger.info(f"Successfully stored connection {connection_id} with data: {json.dumps(connection_item)}")
            
            # Send welcome message if API Gateway Management API is needed
            # (This would require additional implementation)
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': f"Successfully connected", 'connectionId': connection_id})
            }
            
        elif event_type == 'DISCONNECT':
            # Get connection data before deletion (for logging purposes)
            try:
                connection_data = connections_table.get_item(Key={'connectionId': connection_id})
                if 'Item' in connection_data:
                    logger.info(f"Disconnecting user: {json.dumps(connection_data['Item'])}")
            except Exception as get_error:
                logger.warning(f"Could not retrieve connection data before deletion: {str(get_error)}")
            
            # Remove the connection from DynamoDB
            response = connections_table.delete_item(
                Key={
                    'connectionId': connection_id
                },
                ReturnValues='ALL_OLD'  # Return the deleted item
            )
            
            if 'Attributes' in response:
                logger.info(f"Successfully removed connection {connection_id}, was connected for approximately {int(time.time()) - response['Attributes'].get('connectedAt', 0)} seconds")
            else:
                logger.info(f"Successfully removed connection {connection_id}, no previous data found")
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': f"Successfully disconnected", 'connectionId': connection_id})
            }
        
        # Handle unknown event types
        else:
            logger.warning(f"Unknown event type: {event_type}")
            return {
                'statusCode': 400,
                'body': json.dumps({'message': f"Unknown event type: {event_type}"})
            }
        
    except Exception as e:
        logger.error(f"Error processing {event.get('requestContext', {}).get('eventType', 'unknown')} event: {str(e)}")
        logger.exception(e)  # Log full exception traceback
        
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f"Error: {str(e)}"})
        }

def update_connection_activity(connection_id):
    """
    Updates the last activity timestamp for a connection.
    
    Args:
        connection_id (str): WebSocket connection ID
    """
    try:
        connections_table.update_item(
            Key={'connectionId': connection_id},
            UpdateExpression='SET lastActivityAt = :time',
            ExpressionAttributeValues={':time': int(time.time())}
        )
        logger.debug(f"Updated lastActivityAt for connection {connection_id}")
    except Exception as e:
        logger.error(f"Error updating lastActivityAt for connection {connection_id}: {str(e)}") 