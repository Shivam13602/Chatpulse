/**
 * WebSocket Client Test Script
 * 
 * This script tests connectivity to the WebSocket API endpoint and
 * basic message functionality for the Real-Time Chat Application.
 * 
 * Usage: node test_websocket.js <websocket_url> <username>
 */

const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

// Parse command line arguments
const [,, websocketUrl, username = 'tester-' + Math.floor(Math.random() * 1000)] = process.argv;

if (!websocketUrl) {
  console.error('Error: WebSocket URL is required');
  console.log('Usage: node test_websocket.js <websocket_url> <username>');
  process.exit(1);
}

// Add query parameters to WebSocket URL
const connectionUrl = `${websocketUrl}?userId=${uuidv4()}&username=${username}&clientInfo=test-script`;

console.log(`
=========================================
WebSocket Test Client
=========================================
URL: ${connectionUrl}
Username: ${username}
=========================================
`);

// Create WebSocket connection
const ws = new WebSocket(connectionUrl);

// Connection opened
ws.on('open', () => {
  console.log('✅ Connection established successfully!');
  runTests(ws);
});

// Listen for messages
ws.on('message', (data) => {
  try {
    const message = JSON.parse(data);
    console.log('\n📩 Received message:');
    console.log(JSON.stringify(message, null, 2));
  } catch (error) {
    console.log(`\n📩 Received raw message: ${data}`);
  }
});

// Handle errors
ws.on('error', (error) => {
  console.error(`\n❌ WebSocket error:`, error.message);
});

// Connection closed
ws.on('close', (code, reason) => {
  console.log(`\n🔌 Connection closed: Code ${code}${reason ? ', Reason: ' + reason : ''}`);
  process.exit(0);
});

/**
 * Run a series of tests
 * @param {WebSocket} ws - WebSocket connection
 */
function runTests(ws) {
  // Test 1: Send a simple message
  setTimeout(() => {
    console.log('\n🧪 TEST 1: Sending simple message');
    sendMessage(ws, 'Hello, this is a test message!');
  }, 1000);

  // Test 2: Send a message with positive sentiment
  setTimeout(() => {
    console.log('\n🧪 TEST 2: Sending positive message');
    sendMessage(ws, 'This is amazing! I love this chat application, it works perfectly!');
  }, 3000);

  // Test 3: Send a message with negative sentiment
  setTimeout(() => {
    console.log('\n🧪 TEST 3: Sending negative message');
    sendMessage(ws, 'This is terrible and frustrating. I hate when things break.');
  }, 5000);

  // Test 4: Send an invalid format message
  setTimeout(() => {
    console.log('\n🧪 TEST 4: Sending invalid format message');
    ws.send(JSON.stringify({ invalid: 'format' }));
  }, 7000);

  // Test 5: Send ping message
  setTimeout(() => {
    console.log('\n🧪 TEST 5: Sending ping message');
    sendMessage(ws, 'ping', 'ping');
  }, 9000);

  // Complete tests
  setTimeout(() => {
    console.log('\n✅ All tests completed! Closing connection...');
    ws.close();
  }, 11000);
}

/**
 * Send a message through WebSocket
 * @param {WebSocket} ws - WebSocket connection
 * @param {string} text - Message text
 * @param {string} action - Message action (default: sendMessage)
 */
function sendMessage(ws, text, action = 'sendMessage') {
  const message = {
    action,
    data: {
      text,
      timestamp: new Date().toISOString(),
      userId: uuidv4(),
      username: username
    }
  };

  console.log(`📤 Sending message: ${text}`);
  ws.send(JSON.stringify(message));
} 