# Simplified deployment script for Real-Time Chat Application
# This script only deploys the frontend to S3 in demo mode (no backend services)

Write-Host "=============================================================="
Write-Host "Simplified S3 Deployment for Real-Time Chat Application" -ForegroundColor Cyan
Write-Host "=============================================================="
Write-Host "This script will deploy only the frontend portion of the application"
Write-Host "to an S3 bucket in demo mode (no backend services required)."
Write-Host "=============================================================="

# Verify AWS credentials are set
if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY -or -not $env:AWS_SESSION_TOKEN) {
    Write-Host "`nPlease enter your AWS Academy credentials:" -ForegroundColor Yellow
    Write-Host "AWS Access Key ID: " -NoNewline
    $env:AWS_ACCESS_KEY_ID = Read-Host
    Write-Host "AWS Secret Access Key: " -NoNewline
    $env:AWS_SECRET_ACCESS_KEY = Read-Host
    Write-Host "AWS Session Token: " -NoNewline
    $env:AWS_SESSION_TOKEN = Read-Host
}

$env:AWS_DEFAULT_REGION = "us-east-1"
$REGION = "us-east-1"

# Verify AWS credentials
Write-Host "`nVerifying AWS credentials..." -ForegroundColor Cyan
try {
    $identityCheck = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Failed to authenticate with AWS. Please check your credentials and try again." -ForegroundColor Red
        Write-Host $identityCheck
        exit 1
    }
    
    $identity = $identityCheck | ConvertFrom-Json
    Write-Host "✅ AWS credentials verified successfully." -ForegroundColor Green
    Write-Host "Account ID: $($identity.Account)" -ForegroundColor Green
    Write-Host "User ARN: $($identity.Arn)" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Failed to authenticate with AWS. Please check your credentials and try again." -ForegroundColor Red
    Write-Host $_
    exit 1
}

# Create S3 bucket for the frontend
$S3_BUCKET = "real-time-chat-$((Get-Date).ToString('yyyyMMddHHmmss'))"
Write-Host "`nCreating S3 bucket for frontend: $S3_BUCKET" -ForegroundColor Cyan
try {
    $createBucket = aws s3api create-bucket --bucket $S3_BUCKET --region $REGION 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Failed to create S3 bucket. Please check your permissions." -ForegroundColor Red
        Write-Host $createBucket
        exit 1
    }
    Write-Host "✅ S3 bucket created successfully." -ForegroundColor Green
    
    # Set bucket ownership controls
    aws s3api put-bucket-ownership-controls --bucket $S3_BUCKET --ownership-controls="Rules=[{ObjectOwnership=BucketOwnerPreferred}]" 2>&1 | Out-Null
    
    # Configure bucket for website hosting
    Write-Host "`nConfiguring bucket for static website hosting..." -ForegroundColor Cyan
    aws s3 website "s3://$S3_BUCKET" --index-document index.html 2>&1 | Out-Null
    Write-Host "✅ Static website hosting configured." -ForegroundColor Green
    
    # Set up public access configuration
    Write-Host "`nConfiguring bucket for public access..." -ForegroundColor Cyan
    aws s3api put-public-access-block --bucket $S3_BUCKET --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" 2>&1 | Out-Null
    
    # Create bucket policy for public read
    $policyJson = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$S3_BUCKET/*"
        }
    ]
}
"@
    
    # Save policy to temp file
    $policyFile = "temp_policy.json"
    Set-Content -Path $policyFile -Value $policyJson
    
    # Apply policy to bucket
    aws s3api put-bucket-policy --bucket $S3_BUCKET --policy file://$policyFile 2>&1 | Out-Null
    Remove-Item -Path $policyFile
    Write-Host "✅ Bucket policy configured for public access." -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Failed to configure S3 bucket." -ForegroundColor Red
    Write-Host $_
    exit 1
}

# Create or update the frontend files with demo mode enabled
Write-Host "`nPreparing frontend files with demo mode enabled..." -ForegroundColor Cyan

# Define directory for frontend files
$frontendDir = "frontend_temp"
if (Test-Path $frontendDir) {
    Remove-Item -Path $frontendDir -Recurse -Force
}
New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null

# Check if the src/frontend directory exists
if (Test-Path "src/frontend") {
    $sourceDir = "src/frontend"
} else {
    # Fallback to creating a basic frontend if the frontend directory doesn't exist
    $sourceDir = $null
    Write-Host "⚠️ Frontend source directory not found. Creating a basic demo frontend." -ForegroundColor Yellow
    
    # Create a basic index.html file for demo purposes
    $indexHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Real-Time Chat Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .chat-container {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 20px;
            margin-bottom: 20px;
        }
        .demo-banner {
            background-color: #ff9800;
            color: white;
            padding: 10px;
            text-align: center;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .message-list {
            height: 300px;
            overflow-y: auto;
            border: 1px solid #e0e0e0;
            padding: 10px;
            margin-bottom: 10px;
            background-color: #f9f9f9;
        }
        .message {
            margin-bottom: 10px;
            padding: 8px 12px;
            border-radius: 18px;
            max-width: 70%;
            word-wrap: break-word;
        }
        .message.sent {
            background-color: #e3f2fd;
            margin-left: auto;
        }
        .message.received {
            background-color: #f5f5f5;
        }
        .message-form {
            display: flex;
            margin-top: 10px;
        }
        .message-input {
            flex-grow: 1;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            margin-right: 10px;
        }
        .send-button {
            padding: 8px 16px;
            background-color: #1976d2;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .username-container {
            margin-bottom: 20px;
        }
        .connection-status {
            padding: 5px 10px;
            border-radius: 4px;
            font-size: 14px;
            margin-left: 10px;
        }
        .connection-status.connected {
            background-color: #4caf50;
            color: white;
        }
        .connection-status.disconnected {
            background-color: #f44336;
            color: white;
        }
        .sentiment {
            font-size: 12px;
            padding: 2px 6px;
            border-radius: 10px;
            margin-left: 8px;
        }
        .sentiment.positive {
            background-color: #4caf50;
            color: white;
        }
        .sentiment.negative {
            background-color: #f44336;
            color: white;
        }
        .sentiment.neutral {
            background-color: #9e9e9e;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Real-Time Chat Application</h1>
        
        <div class="demo-banner">
            <strong>DEMO MODE</strong> - This is running in demo mode without a backend. Responses are simulated.
        </div>
        
        <div class="chat-container">
            <div class="username-container">
                <input type="text" id="username" placeholder="Enter your username" />
                <button id="connect-btn">Connect</button>
                <span id="connection-status" class="connection-status disconnected">Disconnected</span>
            </div>
            
            <div id="message-list" class="message-list"></div>
            
            <div class="message-form">
                <input type="text" id="message-input" class="message-input" placeholder="Type your message..." disabled />
                <button id="send-btn" class="send-button" disabled>Send</button>
            </div>
        </div>
    </div>

    <script>
        // Demo mode implementation
        let connected = false;
        let username = '';
        const demoResponses = [
            "Hi there! This is a simulated response.",
            "I love this chat app! It's so user-friendly.",
            "AWS services are amazing for building serverless applications.",
            "The weather is terrible today, I don't like it at all.",
            "I'm neutral about this conversation.",
            "Could you explain more about AWS Lambda?",
            "This doesn't make any sense to me!",
            "I appreciate your help with this project."
        ];
        const demoUsernames = ['Alice', 'Bob', 'Charlie', 'Diana', 'System'];
        
        // Preloaded messages for demo
        const preloadedMessages = [
            { sender: 'System', text: 'Welcome to the Real-Time Chat Demo!', sentiment: 'positive' },
            { sender: 'Alice', text: 'Hi everyone! How are you doing today?', sentiment: 'positive' },
            { sender: 'Bob', text: 'I\'m doing great! This chat app is awesome.', sentiment: 'positive' },
            { sender: 'Charlie', text: 'The weather is terrible today.', sentiment: 'negative' },
            { sender: 'Diana', text: 'I\'m just here to observe.', sentiment: 'neutral' }
        ];

        // DOM elements
        const usernameInput = document.getElementById('username');
        const connectBtn = document.getElementById('connect-btn');
        const connectionStatus = document.getElementById('connection-status');
        const messageList = document.getElementById('message-list');
        const messageInput = document.getElementById('message-input');
        const sendBtn = document.getElementById('send-btn');
        
        // Load preloaded messages
        preloadedMessages.forEach(msg => {
            addMessageToUI(msg.sender, msg.text, msg.sentiment);
        });
        
        // Connect button click handler
        connectBtn.addEventListener('click', () => {
            username = usernameInput.value.trim();
            if (!username) {
                alert('Please enter a username');
                return;
            }
            
            // Simulate connection
            connected = true;
            connectionStatus.textContent = 'Connected';
            connectionStatus.className = 'connection-status connected';
            usernameInput.disabled = true;
            connectBtn.disabled = true;
            messageInput.disabled = false;
            sendBtn.disabled = false;
            
            // Add connection message
            addMessageToUI('System', `${username} has joined the chat`, 'neutral');
        });
        
        // Send button click handler
        sendBtn.addEventListener('click', sendMessage);
        messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });
        
        function sendMessage() {
            const text = messageInput.value.trim();
            if (!text) return;
            
            // Add user message to UI
            const sentiment = analyzeSentiment(text);
            addMessageToUI(username, text, sentiment, true);
            messageInput.value = '';
            
            // Simulate response after a delay
            setTimeout(() => {
                const randomResponse = demoResponses[Math.floor(Math.random() * demoResponses.length)];
                const randomUsername = demoUsernames[Math.floor(Math.random() * demoUsernames.length)];
                const responseSentiment = analyzeSentiment(randomResponse);
                addMessageToUI(randomUsername, randomResponse, responseSentiment);
            }, 1000);
        }
        
        function addMessageToUI(sender, text, sentiment, isSent = false) {
            const messageDiv = document.createElement('div');
            messageDiv.className = isSent ? 'message sent' : 'message received';
            
            const senderSpan = document.createElement('strong');
            senderSpan.textContent = sender + ': ';
            
            const sentimentSpan = document.createElement('span');
            sentimentSpan.className = `sentiment ${sentiment}`;
            sentimentSpan.textContent = sentiment.charAt(0).toUpperCase() + sentiment.slice(1);
            
            const textSpan = document.createElement('span');
            textSpan.textContent = text;
            
            messageDiv.appendChild(senderSpan);
            messageDiv.appendChild(textSpan);
            messageDiv.appendChild(sentimentSpan);
            
            messageList.appendChild(messageDiv);
            messageList.scrollTop = messageList.scrollHeight;
        }
        
        function analyzeSentiment(text) {
            const positiveWords = ['good', 'great', 'excellent', 'awesome', 'love', 'like', 'happy', 'amazing'];
            const negativeWords = ['bad', 'terrible', 'awful', 'hate', 'dislike', 'sad', 'angry', 'worst', 'doesn\'t'];
            
            let positiveScore = 0;
            let negativeScore = 0;
            
            const words = text.toLowerCase().split(/\s+/);
            
            words.forEach(word => {
                if (positiveWords.includes(word)) positiveScore++;
                if (negativeWords.includes(word)) negativeScore++;
            });
            
            if (positiveScore > negativeScore) return 'positive';
            if (negativeScore > positiveScore) return 'negative';
            return 'neutral';
        }
    </script>
</body>
</html>
"@
    Set-Content -Path "$frontendDir/index.html" -Value $indexHtml
}

# Copy frontend files if source directory exists
if ($sourceDir) {
    Copy-Item -Path "$sourceDir/*" -Destination $frontendDir -Recurse
    
    # Update the index.html to enable demo mode
    $indexHtml = Get-Content -Path "$frontendDir/index.html" -Raw
    
    # Check if the file already contains demo mode
    if (-not ($indexHtml -match "DEMO MODE")) {
        # Add a demo banner and enable demo mode
        $indexHtml = $indexHtml -replace "<body>", @"
<body>
    <div style="background-color: #ff9800; color: white; padding: 10px; text-align: center; margin-bottom: 20px;">
        <strong>DEMO MODE</strong> - This is running in demo mode without a backend. Responses are simulated.
    </div>
"@
        
        # Replace the WebSocket connection with demo mode code
        # This is a simplified approach - in a real scenario, you might want to modify the JavaScript more carefully
        if ($indexHtml -match "new WebSocket\(") {
            Write-Host "✅ Converting WebSocket code to demo mode..." -ForegroundColor Green
            
            # Add the demo mode JavaScript
            $demoScript = @"
<script>
// Demo mode implementation
let demoMode = true;
const demoResponses = [
    "Hi there! This is a simulated response.",
    "I love this chat app! It's so user-friendly.",
    "AWS services are amazing for building serverless applications.",
    "The weather is terrible today, I don't like it at all.",
    "I'm neutral about this conversation.",
    "Could you explain more about AWS Lambda?",
    "This doesn't make any sense to me!",
    "I appreciate your help with this project."
];
const demoUsernames = ['Alice', 'Bob', 'Charlie', 'Diana', 'System'];

// Override WebSocket connection with demo mode
function createDemoWebSocket() {
    return {
        send: function(message) {
            console.log('Demo mode: Sending message', message);
            const msgObj = JSON.parse(message);
            
            // Simulate response after a delay
            setTimeout(() => {
                const randomResponse = demoResponses[Math.floor(Math.random() * demoResponses.length)];
                const randomUsername = demoUsernames[Math.floor(Math.random() * demoUsernames.length)];
                
                // Analyze sentiment
                const text = randomResponse;
                const positiveWords = ['good', 'great', 'excellent', 'awesome', 'love', 'like', 'happy', 'amazing'];
                const negativeWords = ['bad', 'terrible', 'awful', 'hate', 'dislike', 'sad', 'angry', 'worst', 'doesn\'t'];
                
                let positiveScore = 0;
                let negativeScore = 0;
                
                const words = text.toLowerCase().split(/\s+/);
                
                words.forEach(word => {
                    if (positiveWords.includes(word)) positiveScore++;
                    if (negativeWords.includes(word)) negativeScore++;
                });
                
                let sentiment = 'neutral';
                if (positiveScore > negativeScore) sentiment = 'positive';
                if (negativeScore > positiveScore) sentiment = 'negative';
                
                // Create simulated response
                const response = {
                    message: randomResponse,
                    sender: randomUsername,
                    timestamp: new Date().toISOString(),
                    sentiment: sentiment
                };
                
                // Call onmessage handler with simulated response
                if (this.onmessage) {
                    this.onmessage({
                        data: JSON.stringify(response)
                    });
                }
            }, 1000);
        },
        close: function() {
            console.log('Demo mode: WebSocket closed');
        }
    };
}

// Override WebSocket constructor
window.WebSocket = function(url) {
    console.log('Demo mode: Creating WebSocket', url);
    const demoWs = createDemoWebSocket();
    
    // Simulate connection event
    setTimeout(() => {
        if (demoWs.onopen) {
            demoWs.onopen({});
        }
    }, 500);
    
    return demoWs;
};
</script>
"@
            
            # Insert the demo script before the closing body tag
            $indexHtml = $indexHtml -replace "</body>", "$demoScript</body>"
        }
        
        # Save the modified index.html
        Set-Content -Path "$frontendDir/index.html" -Value $indexHtml
    }
}

# Upload the frontend files to S3
Write-Host "`nUploading frontend files to S3 bucket..." -ForegroundColor Cyan
try {
    # Upload all files from the frontend directory to S3
    if (Test-Path "$frontendDir/index.html") {
        # Upload HTML files with correct content type
        Get-ChildItem -Path $frontendDir -Filter "*.html" | ForEach-Object {
            aws s3 cp $_.FullName "s3://$S3_BUCKET/$($_.Name)" --content-type "text/html" 2>&1 | Out-Null
            Write-Host "✅ Uploaded $($_.Name) with content-type: text/html" -ForegroundColor Green
        }
        
        # Upload CSS files with correct content type
        Get-ChildItem -Path $frontendDir -Filter "*.css" | ForEach-Object {
            aws s3 cp $_.FullName "s3://$S3_BUCKET/$($_.Name)" --content-type "text/css" 2>&1 | Out-Null
            Write-Host "✅ Uploaded $($_.Name) with content-type: text/css" -ForegroundColor Green
        }
        
        # Upload JavaScript files with correct content type
        Get-ChildItem -Path $frontendDir -Filter "*.js" | ForEach-Object {
            aws s3 cp $_.FullName "s3://$S3_BUCKET/$($_.Name)" --content-type "application/javascript" 2>&1 | Out-Null
            Write-Host "✅ Uploaded $($_.Name) with content-type: application/javascript" -ForegroundColor Green
        }
        
        # Upload other files
        Get-ChildItem -Path $frontendDir -Exclude "*.html","*.css","*.js" | ForEach-Object {
            aws s3 cp $_.FullName "s3://$S3_BUCKET/$($_.Name)" 2>&1 | Out-Null
            Write-Host "✅ Uploaded $($_.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Error: No index.html file found in the frontend directory." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error: Failed to upload frontend files." -ForegroundColor Red
    Write-Host $_
}

# Clean up the temporary directory
if (Test-Path $frontendDir) {
    Remove-Item -Path $frontendDir -Recurse -Force
}

# Get the website URL
$websiteURL = "http://$S3_BUCKET.s3-website-$REGION.amazonaws.com"
$s3URL = "https://$S3_BUCKET.s3.amazonaws.com/index.html"

Write-Host "`n=============================================================="
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "=============================================================="
Write-Host "Your Real-Time Chat Application (Demo Mode) has been deployed to:" -ForegroundColor Cyan
Write-Host "Website Endpoint: $websiteURL" -ForegroundColor Yellow
Write-Host "S3 Object URL: $s3URL" -ForegroundColor Yellow
Write-Host "`nIMPORTANT:" -ForegroundColor Cyan
Write-Host "1. The application is running in demo mode (no backend services)"
Write-Host "2. All messages and responses are simulated locally"
Write-Host "3. The sentiment analysis is performed by a basic client-side algorithm"
Write-Host "`nTo clean up resources when done, run:" -ForegroundColor Yellow
Write-Host "aws s3 rm s3://$S3_BUCKET --recursive" -ForegroundColor White
Write-Host "aws s3 rb s3://$S3_BUCKET" -ForegroundColor White
Write-Host "=============================================================="

# Save bucket name to a file for reference
$bucketInfo = @"
S3_BUCKET=$S3_BUCKET
WEBSITE_URL=$websiteURL
S3_URL=$s3URL
DEPLOYED_AT=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
Set-Content -Path "deployment_info.txt" -Value $bucketInfo
Write-Host "Deployment information saved to deployment_info.txt" -ForegroundColor Green
