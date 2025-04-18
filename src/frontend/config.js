// Real-Time Chat Application Configuration
// This file overrides values from modern-chat.js for deployment

// Override the constants using window object to avoid re-declaration errors
window.WS_URL = 'wss://3k7vcoim79.execute-api.us-west-2.amazonaws.com/demo';

// Set to true to use local sentiment analysis only (no server connection)
// This will run the app without needing a backend
window.USE_LOCAL_MODE = true;

// Set to true to simulate sentiment even in non-local mode
window.SIMULATE_SENTIMENT = true;

// These are commented out but available if needed
// window.CONNECTIONS_TABLE = 'real-time-chat-demo-connections';
// window.MESSAGES_TABLE = 'real-time-chat-demo-messages';

// Add debug message to help troubleshoot
console.log('Configuration loaded:', {
    WS_URL: window.WS_URL,
    USE_LOCAL_MODE: window.USE_LOCAL_MODE,
    SIMULATE_SENTIMENT: window.SIMULATE_SENTIMENT,
    MODE: 'STATIC S3 WEBSITE DEMO',
    VERSION: '1.0.1'
}); 