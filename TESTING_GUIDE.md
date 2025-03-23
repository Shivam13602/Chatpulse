# Real-Time Chat Application - Testing Guide

This guide will help you deploy and test the Real-Time Chat Application demo in AWS Academy.

## Deployment Steps

### Step 1: Log into AWS Academy 
1. Go to vocareum.com and access your AWS course
2. Start your AWS Academy Learner Lab
3. Wait for the lab to start (status light turns green)
4. Click on 'AWS Details'
5. Click 'AWS Console' to open the AWS Management Console

### Step 2: Create an S3 Bucket
1. In the AWS Console, search for 'S3' in the search bar
2. Click on 'S3' to open the S3 dashboard
3. Click 'Create bucket'
4. For Bucket name, enter: `real-time-chat-demo-[yourname]`
5. Select a region close to you (e.g., us-east-1)
6. Under "Block Public Access settings", uncheck "Block all public access"
7. Acknowledge the warning by checking the box
8. Keep all other settings as default
9. Click 'Create bucket'

### Step 3: Enable Static Website Hosting
1. Click on your newly created bucket
2. Go to the 'Properties' tab
3. Scroll down to 'Static website hosting'
4. Click 'Edit'
5. Select 'Enable'
6. For 'Index document', enter 'index.html'
7. For 'Error document', enter 'index.html'
8. Click 'Save changes'

### Step 4: Set Bucket Permissions
1. Go to the 'Permissions' tab
2. Under 'Bucket policy', click 'Edit'
3. Copy and paste the following policy (replace `YOUR-BUCKET-NAME` with your actual bucket name):
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
        }
    ]
}
```
4. Click 'Save changes'

### Step 5: Upload the Frontend File
1. Go to the 'Objects' tab
2. Click 'Upload'
3. Click 'Add files'
4. Browse to find the file: `src/frontend/index.html`
5. Before clicking 'Upload', expand 'Additional upload options'
6. Under 'Access control', select 'Grant public-read access'
7. Under 'Properties', set 'Content Type' to 'text/html'
8. Click 'Upload'

### Step 6: Access and Test Your Website
1. Go back to the 'Properties' tab
2. Scroll down to 'Static website hosting'
3. Find and click the 'Bucket website endpoint' URL
4. The chat application should load in your browser

## Testing the Demo

1. **Connect to the Chat**:
   - Enter a username in the input field (e.g., "TestUser")
   - Click "Connect"
   - You should see the connection status change to "Connected" 
   - The demo messages should appear in the chat window

2. **Send Test Messages**:
   - Type a message in the message input field
   - Click "Send" or press Enter
   - Your message should appear in the chat window
   - After a short delay, you should see a simulated response

3. **Test Sentiment Analysis**:
   - Send a positive message like "This application is amazing and I love using it!"
   - The message should appear with a green bar on the left and a "Positive" sentiment badge
   - Send a negative message like "I hate when things don't work properly"
   - The message should appear with a red bar on the left and a "Negative" sentiment badge
   - Send a neutral message like "This is a test message"
   - The message should appear with a gray bar on the left and a "Neutral" sentiment badge

4. **Disconnect and Reconnect**:
   - Click the "Disconnect" button
   - The connection status should change to "Disconnected"
   - Click "Connect" again with the same or a different username
   - The connection status should change back to "Connected"

## Cleanup

When you're done testing:

1. Go back to the S3 console
2. Select your bucket
3. Click 'Empty'
4. Type 'permanently delete' to confirm
5. Click 'Delete objects'
6. Go back to the bucket list
7. Select your bucket
8. Click 'Delete'
9. Type your bucket name to confirm
10. Click 'Delete bucket'

This will ensure you don't incur any charges for the S3 storage. 