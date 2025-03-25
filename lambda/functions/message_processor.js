const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS clients
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const apiGateway = new AWS.ApiGatewayManagementApi();
const s3 = new AWS.S3();
const eventBridge = new AWS.EventBridge();

// Environment variables
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE;
const MESSAGES_TABLE = process.env.MESSAGES_TABLE;
const EVENT_BUS_NAME = process.env.EVENT_BUS_NAME;
const WEBSOCKET_ENDPOINT = process.env.WEBSOCKET_ENDPOINT;

// Configure API Gateway endpoint
apiGateway.endpoint = `https://${WEBSOCKET_ENDPOINT}`;

// Simple sentiment analysis word lists
const POSITIVE_WORDS = ['happy', 'good', 'great', 'excellent', 'awesome', 'fantastic', 'love', 'like', 'nice', 'wonderful', 
                      'amazing', 'best', 'better', 'fantastic', 'cool', 'perfect', 'fun', 'enjoy', 'beautiful', 'pretty'];
const NEGATIVE_WORDS = ['sad', 'bad', 'terrible', 'awful', 'hate', 'dislike', 'angry', 'worse', 'worst', 'horrible', 
                      'annoying', 'frustrating', 'stupid', 'boring', 'ugly', 'disappointed', 'poor', 'nasty', 'fail', 'sucks'];

/**
 * Main Lambda handler function for processing incoming WebSocket messages
 */
exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event));
  
  // For API Gateway WebSocket events
  if (event.requestContext && event.requestContext.connectionId) {
    const connectionId = event.requestContext.connectionId;
    const routeKey = event.requestContext.routeKey;
    
    // Only handle sendMessage route
    if (routeKey === 'sendMessage') {
      try {
        const body = JSON.parse(event.body);
        if (!body.message || typeof body.message !== 'string') {
          return { statusCode: 400, body: 'Invalid message format. Expected { "message": "your message" }' };
        }
        
        // Process and store message
        const message = {
          messageId: uuidv4(),
          connectionId: connectionId,
          username: body.username || 'Anonymous',
          message: body.message,
          sentiment: await analyzeSentiment(body.message),
          timestamp: new Date().toISOString()
        };
        
        // Store message in DynamoDB
        await storeMessage(message);
        
        // Publish message creation event to EventBridge
        await publishMessageCreatedEvent(message);
        
        // Successfully processed
        return { statusCode: 200, body: 'Message received' };
      } catch (error) {
        console.error('Error processing message:', error);
        return { statusCode: 500, body: 'Failed to process message' };
      }
    }
  } 
  // For EventBridge events
  else if (event.source === 'chat.application') {
    try {
      // Handle different event types
      if (event['detail-type'] === 'SentimentAnalysisCompleted') {
        await handleSentimentAnalysisCompleted(event.detail);
        return { statusCode: 200 };
      } else if (event['detail-type'] === 'ModelTrainingCompleted') {
        console.log('Model training completed:', event.detail);
        // Could trigger model reload or other actions
        return { statusCode: 200 };
      }
    } catch (error) {
      console.error('Error handling EventBridge event:', error);
      return { statusCode: 500 };
    }
  }

  // Default response for unhandled event types
  return { statusCode: 400, body: 'Unhandled event type' };
};

/**
 * Store a message in DynamoDB
 */
async function storeMessage(message) {
  const params = {
    TableName: MESSAGES_TABLE,
    Item: message
  };
  
  await dynamoDB.put(params).promise();
  console.log('Message stored in DynamoDB:', message.messageId);
  return message;
}

/**
 * Analyze sentiment of message text
 */
async function analyzeSentiment(text) {
  try {
    // Attempt to get the sentiment model from S3
    const modelData = await getModelFromS3();
    
    // If we have a sentiment model, use it
    if (modelData) {
      return analyzeWithCustomModel(text, modelData);
    } else {
      // Basic sentiment analysis fallback
      return basicSentimentAnalysis(text);
    }
  } catch (error) {
    console.error('Error in sentiment analysis:', error);
    // Return neutral sentiment if analysis fails
    return { score: 0, magnitude: 0, label: 'NEUTRAL' };
  }
}

/**
 * Get sentiment model from S3
 */
async function getModelFromS3() {
  try {
    const params = {
      Bucket: process.env.S3_BUCKET_NAME || 'chat-application-bucket',
      Key: 'models/sentiment_model.json'
    };
    
    const response = await s3.getObject(params).promise();
    const modelData = JSON.parse(response.Body.toString());
    return modelData;
  } catch (error) {
    console.log('Model not found in S3, using basic sentiment:', error);
    return null;
  }
}

/**
 * Analyze text using custom sentiment model
 */
function analyzeWithCustomModel(text, model) {
  const words = text.toLowerCase().split(/\s+/);
  let positiveCount = 0;
  let negativeCount = 0;
  
  words.forEach(word => {
    if (model.positive_words.includes(word)) positiveCount++;
    if (model.negative_words.includes(word)) negativeCount++;
  });
  
  // Calculate sentiment score (-1 to 1)
  const totalWords = words.length || 1;
  const score = (positiveCount - negativeCount) / totalWords;
  
  // Calculate magnitude (0 to 1)
  const magnitude = (positiveCount + negativeCount) / totalWords;
  
  // Determine sentiment label
  let label = 'NEUTRAL';
  if (score > 0.2) label = 'POSITIVE';
  else if (score < -0.2) label = 'NEGATIVE';
  
  // Execute sentiment analysis asynchronously to avoid blocking
  publishSentimentEvent(text, { 
    score, 
    magnitude, 
    label,
    positiveWords: positiveCount,
    negativeWords: negativeCount 
  });
  
  return { score, magnitude, label };
}

/**
 * Basic sentiment analysis fallback
 */
function basicSentimentAnalysis(text) {
  const positiveWords = ['good', 'great', 'excellent', 'happy', 'love', 'like', 'best'];
  const negativeWords = ['bad', 'awful', 'terrible', 'sad', 'hate', 'dislike', 'worst'];
  
  const words = text.toLowerCase().split(/\s+/);
  let positiveCount = 0;
  let negativeCount = 0;
  
  words.forEach(word => {
    if (positiveWords.includes(word)) positiveCount++;
    if (negativeWords.includes(word)) negativeCount++;
  });
  
  // Calculate score and magnitude
  const totalWords = words.length || 1;
  const score = (positiveCount - negativeCount) / totalWords;
  const magnitude = (positiveCount + negativeCount) / totalWords;
  
  // Determine sentiment label
  let label = 'NEUTRAL';
  if (score > 0.2) label = 'POSITIVE';
  else if (score < -0.2) label = 'NEGATIVE';
  
  // Execute sentiment analysis asynchronously to avoid blocking
  publishSentimentEvent(text, { 
    score, 
    magnitude, 
    label,
    positiveWords: positiveCount,
    negativeWords: negativeCount 
  });
  
  return { score, magnitude, label };
}

/**
 * Publish a message created event to EventBridge
 */
async function publishMessageCreatedEvent(message) {
  if (!EVENT_BUS_NAME) {
    console.log('EventBridge bus name not specified, skipping event publishing');
    return;
  }
  
  try {
    const params = {
      Entries: [
        {
          Source: 'chat.application',
          DetailType: 'MessageCreated',
          Detail: JSON.stringify({
            messageId: message.messageId,
            connectionId: message.connectionId,
            username: message.username,
            sentiment: message.sentiment,
            timestamp: message.timestamp
          }),
          EventBusName: EVENT_BUS_NAME
        }
      ]
    };
    
    const result = await eventBridge.putEvents(params).promise();
    console.log('Published MessageCreated event:', result);
    return result;
  } catch (error) {
    console.error('Error publishing MessageCreated event:', error);
    // Continue execution even if event publishing fails
  }
}

/**
 * Publish a sentiment analysis event to EventBridge
 */
async function publishSentimentEvent(text, sentiment) {
  if (!EVENT_BUS_NAME) {
    console.log('EventBridge bus name not specified, skipping event publishing');
    return;
  }
  
  try {
    const params = {
      Entries: [
        {
          Source: 'chat.application',
          DetailType: 'SentimentAnalysisCompleted',
          Detail: JSON.stringify({
            text: text,
            sentiment: sentiment,
            timestamp: new Date().toISOString()
          }),
          EventBusName: EVENT_BUS_NAME
        }
      ]
    };
    
    const result = await eventBridge.putEvents(params).promise();
    console.log('Published SentimentAnalysisCompleted event:', result);
    return result;
  } catch (error) {
    console.error('Error publishing SentimentAnalysisCompleted event:', error);
    // Continue execution even if event publishing fails
  }
}

/**
 * Handle sentiment analysis completed event
 */
async function handleSentimentAnalysisCompleted(detail) {
  console.log('Handling sentiment analysis completed event:', detail);
  
  // In a real application, we might update the message with the new sentiment
  // or trigger other actions based on the sentiment
  
  return { success: true };
} 