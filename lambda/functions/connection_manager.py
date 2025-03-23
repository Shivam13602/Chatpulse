import json
import boto3
import time
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE_NAME', 'ConnectionsTable'))

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
        
        logger.info(f"Received {event_type} event for connection ID: {connection_id}")
        
        if event_type == 'CONNECT':
            # Store the connection in DynamoDB
            response = connections_table.put_item(
                Item={
                    'connectionId': connection_id,
                    'connectedAt': int(time.time()),
                    'status': 'CONNECTED'
                }
            )
            logger.info(f"Successfully stored connection {connection_id}")
            
        elif event_type == 'DISCONNECT':
            # Remove the connection from DynamoDB
            response = connections_table.delete_item(
                Key={
                    'connectionId': connection_id
                }
            )
            logger.info(f"Successfully removed connection {connection_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': f"Successful {event_type}"})
        }
        
    except Exception as e:
        logger.error(f"Error processing {event.get('requestContext', {}).get('eventType', 'unknown')} event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f"Error: {str(e)}"})
        } 