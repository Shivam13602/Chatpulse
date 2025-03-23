/**
 * WebSocket API Testing Script
 * 
 * This script helps test the WebSocket API for the Real-Time Chat Application.
 * 
 * Usage:
 * 1. Update the WebSocket endpoint URL below
 * 2. Run: node test-websocket.js
 */

const WebSocket = require('ws');
const readline = require('readline');

// Configuration - Update with your actual WebSocket URL from CloudFormation output
const WS_ENDPOINT = 'wss://xxxxx.execute-api.xx-xxxx-x.amazonaws.com/prod';

// Setup readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Connect to WebSocket
console.log(`Connecting to WebSocket endpoint: ${WS_ENDPOINT}`);
const ws = new WebSocket(WS_ENDPOINT);

// WebSocket event handlers
ws.on('open', () => {
  console.log('Connected to WebSocket endpoint');
  console.log('Type messages to send. Press Ctrl+C to exit.');
  
  rl.on('line', (input) => {
    const message = {
      action: 'sendmessage',
      data: input,
      userId: 'test-user-' + Math.floor(Math.random() * 1000)
    };
    
    ws.send(JSON.stringify(message));
    console.log(`Sent: ${input}`);
  });
});

ws.on('message', (data) => {
  try {
    const message = JSON.parse(data);
    console.log('\nReceived:');
    console.log(`From: ${message.data.userId}`);
    console.log(`Message: ${message.data.content}`);
    console.log(`Sentiment: ${message.data.sentiment}`);
    console.log('> ');
  } catch (err) {
    console.log('Received (raw):', data);
  }
});

ws.on('error', (error) => {
  console.error('WebSocket Error:', error);
});

ws.on('close', () => {
  console.log('Connection closed');
  rl.close();
  process.exit(0);
});

// Handle process termination
process.on('SIGINT', () => {
  console.log('\nClosing connection...');
  ws.close();
}); 