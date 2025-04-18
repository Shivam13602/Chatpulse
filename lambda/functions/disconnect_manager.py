import json
import boto3
import os

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE', 'ConnectionsTable'))

def lambda_handler(event, context):
    """
    Lambda function to handle WebSocket disconnection events.
    Removes connection IDs from DynamoDB when clients disconnect.
    
    Parameters:
    - event: The event data from API Gateway
    - context: The Lambda execution context
    
    Returns:
    - Response with 200 status code
    """
    connection_id = event['requestContext']['connectionId']
    
    # Determine the route key (connect, disconnect, etc.)
    route_key = event['requestContext'].get('routeKey')
    
    # Handle disconnection
    if route_key == '$disconnect':
        try:
            # Remove connection ID from DynamoDB
            connections_table.delete_item(
                Key={
                    'connectionId': connection_id
                }
            )
            print(f"Connection {connection_id} removed from DynamoDB.")
        except Exception as e:
            print(f"Error removing connection {connection_id}: {str(e)}")
            return {'statusCode': 500, 'body': 'Failed to disconnect properly'}
    
    return {
        'statusCode': 200,
        'body': 'Disconnected from WebSocket API'
    } 