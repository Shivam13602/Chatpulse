/**
 * Default handler for Real-Time Chat Application
 * This function handles unknown routes in the WebSocket API
 */

const AWS = require('aws-sdk');
const apiGateway = new AWS.ApiGatewayManagementApi({
  endpoint: process.env.WEBSOCKET_ENDPOINT
});

/**
 * Main handler function for the Lambda
 * @param {Object} event - API Gateway event
 * @param {Object} context - Lambda context
 * @returns {Object} - Response object
 */
exports.handler = async (event, context) => {
  console.log('Event received:', JSON.stringify(event));
  
  try {
    const connectionId = event.requestContext.connectionId;
    const routeKey = event.requestContext.routeKey;
    
    console.log(`Received request for unsupported route: ${routeKey}`);
    
    // Send a response back to the client
    const message = {
      message: `Route '${routeKey}' is not supported. Valid routes are $connect, $disconnect, and sendMessage.`,
      timestamp: new Date().toISOString()
    };
    
    try {
      await sendMessageToClient(connectionId, message);
      console.log('Response sent to client successfully');
    } catch (err) {
      if (err.statusCode === 410) {
        console.log(`Connection ${connectionId} is stale or no longer available`);
      } else {
        console.error('Error sending message to client:', err);
      }
    }
    
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Default handler processed request' })
    };
  } catch (err) {
    console.error('Error processing default handler request:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error' })
    };
  }
};

/**
 * Send a message to a connected WebSocket client
 * @param {string} connectionId - Client connection ID
 * @param {Object} payload - Message payload
 * @returns {Promise} - API Gateway management result
 */
async function sendMessageToClient(connectionId, payload) {
  return apiGateway.postToConnection({
    ConnectionId: connectionId,
    Data: JSON.stringify(payload)
  }).promise();
} 