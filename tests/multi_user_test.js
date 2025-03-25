const WebSocket = require('ws');

// WebSocket API endpoint
const WS_ENDPOINT = 'wss://haq5j7myy4.execute-api.us-west-2.amazonaws.com/prod';

// Test users
const users = [
  { username: 'User1', connectionId: null, ws: null },
  { username: 'User2', connectionId: null, ws: null },
  { username: 'User3', connectionId: null, ws: null }
];

// Test messages with different sentiments
const messages = [
  { text: 'Hello everyone! I am so happy to be here. This is really great!', expectedSentiment: 'positive' },
  { text: 'I am feeling a bit sad and disappointed today.', expectedSentiment: 'negative' },
  { text: 'This is just a normal message with no particular sentiment.', expectedSentiment: 'neutral' }
];

// Connect all users
const connectUsers = async () => {
  console.log('Connecting users...');
  
  for (const user of users) {
    await new Promise((resolve) => {
      const ws = new WebSocket(`${WS_ENDPOINT}?username=${user.username}`);
      
      ws.on('open', () => {
        console.log(`${user.username} connected`);
        user.ws = ws;
        
        // Set up message handler
        ws.on('message', (data) => {
          const message = JSON.parse(data.toString());
          console.log(`${user.username} received:`, message);
          
          if (message.type === 'message') {
            const sentimentText = getSentimentText(message.data.sentiment);
            console.log(`Message sentiment: ${sentimentText} (${message.data.sentiment})`);
          }
        });
        
        resolve();
      });
      
      ws.on('error', (error) => {
        console.error(`${user.username} connection error:`, error);
        resolve();
      });
    });
    
    // Wait a bit between connections
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
};

// Send test messages
const sendTestMessages = async () => {
  console.log('\nSending test messages...');
  
  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    const message = messages[i % messages.length];
    
    if (user.ws && user.ws.readyState === WebSocket.OPEN) {
      console.log(`${user.username} sending: "${message.text}"`);
      console.log(`Expected sentiment: ${message.expectedSentiment}`);
      
      user.ws.send(JSON.stringify({
        action: 'sendMessage',
        data: message.text,
        userId: user.username
      }));
      
      // Wait a bit between messages
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
};

// Helper function to convert sentiment score to text
function getSentimentText(score) {
  if (score > 0) return 'positive';
  if (score < 0) return 'negative';
  return 'neutral';
}

// Main test function
const runTest = async () => {
  try {
    await connectUsers();
    await sendTestMessages();
    
    console.log('\nTest complete! Keeping connections open to receive messages...');
    
    // Keep the script running for a while to receive all messages
    setTimeout(() => {
      console.log('Closing connections...');
      users.forEach(user => {
        if (user.ws) user.ws.close();
      });
      console.log('Test finished.');
    }, 10000);
    
  } catch (error) {
    console.error('Test error:', error);
  }
};

// Run the test
runTest(); 