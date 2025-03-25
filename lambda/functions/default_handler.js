const AWS = require('aws-sdk');

// Environment variables
const WEBSOCKET_ENDPOINT = process.env.WEBSOCKET_ENDPOINT;

// Initialize AWS clients
const apiGateway = new AWS.ApiGatewayManagementApi({
  endpoint: `https://${WEBSOCKET_ENDPOINT}`
});

/**
 * Lambda handler for the default WebSocket route
 * This handles any unsupported WebSocket message types
 */
exports.handler = async (event) => {
  console.log('Default handler event:', JSON.stringify(event));
  
  if (!event.requestContext || !event.requestContext.connectionId) {
    return { statusCode: 400, body: 'Invalid request format' };
  }
  
  const connectionId = event.requestContext.connectionId;
  
  try {
    // Parse body if present
    let body = {};
    if (event.body) {
      try {
        body = JSON.parse(event.body);
      } catch (error) {
        console.log('Error parsing message body:', error);
      }
    }
    
    // Send response to client explaining the error
    await apiGateway.postToConnection({
      ConnectionId: connectionId,
      Data: JSON.stringify({
        type: 'error',
        message: 'Unsupported action',
        receivedAction: body.action || 'unknown',
        supportedActions: ['sendMessage'],
        timestamp: new Date().toISOString()
      })
    }).promise();
    
    return { statusCode: 200, body: 'Default handler processed message' };
  } catch (error) {
    console.error('Error in default handler:', error);
    return { statusCode: 500, body: 'Internal server error' };
  }
}; 