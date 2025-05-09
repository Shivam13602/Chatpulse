import json
import boto3
import os
import time

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE', 'ConnectionsTable'))

def lambda_handler(event, context):
    """
    Lambda function to handle WebSocket connection events.
    Manages connections by storing connection IDs in DynamoDB.
    
    Parameters:
    - event: The event data from API Gateway
    - context: The Lambda execution context
    
    Returns:
    - Response with 200 status code
    """
    connection_id = event['requestContext']['connectionId']
    
    # Determine the route key (connect, disconnect, etc.)
    route_key = event['requestContext'].get('routeKey')
    
    # Handle connection
    if route_key == '$connect':
        # Store connection ID in DynamoDB
        try:
            connections_table.put_item(
                Item={
                    'connectionId': connection_id,
                    'timestamp': int(time.time() * 1000),
                    'status': 'connected'
                }
            )
            print(f"Connection {connection_id} added to DynamoDB.")
        except Exception as e:
            print(f"Error storing connection {connection_id}: {str(e)}")
            return {'statusCode': 500, 'body': 'Failed to connect'}
    
    return {
        'statusCode': 200,
        'body': 'Connected to WebSocket API'
    } 