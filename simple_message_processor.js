// Simple message processor without uuid dependency
const AWS = require('aws-sdk');

// Configure AWS SDK
const apiGateway = new AWS.ApiGatewayManagementApi({
  endpoint: process.env.WEBSOCKET_ENDPOINT
});

// Main handler function
exports.handler = async (event) => {
  console.log('Event received', JSON.stringify(event));
  
  // Extract connection ID from the event
  const connectionId = event.requestContext.connectionId;
  const domainName = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  
  // Set up the WebSocket endpoint if not already provided
  if (!process.env.WEBSOCKET_ENDPOINT) {
    const endpoint = `${domainName}/${stage}`;
    apiGateway.config.endpoint = endpoint;
    console.log(`WebSocket endpoint set to: ${endpoint}`);
  }
  
  try {
    // Parse the body content
    let body;
    try {
      body = JSON.parse(event.body);
    } catch (e) {
      console.error('Error parsing request body:', e);
      return { statusCode: 400, body: 'Invalid request body' };
    }
    
    // Check if this is a message action - be case insensitive to handle both 'sendMessage' and 'sendmessage'
    if (body.action && body.action.toLowerCase() === 'sendmessage') {
      const messageData = body.data;
      const userId = body.userId || 'anonymous';
      
      // Create a message object
      const message = {
        messageId: Date.now().toString(), // Simple ID using timestamp instead of uuid
        timestamp: new Date().toISOString(),
        content: messageData,
        userId: userId,
        sentiment: 'NEUTRAL' // Default sentiment
      };
      
      // Send the message to the client
      await sendMessageToClient(connectionId, JSON.stringify(message));
      
      return { statusCode: 200, body: 'Message sent' };
    } else {
      console.log(`Action '${body.action}' not supported. Use 'sendmessage' or 'sendMessage'.`);
      return { statusCode: 400, body: `Action '${body.action}' not supported. Use 'sendmessage' or 'sendMessage'.` };
    }
  } catch (err) {
    console.error('Error processing message:', err);
    return { statusCode: 500, body: 'Internal server error' };
  }
};

// Function to send a message to a WebSocket client
async function sendMessageToClient(connectionId, message) {
  try {
    await apiGateway.postToConnection({
      ConnectionId: connectionId,
      Data: message
    }).promise();
    console.log(`Message sent to connection ${connectionId}`);
  } catch (err) {
    console.error(`Error sending message to connection ${connectionId}:`, err);
    
    // If the connection is no longer available, ignore the error
    if (err.statusCode === 410) {
      console.log(`Connection ${connectionId} is no longer available`);
    } else {
      throw err;
    }
  }
} 