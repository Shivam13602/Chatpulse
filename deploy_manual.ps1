# Simple manual guide for S3 deployment 
# This script provides step-by-step instructions for manual deployment

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Manual Deployment Guide for Real-Time Chat Demo" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# 1. Create a unique bucket name
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$bucketName = "real-time-chat-demo-$timestamp"

Write-Host "`nPlease follow these steps to deploy the demo:" -ForegroundColor Cyan

Write-Host "`n1. Log into your AWS Academy Learner Lab" -ForegroundColor Yellow
Write-Host "   - Go to vocareum.com and access your AWS course"
Write-Host "   - Start your AWS Academy Learner Lab"
Write-Host "   - Wait for the lab to start (status light turns green)"

Write-Host "`n2. Click on 'AWS Details'" -ForegroundColor Yellow
Write-Host "   - Find and click the 'AWS Details' dropdown"
Write-Host "   - Click 'AWS Console' to open the AWS Management Console in a new tab"

Write-Host "`n3. Open the S3 Service" -ForegroundColor Yellow
Write-Host "   - In the AWS Console, search for 'S3' in the search bar at the top"
Write-Host "   - Click on 'S3' to open the S3 dashboard"

Write-Host "`n4. Create a new S3 bucket" -ForegroundColor Yellow
Write-Host "   - Click the 'Create bucket' button"
Write-Host "   - Bucket name: $bucketName (you can use this or choose your own unique name)"
Write-Host "   - Region: Select a region close to you (e.g., us-east-1)"
Write-Host "   - Disable 'Block all public access' (uncheck the checkbox)"
Write-Host "   - Acknowledge the warning about making the bucket public"
Write-Host "   - Keep all other settings as default"
Write-Host "   - Click 'Create bucket' at the bottom"

Write-Host "`n5. Enable static website hosting" -ForegroundColor Yellow
Write-Host "   - Click on your new bucket name in the S3 console"
Write-Host "   - Go to the 'Properties' tab"
Write-Host "   - Scroll down to 'Static website hosting'"
Write-Host "   - Click 'Edit'"
Write-Host "   - Select 'Enable'"
Write-Host "   - For 'Index document', enter 'index.html'"
Write-Host "   - For 'Error document', enter 'index.html'"
Write-Host "   - Click 'Save changes'"

Write-Host "`n6. Set bucket permissions" -ForegroundColor Yellow
Write-Host "   - Go to the 'Permissions' tab"
Write-Host "   - Under 'Bucket policy', click 'Edit'"
Write-Host "   - Copy and paste the following policy (replace BUCKET_NAME with your bucket name):"

$policyTemplate = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::BUCKET_NAME/*"
        }
    ]
}
"@

$policy = $policyTemplate -replace "BUCKET_NAME", $bucketName
Write-Host $policy -ForegroundColor Gray
Write-Host "   - Click 'Save changes'"

Write-Host "`n7. Upload the frontend file" -ForegroundColor Yellow
Write-Host "   - Go to the 'Objects' tab"
Write-Host "   - Click 'Upload'"
Write-Host "   - Click 'Add files'"
Write-Host "   - Browse to find the file: src/frontend/index.html"
Write-Host "   - Before clicking 'Upload', click on 'Additional upload options'"
Write-Host "   - Expand 'Access control'"
Write-Host "   - Select 'Grant public-read access' under 'Predefined ACLs'"
Write-Host "   - Under 'Properties', set 'Content Type' to 'text/html'"
Write-Host "   - Click 'Upload'"

Write-Host "`n8. Access your website" -ForegroundColor Yellow
Write-Host "   - Go back to 'Properties' tab"
Write-Host "   - Scroll down to 'Static website hosting'"
Write-Host "   - Find the 'Bucket website endpoint' URL"
Write-Host "   - Click the URL or copy it to your browser"
Write-Host "   - The demo website should now be visible"

Write-Host "`n9. Cleanup when done" -ForegroundColor Yellow
Write-Host "   - To delete the bucket and all its contents:"
Write-Host "   - Go to the 'Objects' tab"
Write-Host "   - Select all objects and click 'Delete'"
Write-Host "   - Confirm deletion by typing 'permanently delete'"
Write-Host "   - Go back to bucket list by clicking 'Buckets' in the breadcrumb"
Write-Host "   - Select your bucket and click 'Delete'"
Write-Host "   - Confirm deletion by typing your bucket name"

# Information about the demo
Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "About the Demo" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "`nThis demo shows what the Real-Time Chat app with sentiment analysis would look like if the"
Write-Host "full backend implementation was available. Due to AWS Academy limitations, we've created"
Write-Host "a static demo that simulates the functionality."
Write-Host "`nThe complete architecture would include:"
Write-Host "- API Gateway WebSocket API for real-time communication"
Write-Host "- Lambda functions for connection management and message processing"
Write-Host "- DynamoDB tables for storing connections and messages"
Write-Host "- S3 bucket for frontend hosting"
Write-Host "`nFull implementation details are available in the README.md and PROJECT_SUMMARY.md files."
Write-Host "===============================================`n" -ForegroundColor Green 