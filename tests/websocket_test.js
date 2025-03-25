const WebSocket = require('ws');

// Create a WebSocket connection to our API
const ws = new WebSocket('wss://haq5j7myy4.execute-api.us-west-2.amazonaws.com/prod?username=testuser');

// Connection opened
ws.on('open', function() {
  console.log('Connected to WebSocket API');
  
  // Send a test message with the 'sendMessage' action
  const message = {
    action: 'sendMessage',
    data: 'Hello! This is a test message with the fixed action name and UUID dependency.',
    userId: 'testuser'
  };
  
  ws.send(JSON.stringify(message));
  console.log('Test message sent');
});

// Listen for messages
ws.on('message', function(data) {
  console.log('Received message from server:', data.toString());
});

// Handle errors
ws.on('error', function(error) {
  console.error('WebSocket error:', error);
});

// Connection closed
ws.on('close', function() {
  console.log('Connection closed');
}); 