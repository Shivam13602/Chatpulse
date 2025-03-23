const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS services
const dynamoDB = new AWS.DynamoDB.DocumentClient();
let apiGateway;

// Enhanced word lists for sentiment analysis
const POSITIVE = [
  'happy', 'great', 'excellent', 'good', 'love', 'awesome', 'fantastic', 
  'wonderful', 'nice', 'amazing', 'joy', 'pleased', 'delighted', 'satisfied', 
  'impressed', 'grateful', 'thankful', 'appreciate', 'perfect', 'outstanding'
];

const NEGATIVE = [
  'sad', 'bad', 'awful', 'terrible', 'horrible', 'hate', 'dislike', 'angry', 
  'upset', 'disappointed', 'frustrated', 'annoyed', 'unhappy', 'miserable', 
  'poor', 'terrible', 'worst', 'sucks', 'useless', 'rubbish'
];

// Sentiment intensity modifiers
const INTENSIFIERS = [
  'very', 'really', 'extremely', 'absolutely', 'completely', 'totally',
  'utterly', 'so', 'too', 'incredibly', 'remarkably', 'unusually'
];

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
      await sendResponseToClient(connectionId, {
        type: 'error',
        data: { message: 'Invalid message format. Must include action and data fields.' }
      });
      return { statusCode: 400, body: JSON.stringify({ message: 'Invalid message format' }) };
    }

    // Only process 'sendmessage' action
    if (body.action !== 'sendmessage') {
      await sendResponseToClient(connectionId, {
        type: 'error',
        data: { message: `Action '${body.action}' not supported. Use 'sendmessage'.` }
      });
      return { statusCode: 200, body: JSON.stringify({ message: 'Unsupported action' }) };
    }

    // Get the text content of the message
    const text = body.data;
    
    // Get user info from database
    let userId = body.userId || connectionId;
    let username = body.username || 'Anonymous';
    
    try {
      const connData = await dynamoDB.get({
        TableName: process.env.CONNECTIONS_TABLE || 'ConnectionsTable',
        Key: { connectionId }
      }).promise();
      
      if (connData.Item) {
        userId = connData.Item.userId || userId;
        username = connData.Item.username || username;
        
        // Update last activity timestamp
        await dynamoDB.update({
          TableName: process.env.CONNECTIONS_TABLE || 'ConnectionsTable',
          Key: { connectionId },
          UpdateExpression: 'SET lastActivityAt = :time',
          ExpressionAttributeValues: { ':time': Date.now() }
        }).promise();
      }
    } catch (error) {
      console.warn('Error retrieving connection info', error);
    }
    
    // Perform enhanced sentiment analysis
    const sentiment = analyzeSentiment(text);
    
    // Create message object
    const message = {
      messageId: uuidv4(),
      connectionId: connectionId,
      userId: userId,
      username: username,
      content: text,
      sentiment: sentiment.score,
      sentimentData: sentiment,
      timestamp: Date.now()
    };
    
    // Store message in DynamoDB
    await dynamoDB.put({
      TableName: process.env.MESSAGES_TABLE || 'MessagesTable',
      Item: message
    }).promise();
    
    console.log('Message stored in DynamoDB:', message.messageId);
    
    // Fetch all active connections
    const connectionsData = await dynamoDB.scan({
      TableName: process.env.CONNECTIONS_TABLE || 'ConnectionsTable'
    }).promise();
    
    // Prepare message for broadcast - remove internal data
    const broadcastMessage = {
      messageId: message.messageId,
      userId: message.userId,
      username: message.username,
      content: message.content,
      sentiment: message.sentiment,
      timestamp: message.timestamp
    };
    
    // Broadcast message to all connections
    const postCalls = connectionsData.Items.map(({ connectionId }) => 
      broadcastToConnection(connectionId, {
        type: 'message',
        data: broadcastMessage
      })
    );
    
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

/**
 * Sends a response to a specific client
 * 
 * @param {string} connectionId - The WebSocket connection ID
 * @param {object} message - The message to send
 * @returns {Promise} - A promise that resolves when the message is sent
 */
async function sendResponseToClient(connectionId, message) {
  try {
    await apiGateway.postToConnection({
      ConnectionId: connectionId,
      Data: JSON.stringify(message)
    }).promise();
    console.log(`Response sent to ${connectionId}`);
    return true;
  } catch (err) {
    if (err.statusCode === 410) {
      console.log(`Connection ${connectionId} is stale, removing...`);
      await removeStaleConnection(connectionId);
      return false;
    }
    throw err;
  }
}

/**
 * Broadcasts a message to a connection, handling errors appropriately
 * 
 * @param {string} connectionId - The WebSocket connection ID
 * @param {object} message - The message to broadcast
 * @returns {Promise} - A promise that resolves when the message is broadcast
 */
async function broadcastToConnection(connectionId, message) {
  try {
    await apiGateway.postToConnection({
      ConnectionId: connectionId,
      Data: JSON.stringify(message)
    }).promise();
    console.log(`Message broadcast to ${connectionId}`);
    return true;
  } catch (err) {
    if (err.statusCode === 410) {
      console.log(`Connection ${connectionId} is stale, removing...`);
      await removeStaleConnection(connectionId);
      return false;
    }
    console.error(`Error broadcasting to ${connectionId}:`, err);
    return false;
  }
}

/**
 * Removes a stale connection from the database
 * 
 * @param {string} connectionId - The WebSocket connection ID to remove
 * @returns {Promise} - A promise that resolves when the connection is removed
 */
async function removeStaleConnection(connectionId) {
  try {
    await dynamoDB.delete({
      TableName: process.env.CONNECTIONS_TABLE || 'ConnectionsTable',
      Key: { connectionId }
    }).promise();
    console.log(`Stale connection ${connectionId} removed from database`);
    return true;
  } catch (err) {
    console.error(`Error removing stale connection ${connectionId}:`, err);
    return false;
  }
}

/**
 * Performs sentiment analysis on a text string
 * 
 * @param {string} text - The text to analyze
 * @returns {object} - An object containing sentiment analysis results
 */
function analyzeSentiment(text) {
  // Default result structure
  const result = {
    score: 0,
    positive: {
      count: 0,
      words: []
    },
    negative: {
      count: 0,
      words: []
    },
    neutral: true,
    dominantSentiment: 'neutral'
  };
  
  if (!text || text.trim() === '') {
    return result;
  }
  
  // Lowercase and tokenize text
  const words = text.toLowerCase().split(/\s+/);
  let intensifierCount = 0;
  
  // First pass: identify intensifiers
  words.forEach((word, index) => {
    if (INTENSIFIERS.includes(word)) {
      intensifierCount++;
    }
  });
  
  // Calculate intensifier multiplier (more intensifiers lead to stronger sentiment)
  const intensifierMultiplier = 1 + (intensifierCount * 0.2);
  
  // Second pass: analyze sentiment
  words.forEach((word) => {
    // Remove any punctuation
    const cleanWord = word.replace(/[^\w\s]/gi, '');
    
    if (POSITIVE.includes(cleanWord)) {
      result.positive.count++;
      result.positive.words.push(cleanWord);
      result.score += 1 * intensifierMultiplier;
      result.neutral = false;
    } else if (NEGATIVE.includes(cleanWord)) {
      result.negative.count++;
      result.negative.words.push(cleanWord);
      result.score -= 1 * intensifierMultiplier;
      result.neutral = false;
    }
  });
  
  // Determine dominant sentiment
  if (result.score > 0) {
    result.dominantSentiment = 'positive';
  } else if (result.score < 0) {
    result.dominantSentiment = 'negative';
  }
  
  return result;
} 