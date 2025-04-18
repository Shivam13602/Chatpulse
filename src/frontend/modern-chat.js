// Constants for API endpoints
const API_URL = 'http://localhost:3000/api';  // For any REST API calls (not used in demo)
const WS_URL = window.WS_URL || 'wss://sov1x7kc56.execute-api.us-west-2.amazonaws.com/prod';  // WebSocket URL for RealTimeChatWebSocketApi
const USE_LOCAL_MODE = window.USE_LOCAL_MODE !== undefined ? window.USE_LOCAL_MODE : false; // Set to true to use local sentiment analysis only (no server connection)
const SIMULATE_SENTIMENT = window.SIMULATE_SENTIMENT !== undefined ? window.SIMULATE_SENTIMENT : false; // Set to true to simulate sentiment even in non-local mode

// WebSocket route actions - must match API Gateway routes
const WS_ACTIONS = {
    CONNECT: '$connect',
    DISCONNECT: '$disconnect',
    DEFAULT: '$default',
    SENDMESSAGE: 'sendmessage'  // This must match the route key in API Gateway
};

// DOM Elements
const loginModal = document.getElementById('loginModal');
const usernameInput = document.getElementById('usernameInput');
const colorInput = document.getElementById('colorInput');
const loginButton = document.getElementById('loginButton');
const logoutButton = document.getElementById('logoutButton');
const toggleDarkModeButton = document.getElementById('toggleDarkMode');
const toggleSidebarButton = document.getElementById('toggleSidebar');
const sidebar = document.getElementById('sidebar');
const connectionStatus = document.getElementById('connectionStatus');
const connectionStatusText = document.getElementById('connectionStatusText');
const chatArea = document.getElementById('chatArea');
const messageInput = document.getElementById('messageInput');
const sendButton = document.getElementById('sendButton');
const typingIndicator = document.getElementById('typingIndicator');
const userList = document.getElementById('userList');
const userCount = document.getElementById('userCount');
const roomName = document.getElementById('roomName');
const emojiButton = document.getElementById('emojiButton');
const emojiPicker = document.getElementById('emojiPicker');
const emojiList = document.getElementById('emojiList');
const closeEmojiButton = document.getElementById('closeEmojiButton');

// Application state
const state = {
    user: null,
    socket: null,
    users: new Map(),
    messages: [],
    darkMode: localStorage.getItem('darkMode') === 'true',
    typingTimeout: null,
    typingUsers: new Set(),
    connectionStatus: 'disconnected', // disconnected, connecting, connected
    sidebarVisible: window.innerWidth > 768
};

// Common emojis for the emoji picker
const commonEmojis = ['😊', '👍', '❤️', '😂', '🎉', '🙌', '😎', '🔥', '✨', '🤔', '😢', '👎', '😡', '😍', '🤗', '👋', '🙏', '💯', '🌈', '💪'];

// Lists for sentiment analysis
const POSITIVE_WORDS = ['happy', 'great', 'excellent', 'good', 'awesome', 'wonderful', 'best', 'love', 'like', 'glad', 'excited', 'amazing', 'fantastic', 'nice', 'joy', 'excited', 'smile', 'beautiful', 'perfect', 'pleased'];
const NEGATIVE_WORDS = ['sad', 'bad', 'terrible', 'awful', 'worst', 'hate', 'horrible', 'disappointed', 'angry', 'frustrated', 'upset', 'mad', 'unhappy', 'dislike', 'sorry', 'unfortunately', 'annoying', 'poor', 'fail', 'sucks'];

// Initialize the application when the DOM is fully loaded
document.addEventListener('DOMContentLoaded', () => {
    initApp();
    
    // Check for dev mode in URL
    if (window.location.search.includes('dev=true')) {
        localStorage.setItem('devMode', 'true');
        console.log('Development mode enabled');
    }
});

// Initialize the application
function initApp() {
    console.log('Initializing chat application...');
    
    // Load dark mode preference
    const darkMode = localStorage.getItem('darkMode') === 'true';
    if (darkMode) {
        state.darkMode = true;
        document.body.classList.add('dark-mode');
        toggleDarkModeButton.innerHTML = '<i class="fas fa-sun"></i>';
    }
    
    // Load saved username and color
    const savedUsername = localStorage.getItem('username');
    const savedColor = localStorage.getItem('color') || '#4a6ff9';
    
    if (savedUsername) {
        usernameInput.value = savedUsername;
        colorInput.value = savedColor;
    }
    
    // Setup event listeners
    setupEventListeners();
    
    // Set up debug tools
    setupDebugTools();
    
    // Add sentiment test buttons
    setupSentimentTestButtons();
    
    // Populate emoji picker
    populateEmojiPicker();
    
    // Initialize text areas
    autoResizeTextarea(messageInput);
}

// Set up event listeners
function setupEventListeners() {
    // Login button click
    loginButton.addEventListener('click', handleLogin);
    
    // Username input enter key
    usernameInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && usernameInput.value.trim()) {
            handleLogin();
        }
    });
    
    // Logout button click
    logoutButton.addEventListener('click', handleLogout);
    
    // Send button click
    sendButton.addEventListener('click', sendMessage);
    
    // Message input events
    messageInput.addEventListener('keypress', handleMessageInputKeypress);
    messageInput.addEventListener('input', () => {
        autoResizeTextarea(messageInput);
        
        // Handle typing indicator
        if (messageInput.value.trim()) {
            sendTypingStatus(true);
        }
    });
    
    // Toggle dark mode
    toggleDarkModeButton.addEventListener('click', toggleDarkMode);
    
    // Toggle sidebar on mobile
    toggleSidebarButton.addEventListener('click', () => {
        state.sidebarVisible = !state.sidebarVisible;
        sidebar.classList.toggle('active', state.sidebarVisible);
    });
    
    // Emoji picker
    emojiButton.addEventListener('click', toggleEmojiPicker);
    closeEmojiButton.addEventListener('click', () => {
        emojiPicker.classList.add('hidden');
    });
    
    // Hide emoji picker when clicking outside
    document.addEventListener('click', (e) => {
        if (!emojiPicker.contains(e.target) && e.target !== emojiButton) {
            emojiPicker.classList.add('hidden');
        }
    });
    
    // Window resize event for sidebar
    window.addEventListener('resize', () => {
        if (window.innerWidth > 768) {
            state.sidebarVisible = true;
            sidebar.classList.add('active');
        }
    });
}

// Add a system message
function addWelcomeMessages() {
    // Welcome message
    addMessage({
        id: `system-welcome-${Date.now()}`,
        system: true,
        content: 'Welcome to the Real-Time Chat with Sentiment Analysis!'
    });
    
    // Add example messages demonstrating sentiment analysis
    setTimeout(() => {
        addMessage({
            id: `example-positive-${Date.now()}`,
            userId: 'system-examples',
            username: 'Sentiment Bot',
            content: 'I\'m happy to demonstrate positive sentiment in this message! This is great!',
            timestamp: Date.now(),
            sentiment: 2,
            color: '#17a2b8'  // info color
        });
    }, 1000);
    
    setTimeout(() => {
        addMessage({
            id: `example-neutral-${Date.now()}`,
            userId: 'system-examples',
            username: 'Sentiment Bot',
            content: 'This is a neutral message that doesn\'t express strong emotions either way.',
            timestamp: Date.now(),
            sentiment: 0,
            color: '#17a2b8'  // info color
        });
    }, 2000);
    
    setTimeout(() => {
        addMessage({
            id: `example-negative-${Date.now()}`,
            userId: 'system-examples',
            username: 'Sentiment Bot',
            content: 'I\'m sad and disappointed with this terrible example of negative sentiment.',
            timestamp: Date.now(),
            sentiment: -2,
            color: '#17a2b8'  // info color
        });
    }, 3000);
    
    setTimeout(() => {
        addMessage({
            id: `example-explanation-${Date.now()}`,
            userId: 'system-examples',
            username: 'Sentiment Bot',
            content: 'Try sending your own messages! The system will analyze the sentiment based on the words you use and display an indicator.',
            timestamp: Date.now(),
            sentiment: 1,
            color: '#17a2b8'  // info color
        });
    }, 4000);
}

// Handle login
function handleLogin() {
    const username = usernameInput.value.trim();
    const color = colorInput.value;
    
    if (username.length < 3) {
        shakeElement(usernameInput);
        return;
    }
    
    // Set user info
    state.user = {
        id: generateUserId(),
        username,
        color
    };
    
    // Save to localStorage
    localStorage.setItem('username', username);
    localStorage.setItem('color', color);
    
    // Hide login modal
    loginModal.classList.add('hidden');
    
    // Connect to WebSocket
    connectWebSocket();
    
    // Add welcome messages with sentiment examples
    addWelcomeMessages();
}

// Handle logout
function handleLogout() {
    // Disconnect from WebSocket
    if (state.socket) {
        state.socket.close();
    }
    
    // Clear state
    state.user = null;
    state.users.clear();
    state.messages = [];
    
    // Update UI
    updateUserList();
    clearChat();
    
    // Show login modal
    loginModal.classList.remove('hidden');
    
    // Update connection status
    state.connectionStatus = 'disconnected';
    updateConnectionStatus(false);
}

// Connect to WebSocket
function connectWebSocket() {
    state.connectionStatus = 'connecting';
    updateConnectionStatus(false);
    
    // If using local mode, simulate connection
    if (USE_LOCAL_MODE) {
        console.log('Using local mode (no server connection)');
        setTimeout(() => {
            state.connectionStatus = 'connected';
            updateConnectionStatus(true);
            
            // Add this user to the local users list
            state.users.set(state.user.id, {
                id: state.user.id,
                username: state.user.username,
                color: state.user.color
            });
            
            // Update UI
            updateUserList();
            
            // Add a system message
            addMessage({
                id: `system-${Date.now()}`,
                system: true,
                content: 'You joined the chat (Local Mode)'
            });
            
            // Add welcome message about local mode
            addMessage({
                id: `system-welcome-${Date.now()}`,
                system: true,
                content: 'Using local mode: Messages will use client-side sentiment analysis only.'
            });
            
            // Still add the existing welcome messages
            addWelcomeMessages();
        }, 1000);
        return;
    }
    
    try {
        // Connect to WebSocket
        state.socket = new WebSocket(WS_URL);
        
        // Socket open event
        state.socket.onopen = () => {
            console.log('WebSocket connected');
            state.connectionStatus = 'connected';
            updateConnectionStatus(true);
            
            // Send user info with body parameter for AWS API Gateway
            const message = {
                action: WS_ACTIONS.SENDMESSAGE,
                body: JSON.stringify({
                    type: 'identify',
                    userId: state.user.id,
                    username: state.user.username,
                    color: state.user.color
                })
            };
            
            console.log('Sending identify:', message);
            state.socket.send(JSON.stringify(message));
            
            // Also add this user to the local users list
            state.users.set(state.user.id, {
                id: state.user.id,
                username: state.user.username,
                color: state.user.color
            });
            
            // Update UI
            updateUserList();
            
            // Add a system message
            addMessage({
                id: `system-${Date.now()}`,
                system: true,
                content: 'You joined the chat'
            });
        };
        
        // Socket message event
        state.socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            handleWebSocketMessage(data);
        };
        
        // Socket close event
        state.socket.onclose = () => {
            console.log('WebSocket disconnected');
            state.connectionStatus = 'disconnected';
            updateConnectionStatus(false);
            
            // Attempt to reconnect if logged in
            if (state.user) {
                setTimeout(connectWebSocket, 3000);
            }
        };
        
        // Socket error event
        state.socket.onerror = (error) => {
            console.error('WebSocket error:', error);
            state.connectionStatus = 'disconnected';
            updateConnectionStatus(false);
        };
        
    } catch (error) {
        console.error('Failed to connect to WebSocket:', error);
        state.connectionStatus = 'disconnected';
        updateConnectionStatus(false);
    }
}

// Handle WebSocket messages
function handleWebSocketMessage(data) {
    console.log('Received message:', data);
    
    // Handle AWS-style error messages
    if (data.message === 'Forbidden' || data.message === 'Internal server error') {
        console.error('Server error:', data);
        return;
    }
    
    // Determine message type - AWS Lambda might not include type field directly
    let messageType = data.type;
    
    // If no type, try to determine from content
    if (!messageType) {
        if (data.messageId) {
            messageType = 'message';
        } else if (data.message === 'typing' || data.message === 'stopped_typing') {
            messageType = 'typing';
        }
    }
    
    // Extract body if message is from AWS API Gateway
    let processedData = data;
    if (data.body && typeof data.body === 'string') {
        try {
            processedData = JSON.parse(data.body);
            // Preserve the action from the original message if it exists
            if (data.action) {
                processedData.action = data.action;
            }
        } catch (e) {
            console.error('Failed to parse message body:', e);
        }
    }
    
    switch (messageType) {
        case 'message':
            // Add message to chat
            addMessage({
                id: processedData.messageId || `${processedData.userId || processedData.connectionId}-${processedData.timestamp}`,
                userId: processedData.userId,
                username: processedData.username || 'Anonymous',
                content: processedData.message,  // Changed to match AWS expected format
                timestamp: processedData.timestamp,
                sentiment: processedData.sentiment || 0, // Ensure we have a default sentiment value
                color: processedData.color
            });
            break;
            
        case 'userJoined':
            // Add user to users list
            state.users.set(processedData.userId, {
                id: processedData.userId,
                username: processedData.username,
                color: processedData.color
            });
            
            // Update users list
            updateUserList();
            
            // Add system message
            addMessage({
                id: `system-${Date.now()}`,
                system: true,
                content: `${processedData.username} joined the chat`
            });
            break;
            
        case 'userLeft':
            // Remove user from users list
            state.users.delete(processedData.userId);
            
            // Update users list
            updateUserList();
            
            // Add system message
            addMessage({
                id: `system-${Date.now()}`,
                system: true,
                content: `${processedData.username} left the chat`
            });
            
            // Remove from typing users
            state.typingUsers.delete(processedData.username);
            updateTypingStatus();
            break;
            
        case 'typing':
            const isTyping = processedData.message === 'typing' || processedData.isTyping === true;
            updateTypingStatus(processedData.username, isTyping);
            break;
            
        default:
            console.log('Unknown message type or format:', processedData);
            // If this is a normal message without explicit type
            if (processedData.message && processedData.userId) {
                addMessage({
                    id: processedData.messageId || `${processedData.userId}-${Date.now()}`,
                    userId: processedData.userId,
                    username: processedData.username || 'Anonymous',
                    content: processedData.message,
                    timestamp: processedData.timestamp || Date.now(),
                    sentiment: processedData.sentiment || 0, // Ensure we have a default sentiment value
                    color: processedData.color
                });
            }
            break;
    }
}

// Update connection status in UI
function updateConnectionStatus(connected) {
    const statusText = connected ? 'Connected' : (state.connectionStatus === 'connecting' ? 'Connecting...' : 'Disconnected');
    
    connectionStatusText.textContent = statusText;
    connectionStatus.className = 'connection-status';
    
    if (connected) {
        connectionStatus.classList.add('connected');
        setTimeout(() => {
            connectionStatus.classList.add('hidden');
        }, 3000);
    } else {
        connectionStatus.classList.remove('hidden');
        connectionStatus.classList.add('disconnected');
    }
}

// Update user list in UI
function updateUserList() {
    // Clear user list
    userList.innerHTML = '';
    
    // Update user count
    userCount.textContent = `(${state.users.size})`;
    
    // Sort users by username
    const sortedUsers = Array.from(state.users.values()).sort((a, b) => {
        // Current user first
        if (a.id === state.user?.id) return -1;
        if (b.id === state.user?.id) return 1;
        
        // Then alphabetically
        return a.username.localeCompare(b.username);
    });
    
    // Add users to list
    for (const user of sortedUsers) {
        const userItem = document.createElement('li');
        userItem.className = 'user-item';
        
        if (user.id === state.user?.id) {
            userItem.classList.add('current-user');
        }
        
        const userAvatar = document.createElement('div');
        userAvatar.className = 'user-avatar';
        userAvatar.textContent = getInitials(user.username);
        userAvatar.style.backgroundColor = user.color || '#4a6fff';
        
        const userInfo = document.createElement('div');
        userInfo.className = 'user-info';
        
        const userName = document.createElement('div');
        userName.className = 'user-name';
        userName.textContent = user.username;
        
        const userStatus = document.createElement('div');
        userStatus.className = 'user-status';
        userStatus.textContent = user.id === state.user?.id ? 'You' : 'Online';
        
        userInfo.appendChild(userName);
        userInfo.appendChild(userStatus);
        
        userItem.appendChild(userAvatar);
        userItem.appendChild(userInfo);
        
        userList.appendChild(userItem);
    }
}

// Send message
function sendMessage() {
    const content = messageInput.value.trim();
    
    if (!content || !state.user || state.connectionStatus !== 'connected') {
        return;
    }
    
    // In local mode, just add the message and simulate a response
    if (USE_LOCAL_MODE) {
        const sentimentScore = analyzeSentimentLocally(content);
        
        // Add user message
        addMessage({
            id: `self-${Date.now()}`,
            userId: state.user.id,
            username: state.user.username,
            content: content,
            timestamp: Date.now(),
            color: state.user.color,
            sentiment: sentimentScore
        });
        
        // Clear input
        messageInput.value = '';
        messageInput.style.height = 'auto';
        messageInput.focus();
        
        // Simulate a response after a delay
        setTimeout(() => {
            simulateResponse(content, sentimentScore);
        }, 1000 + Math.random() * 1500);
        
        return;
    }
    
    // Create message object with body parameter for AWS API Gateway
    const message = {
        action: WS_ACTIONS.SENDMESSAGE,
        body: JSON.stringify({
            message: content,
            userId: state.user.id,
            username: state.user.username,
            color: state.user.color,
            timestamp: Date.now()
        })
    };
    
    console.log('Sending message:', message);
    
    // Send message to server
    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
        state.socket.send(JSON.stringify(message));
        
        // Also add message to our own chat
        addMessage({
            id: `self-${Date.now()}`,
            userId: state.user.id,
            username: state.user.username,
            content: content,
            timestamp: Date.now(),
            color: state.user.color,
            // We don't know sentiment yet, server will calculate
            sentiment: 0
        });
        
        // Reset typing status
        sendTypingStatus(false);
        
        // Clear input
        messageInput.value = '';
        messageInput.style.height = 'auto';
        messageInput.focus();
    }
}

// Function to simulate a response in local mode
function simulateResponse(originalMessage, originalSentiment) {
    // Bot usernames
    const bots = [
        { name: 'Sentiment Bot', color: '#17a2b8' },
        { name: 'Chat Assistant', color: '#28a745' },
        { name: 'Response AI', color: '#6610f2' }
    ];
    
    // Select random bot
    const bot = bots[Math.floor(Math.random() * bots.length)];
    
    // Generate appropriate response based on sentiment
    let response;
    let responseColor = bot.color;
    
    if (originalSentiment > 0) {
        response = [
            "That sounds fantastic! I'm glad to hear that.",
            "Great to see such positivity! Thanks for sharing.",
            "Awesome! Your enthusiasm is contagious.",
            "I appreciate your positive attitude!",
            "That's wonderful news! Keep that positive energy."
        ][Math.floor(Math.random() * 5)];
    } else if (originalSentiment < 0) {
        response = [
            "I'm sorry to hear that. Hope things get better soon.",
            "That's unfortunate. Is there anything I can help with?",
            "I understand your frustration. Sometimes it helps to talk about it.",
            "That does sound challenging. Hang in there.",
            "I'm here to listen if you need to vent more."
        ][Math.floor(Math.random() * 5)];
    } else {
        response = [
            "Interesting point. Thanks for sharing that.",
            "I see what you mean. Could you elaborate more?",
            "That's a valid perspective. What else do you think?",
            "I understand. Let me know if you have other thoughts.",
            "Thanks for the update. Keep the conversation going!"
        ][Math.floor(Math.random() * 5)];
    }
    
    // Calculate sentiment for the response
    const responseSentiment = analyzeSentimentLocally(response);
    
    // Add bot response message
    addMessage({
        id: `bot-${Date.now()}`,
        userId: `bot-${bot.name.toLowerCase().replace(/\s+/g, '-')}`,
        username: bot.name,
        content: response,
        timestamp: Date.now(),
        color: responseColor,
        sentiment: responseSentiment
    });
}

// Add message to chat
function addMessage(message) {
    // Check if message already exists
    if (document.querySelector(`[data-message-id="${message.id}"]`)) {
        return;
    }
    
    // Create message element
    const messageElement = document.createElement('div');
    messageElement.className = 'message';
    messageElement.setAttribute('data-message-id', message.id);
    
    if (message.system) {
        // System message
        messageElement.className = 'message message-system';
        
        const messageContent = document.createElement('div');
        messageContent.className = 'message-content system-content';
        messageContent.textContent = message.content;
        
        messageElement.appendChild(messageContent);
    } else {
        // User message
        const isOwnMessage = message.userId === state.user?.id;
        
        if (isOwnMessage) {
            messageElement.classList.add('message-own');
        } else {
            messageElement.classList.add('message-other');
        }
        
        // Add sentiment class
        let sentimentClass = 'sentiment-neutral';
        let sentimentText = 'Neutral';
        
        // If sentiment is not provided or is 0, use local sentiment analysis
        if (message.sentiment === undefined || message.sentiment === 0) {
            message.sentiment = analyzeSentimentLocally(message.content);
        }
        
        if (typeof message.sentiment === 'number') {
            if (message.sentiment > 0) {
                sentimentClass = 'sentiment-positive';
                sentimentText = 'Positive';
            } else if (message.sentiment < 0) {
                sentimentClass = 'sentiment-negative';
                sentimentText = 'Negative';
            }
        }
        messageElement.classList.add(sentimentClass);
        
        // Message header
        const messageHeader = document.createElement('div');
        messageHeader.className = 'message-header';
        
        // Username for others' messages
        if (!isOwnMessage) {
            const messageUsername = document.createElement('div');
            messageUsername.className = 'message-username';
            messageUsername.textContent = message.username;
            messageUsername.style.color = message.color || '#4a6fff';
            messageHeader.appendChild(messageUsername);
        }
        
        // Message time
        const messageTime = document.createElement('div');
        messageTime.className = 'message-time';
        const date = new Date(message.timestamp);
        messageTime.textContent = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        messageHeader.appendChild(messageTime);
        
        // Message content
        const messageContent = document.createElement('div');
        messageContent.className = 'message-content';
        messageContent.innerHTML = formatMessageContent(message.content);
        
        // Add sentiment indicator
        const sentimentIndicator = document.createElement('div');
        sentimentIndicator.className = 'message-sentiment';
        
        // Create sentiment icon based on the sentiment value
        const sentimentIcon = document.createElement('i');
        if (sentimentClass === 'sentiment-positive') {
            sentimentIcon.className = 'fas fa-smile';
        } else if (sentimentClass === 'sentiment-negative') {
            sentimentIcon.className = 'fas fa-frown';
        } else {
            sentimentIcon.className = 'fas fa-meh';
        }
        
        // Create sentiment label
        const sentimentLabel = document.createElement('span');
        sentimentLabel.textContent = sentimentText;
        if (typeof message.sentiment === 'number') {
            sentimentLabel.textContent += ` (${message.sentiment})`;
        }
        
        sentimentIndicator.appendChild(sentimentIcon);
        sentimentIndicator.appendChild(sentimentLabel);
        
        // Assemble message
        messageElement.appendChild(messageHeader);
        messageElement.appendChild(messageContent);
        messageElement.appendChild(sentimentIndicator);
    }
    
    // Add to chat area
    chatArea.appendChild(messageElement);
    
    // Scroll to bottom
    scrollToBottom();
    
    // Store in messages array
    state.messages.push(message);
}

// Format message content with emojis and links
function formatMessageContent(content) {
    // Replace URLs with links
    content = content.replace(/(https?:\/\/[^\s]+)/g, '<a href="$1" target="_blank">$1</a>');
    
    return content;
}

// Send typing status
function sendTypingStatus(isTyping) {
    if (!state.user || state.connectionStatus !== 'connected') {
        return;
    }
    
    // Clear previous timeout
    if (state.typingTimeout) {
        clearTimeout(state.typingTimeout);
    }
    
    // Send typing status with body parameter for AWS API Gateway
    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
        state.socket.send(JSON.stringify({
            action: WS_ACTIONS.SENDMESSAGE,
            body: JSON.stringify({
                type: 'typing',
                message: isTyping ? 'typing' : 'stopped_typing',
                userId: state.user.id,
                username: state.user.username,
                isTyping
            })
        }));
    }
    
    // Set timeout to automatically set typing to false
    if (isTyping) {
        state.typingTimeout = setTimeout(() => {
            sendTypingStatus(false);
        }, 3000);
    }
}

// Update typing status in UI
function updateTypingStatus(username, isTyping) {
    if (!username) {
        // Just update UI
        const typingUsers = Array.from(state.typingUsers);
        
        if (typingUsers.length === 0) {
            typingIndicator.classList.add('hidden');
        } else if (typingUsers.length === 1) {
            typingIndicator.querySelector('span').textContent = `${typingUsers[0]} is typing...`;
            typingIndicator.classList.remove('hidden');
        } else if (typingUsers.length === 2) {
            typingIndicator.querySelector('span').textContent = `${typingUsers[0]} and ${typingUsers[1]} are typing...`;
            typingIndicator.classList.remove('hidden');
        } else {
            typingIndicator.querySelector('span').textContent = 'Several people are typing...';
            typingIndicator.classList.remove('hidden');
        }
        
        return;
    }
    
    // Skip current user
    if (username === state.user?.username) {
        return;
    }
    
    // Update typing users set
    if (isTyping) {
        state.typingUsers.add(username);
    } else {
        state.typingUsers.delete(username);
    }
    
    // Update UI
    updateTypingStatus();
}

// Handle message input keypress
function handleMessageInputKeypress(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
    }
}

// Clear chat area
function clearChat() {
    chatArea.innerHTML = '';
    state.messages = [];
}

// Toggle dark mode
function toggleDarkMode() {
    state.darkMode = !state.darkMode;
    
    // Update body class
    document.body.classList.toggle('dark-mode', state.darkMode);
    
    // Update icon
    toggleDarkModeButton.innerHTML = state.darkMode ? 
        '<i class="fas fa-sun"></i>' : 
        '<i class="fas fa-moon"></i>';
    
    // Save preference
    localStorage.setItem('darkMode', state.darkMode);
}

// Toggle emoji picker
function toggleEmojiPicker() {
    emojiPicker.classList.toggle('hidden');
}

// Populate emoji picker
function populateEmojiPicker() {
    emojiList.innerHTML = '';
    
    // Add emojis
    for (const emoji of commonEmojis) {
        const emojiButton = document.createElement('button');
        emojiButton.className = 'emoji-button';
        emojiButton.textContent = emoji;
        
        emojiButton.addEventListener('click', () => {
            insertAtCursor(messageInput, emoji);
            emojiPicker.classList.add('hidden');
            messageInput.focus();
        });
        
        emojiList.appendChild(emojiButton);
    }
}

// Get user initials for avatar
function getInitials(name) {
    if (!name) return '?';
    
    const parts = name.trim().split(/\s+/);
    
    if (parts.length === 1) {
        return parts[0].charAt(0).toUpperCase();
    } else {
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }
}

// Scroll chat area to bottom
function scrollToBottom() {
    chatArea.scrollTop = chatArea.scrollHeight;
}

// Shake an element to indicate error
function shakeElement(element) {
    element.classList.add('shake');
    setTimeout(() => {
        element.classList.remove('shake');
    }, 820); // Animation duration + small buffer
}

// Insert text at cursor position in input
function insertAtCursor(input, text) {
    const start = input.selectionStart;
    const end = input.selectionEnd;
    const before = input.value.substring(0, start);
    const after = input.value.substring(end, input.value.length);
    
    input.value = before + text + after;
    
    // Set cursor position after the inserted text
    input.selectionStart = input.selectionEnd = start + text.length;
    
    // Trigger input event to resize textarea
    const event = new Event('input', { bubbles: true });
    input.dispatchEvent(event);
}

// Auto-resize textarea based on content
function autoResizeTextarea(textarea) {
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 150) + 'px';
}

// DEBUG function to simulate receiving messages with different sentiment values
function simulateSentimentMessage(sentiment, content) {
    const testMessage = {
        id: `test-${Date.now()}`,
        userId: 'system-test',
        username: 'Sentiment Bot',
        content: content || `This is a test message with ${sentiment > 0 ? 'positive' : (sentiment < 0 ? 'negative' : 'neutral')} sentiment.`,
        timestamp: Date.now(),
        sentiment: sentiment,
        color: '#17a2b8'  // info color
    };
    
    addMessage(testMessage);
    
    // Log for debugging
    console.log('Simulated message with sentiment:', testMessage);
}

// Add debugging buttons if in development mode
function setupDebugTools() {
    // Check if we're in development mode (you can set this in localStorage or based on URL)
    if (localStorage.getItem('devMode') === 'true' || window.location.search.includes('dev=true')) {
        const debugContainer = document.createElement('div');
        debugContainer.className = 'debug-container';
        debugContainer.innerHTML = `
            <div class="debug-header">
                <button id="toggleDebug" class="btn btn-sm">
                    <i class="fas fa-bug"></i> Sentiment Test Tools
                </button>
            </div>
            <div class="debug-content hidden">
                <div class="debug-buttons">
                    <button class="btn btn-sm debug-btn" data-sentiment="2">Test Positive</button>
                    <button class="btn btn-sm debug-btn" data-sentiment="0">Test Neutral</button>
                    <button class="btn btn-sm debug-btn" data-sentiment="-2">Test Negative</button>
                </div>
                <div class="debug-input">
                    <input type="number" id="customSentiment" min="-5" max="5" value="0" step="1">
                    <button id="testCustom" class="btn btn-sm">Test Custom</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(debugContainer);
        
        // Toggle debug panel
        document.getElementById('toggleDebug').addEventListener('click', () => {
            document.querySelector('.debug-content').classList.toggle('hidden');
        });
        
        // Handle sentiment test buttons
        document.querySelectorAll('.debug-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const sentiment = parseInt(btn.dataset.sentiment);
                simulateSentimentMessage(sentiment);
            });
        });
        
        // Handle custom sentiment test
        document.getElementById('testCustom').addEventListener('click', () => {
            const sentiment = parseInt(document.getElementById('customSentiment').value);
            simulateSentimentMessage(sentiment);
        });
    }
}

// Generate unique user ID
function generateUserId() {
    return 'user_' + Date.now().toString() + '_' + Math.random().toString(36).substr(2, 9);
}

// Local sentiment analysis function (fallback if server doesn't provide sentiment)
function analyzeSentimentLocally(text) {
    if (!text) return 0;
    
    let score = 0;
    const words = text.toLowerCase().split(/\s+/);
    
    for (const word of words) {
        const cleanWord = word.replace(/[^\w]/g, ''); // Remove punctuation
        if (POSITIVE_WORDS.includes(cleanWord)) {
            score += 1;
        } else if (NEGATIVE_WORDS.includes(cleanWord)) {
            score -= 1;
        }
    }
    
    console.log(`Local sentiment analysis for "${text}": ${score}`);
    return score;
}

// Add sentiment test buttons to the UI
function setupSentimentTestButtons() {
    // Create container for test buttons
    const sentimentTestContainer = document.createElement('div');
    sentimentTestContainer.className = 'sentiment-test-buttons';
    sentimentTestContainer.style.position = 'absolute';
    sentimentTestContainer.style.bottom = '80px';
    sentimentTestContainer.style.right = '20px';
    sentimentTestContainer.style.display = 'flex';
    sentimentTestContainer.style.flexDirection = 'column';
    sentimentTestContainer.style.gap = '5px';
    sentimentTestContainer.style.zIndex = '100';
    
    // Create toggle button
    const toggleButton = document.createElement('button');
    toggleButton.className = 'btn btn-sm btn-circle';
    toggleButton.innerHTML = '<i class="fas fa-flask"></i>';
    toggleButton.title = 'Test Sentiment Analysis';
    toggleButton.style.backgroundColor = '#6c757d';
    toggleButton.style.color = 'white';
    
    // Create test buttons container (initially hidden)
    const buttonsContainer = document.createElement('div');
    buttonsContainer.className = 'test-buttons-container hidden';
    buttonsContainer.style.display = 'flex';
    buttonsContainer.style.flexDirection = 'column';
    buttonsContainer.style.gap = '5px';
    buttonsContainer.style.marginBottom = '5px';
    
    // Create sentiment test buttons
    const positiveButton = createTestButton('Positive', '#28a745', 'I am happy and excited about this amazing chat!');
    const neutralButton = createTestButton('Neutral', '#6c757d', 'This is a regular message with no strong emotions.');
    const negativeButton = createTestButton('Negative', '#dc3545', 'I am sad and disappointed with the terrible weather today.');
    
    // Add buttons to container
    buttonsContainer.appendChild(positiveButton);
    buttonsContainer.appendChild(neutralButton);
    buttonsContainer.appendChild(negativeButton);
    
    // Add toggle functionality
    toggleButton.addEventListener('click', () => {
        buttonsContainer.classList.toggle('hidden');
    });
    
    // Add elements to container
    sentimentTestContainer.appendChild(buttonsContainer);
    sentimentTestContainer.appendChild(toggleButton);
    
    // Add to chat content
    document.querySelector('.chat-content').appendChild(sentimentTestContainer);
}

// Helper function to create test buttons
function createTestButton(text, color, message) {
    const button = document.createElement('button');
    button.className = 'btn btn-sm';
    button.textContent = `Test ${text}`;
    button.style.backgroundColor = color;
    button.style.color = 'white';
    button.style.minWidth = '120px';
    
    button.addEventListener('click', () => {
        if (state.connectionStatus !== 'connected') {
            alert('Please connect to chat first');
            return;
        }
        
        // Set the message in the input field
        messageInput.value = message;
        // Trigger the send button click
        sendButton.click();
    });
    
    return button;
} 