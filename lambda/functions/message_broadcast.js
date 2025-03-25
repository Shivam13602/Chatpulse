const AWS = require('aws-sdk');

// Initialize AWS clients
const dynamoDB = new AWS.DynamoDB.DocumentClient();
let apiGateway;

exports.handler = async (event) => {
  console.log('Event received by message_broadcast.js:', JSON.stringify(event, null, 2));
  
  try {
    // Extract the message data from the event
    const messageData = event.detail;
    
    // Validate the message data
    if (!messageData || !messageData.messageId) {
      console.error('Invalid message data received');
      return { statusCode: 400, body: 'Invalid message data' };
    }
    
    // Initialize API Gateway with the WebSocket endpoint from environment variable
    apiGateway = new AWS.ApiGatewayManagementApi({
      endpoint: process.env.WEBSOCKET_ENDPOINT
    });
    
    console.log('Retrieving connections from DynamoDB...');
    // Get all connections from DynamoDB
    const connections = await dynamoDB.scan({
      TableName: process.env.CONNECTIONS_TABLE
    }).promise();
    
    console.log(`Found ${connections.Items.length} active connections`);
    
    // Broadcast the message to all connected clients
    const broadcastMessage = {
      type: 'message',
      data: {
        messageId: messageData.messageId,
        userId: messageData.userId,
        username: messageData.username || 'Anonymous',
        content: messageData.content,
        sentiment: messageData.sentiment,
        timestamp: messageData.timestamp
      }
    };
    
    const broadcastPromises = connections.Items.map(async ({ connectionId }) => {
      try {
        console.log(`Broadcasting message ${messageData.messageId} to connection ${connectionId}`);
        await apiGateway.postToConnection({
          ConnectionId: connectionId,
          Data: JSON.stringify(broadcastMessage)
        }).promise();
        return { connectionId, success: true };
      } catch (error) {
        if (error.statusCode === 410) {
          // Connection is stale (client disconnected)
          console.log(`Connection ${connectionId} is stale, removing from DynamoDB`);
          await dynamoDB.delete({
            TableName: process.env.CONNECTIONS_TABLE,
            Key: { connectionId }
          }).promise();
          return { connectionId, success: false, stale: true };
        } else {
          console.error(`Error broadcasting to ${connectionId}:`, error);
          return { connectionId, success: false, error: error.message };
        }
      }
    });
    
    const results = await Promise.all(broadcastPromises);
    const successCount = results.filter(r => r.success).length;
    const staleCount = results.filter(r => r.stale).length;
    
    console.log(`Broadcast complete: ${successCount} successful, ${staleCount} stale connections removed`);
    
    // Optionally log the event to CloudWatch for analytics
    const logToCloudWatchEvents = async () => {
      try {
        const eventBridge = new AWS.EventBridge();
        await eventBridge.putEvents({
          Entries: [{
            Source: 'chat.application',
            DetailType: 'MessageBroadcastCompleted',
            Detail: JSON.stringify({
              messageId: messageData.messageId,
              broadcastStats: {
                total: connections.Items.length,
                successful: successCount,
                stale: staleCount,
                failed: connections.Items.length - successCount - staleCount
              },
              timestamp: Date.now()
            }),
            EventBusName: process.env.EVENT_BUS_NAME || 'default'
          }]
        }).promise();
        console.log('MessageBroadcastCompleted event published to EventBridge');
      } catch (error) {
        console.error('Error publishing event to EventBridge:', error);
      }
    };
    
    // Don't await this to keep the function response time faster
    logToCloudWatchEvents().catch(console.error);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Broadcast complete',
        stats: {
          total: connections.Items.length,
          successful: successCount,
          stale: staleCount,
          failed: connections.Items.length - successCount - staleCount
        }
      })
    };
  } catch (error) {
    console.error('Unhandled error in Lambda:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error', error: error.message })
    };
  }
}; 