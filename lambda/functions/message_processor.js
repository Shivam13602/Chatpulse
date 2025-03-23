const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS services
const dynamoDB = new AWS.DynamoDB.DocumentClient();
let apiGateway;

// Define positive and negative word lists for basic sentiment analysis
const POSITIVE = ['happy', 'great', 'excellent', 'good', 'love', 'awesome', 'fantastic', 'wonderful', 'nice', 'amazing'];
const NEGATIVE = ['sad', 'bad', 'awful', 'terrible', 'horrible', 'hate', 'dislike', 'angry', 'upset', 'disappointed'];

/**
 * Lambda function to process incoming messages, perform sentiment analysis,
 * store in DynamoDB, and broadcast to all connected clients.
 */
exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event));
    
    // Initialize API Gateway with the correct endpoint from the event
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    apiGateway = new AWS.ApiGatewayManagementApi({
        endpoint: `${domain}/${stage}`
    });
    
    try {
        // Extract connection ID and message data
        const connectionId = event.requestContext.connectionId;
        const body = JSON.parse(event.body);
        
        // Ensure body has expected format
        if (!body.action || !body.data) {
            return { statusCode: 400, body: JSON.stringify({ message: 'Invalid message format' }) };
        }

        // Only process 'sendmessage' action
        if (body.action !== 'sendmessage') {
            return { statusCode: 200, body: JSON.stringify({ message: 'Unsupported action' }) };
        }

        const text = body.data;
        
        // Perform simple sentiment analysis
        let score = 0;
        const words = text.toLowerCase().split(/\s+/);
        
        words.forEach(word => {
            if (POSITIVE.includes(word)) score += 1;
            if (NEGATIVE.includes(word)) score -= 1;
        });
        
        // Create message object
        const message = {
            messageId: uuidv4(),
            connectionId: connectionId,
            content: text,
            sentiment: score,
            timestamp: Date.now(),
            userId: body.userId || connectionId // Use provided userId or connectionId as fallback
        };
        
        // Store message in DynamoDB
        await dynamoDB.put({
            TableName: process.env.MESSAGES_TABLE_NAME || 'MessagesTable',
            Item: message
        }).promise();
        
        console.log('Message stored in DynamoDB:', message.messageId);
        
        // Fetch all active connections
        const connectionsData = await dynamoDB.scan({
            TableName: process.env.CONNECTIONS_TABLE_NAME || 'ConnectionsTable'
        }).promise();
        
        // Broadcast message to all connections
        const postCalls = connectionsData.Items.map(async ({ connectionId }) => {
            try {
                await apiGateway.postToConnection({
                    ConnectionId: connectionId,
                    Data: JSON.stringify({
                        type: 'message',
                        data: message
                    })
                }).promise();
                console.log(`Message successfully sent to ${connectionId}`);
            } catch (err) {
                // Handle stale connections
                if (err.statusCode === 410) {
                    console.log(`Connection ${connectionId} is stale, removing...`);
                    await dynamoDB.delete({
                        TableName: process.env.CONNECTIONS_TABLE_NAME || 'ConnectionsTable',
                        Key: { connectionId }
                    }).promise();
                } else {
                    console.error(`Error sending message to ${connectionId}:`, err);
                    throw err;
                }
            }
        });
        
        // Wait for all broadcast operations to complete
        await Promise.all(postCalls);
        
        return { 
            statusCode: 200, 
            body: JSON.stringify({ 
                message: 'Message processed and broadcast successfully',
                messageId: message.messageId
            }) 
        };
        
    } catch (err) {
        console.error('Error processing message:', err);
        return { 
            statusCode: 500, 
            body: JSON.stringify({ 
                message: 'Error processing message',
                error: err.message
            }) 
        };
    }
}; 