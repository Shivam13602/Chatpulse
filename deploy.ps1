# Simplified PowerShell Deployment Script for Real-Time Chat Application

param(
    [string]$Region = "us-west-2",
    [string]$S3BucketName = "cloud-chat-app-bucket",
    [string]$StackName = "real-time-chat-app",
    [string]$Environment = "Prod",
    [string]$AdminEmail = "admin@example.com"
)

Write-Host "Starting deployment of the Real-Time Chat Application with Sentiment Insights..." -ForegroundColor Green

# Step 1: Check if the S3 bucket exists, if not create it
Write-Host "Checking if S3 bucket '$S3BucketName' exists..." -ForegroundColor Yellow
$bucketExists = $false
try {
    $buckets = aws s3api list-buckets --query "Buckets[].Name" --output text --region $Region
    if ($buckets -contains $S3BucketName) {
        $bucketExists = $true
        Write-Host "S3 bucket '$S3BucketName' already exists." -ForegroundColor Green
    } 
} catch {
    Write-Host "Error checking for S3 bucket: $_" -ForegroundColor Red
}

if (-not $bucketExists) {
    Write-Host "Creating S3 bucket '$S3BucketName'..." -ForegroundColor Yellow
    try {
        aws s3api create-bucket --bucket $S3BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region
        $policyContent = Get-Content -Raw -Path "bucket_policy.json"
        $policyContent = $policyContent.Trim()
        aws s3api put-bucket-policy --bucket $S3BucketName --policy $policyContent
        aws s3api put-bucket-website --bucket $S3BucketName --website-configuration "IndexDocument={Suffix=index.html},ErrorDocument={Key=error.html}"
        Write-Host "S3 bucket created and configured successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error creating S3 bucket: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Package and upload Lambda functions
Write-Host "Packaging Lambda functions..." -ForegroundColor Yellow

# Create a temporary directory for packaging
$tempDir = New-Item -ItemType Directory -Path ".\temp" -Force

# Package connection_manager.py Lambda function
Write-Host "Packaging connection_manager.py Lambda function..." -ForegroundColor Yellow
Copy-Item ".\lambda\functions\connection_manager.py" -Destination $tempDir
Compress-Archive -Path "$tempDir\connection_manager.py" -DestinationPath "$tempDir\connection_manager.zip" -Force
aws s3 cp "$tempDir\connection_manager.zip" "s3://$S3BucketName/lambda/connection_manager.zip" --region $Region

# Package message_processor.js Lambda function
Write-Host "Packaging message_processor.js Lambda function..." -ForegroundColor Yellow
Copy-Item ".\lambda\functions\message_processor.js" -Destination $tempDir
Copy-Item ".\lambda\functions\package.json" -Destination $tempDir
Set-Location $tempDir
npm install --production
Compress-Archive -Path ".\node_modules", ".\message_processor.js", ".\package.json" -DestinationPath "message_processor.zip" -Force
aws s3 cp "message_processor.zip" "s3://$S3BucketName/lambda/message_processor.zip" --region $Region

# Package default_handler.js Lambda function
Write-Host "Packaging default_handler.js Lambda function..." -ForegroundColor Yellow
Remove-Item -Recurse -Force .\node_modules -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\*.js -ErrorAction SilentlyContinue
Copy-Item "..\lambda\functions\default_handler.js" -Destination $tempDir
Copy-Item "..\lambda\functions\package.json" -Destination $tempDir
npm install --production
Compress-Archive -Path ".\node_modules", ".\default_handler.js", ".\package.json" -DestinationPath "default_handler.zip" -Force
aws s3 cp "default_handler.zip" "s3://$S3BucketName/lambda/default_handler.zip" --region $Region

# Package message_broadcast.js Lambda function
Write-Host "Packaging message_broadcast.js Lambda function..." -ForegroundColor Yellow
Remove-Item -Recurse -Force .\node_modules -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\*.js -ErrorAction SilentlyContinue
Copy-Item "..\lambda\functions\message_broadcast.js" -Destination $tempDir
Copy-Item "..\lambda\functions\package.json" -Destination $tempDir
npm install --production
Compress-Archive -Path ".\node_modules", ".\message_broadcast.js", ".\package.json" -DestinationPath "message_broadcast.zip" -Force
aws s3 cp "message_broadcast.zip" "s3://$S3BucketName/lambda/message_broadcast.zip" --region $Region

# Return to original directory
Set-Location ..
Write-Host "All Lambda functions packaged and uploaded." -ForegroundColor Green

# Step 3: Upload CloudFormation templates
Write-Host "Uploading CloudFormation templates..." -ForegroundColor Yellow
aws s3 cp ".\infrastructure\cloudformation\main-template.yml" "s3://$S3BucketName/cloudformation/main-template.yml" --region $Region
aws s3 cp ".\infrastructure\cloudformation\ec2-training.yml" "s3://$S3BucketName/cloudformation/ec2-training.yml" --region $Region
aws s3 cp ".\infrastructure\cloudformation\eventbridge.yml" "s3://$S3BucketName/cloudformation/eventbridge.yml" --region $Region
aws s3 cp ".\infrastructure\cloudformation\cloudwatch.yml" "s3://$S3BucketName/cloudformation/cloudwatch.yml" --region $Region
aws s3 cp ".\infrastructure\cloudformation\s3-bucket.yml" "s3://$S3BucketName/cloudformation/s3-bucket.yml" --region $Region
Write-Host "CloudFormation templates uploaded." -ForegroundColor Green

# Step 4: Upload frontend files
Write-Host "Uploading frontend files..." -ForegroundColor Yellow
aws s3 cp ".\src\index.html" "s3://$S3BucketName/index.html" --region $Region
Write-Host "Frontend files uploaded." -ForegroundColor Green

# Step 5: Create/update the CloudFormation stack
Write-Host "Deploying CloudFormation stack '$StackName'..." -ForegroundColor Yellow
try {
    aws cloudformation deploy `
        --template-url "https://$S3BucketName.s3.$Region.amazonaws.com/cloudformation/main-template.yml" `
        --stack-name $StackName `
        --parameter-overrides EnvironmentName=$Environment S3BucketName=$S3BucketName AdminEmail=$AdminEmail `
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
        --region $Region

    Write-Host "CloudFormation stack deployed successfully." -ForegroundColor Green
} catch {
    Write-Host "Error deploying CloudFormation stack: $_" -ForegroundColor Red
    exit 1
}

# Step 6: Get outputs from the CloudFormation stack
Write-Host "Retrieving CloudFormation stack outputs..." -ForegroundColor Yellow
try {
    $outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" --output json --region $Region | ConvertFrom-Json
    
    $websocketUrl = ($outputs | Where-Object { $_.OutputKey -eq "WebSocketURL" }).OutputValue
    $frontendUrl = ($outputs | Where-Object { $_.OutputKey -eq "FrontendURL" }).OutputValue
    $dashboardUrl = ($outputs | Where-Object { $_.OutputKey -eq "DashboardURL" }).OutputValue
    $modelTrainingInstanceId = ($outputs | Where-Object { $_.OutputKey -eq "ModelTrainingInstanceId" }).OutputValue
    
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host "WebSocket URL: $websocketUrl" -ForegroundColor Cyan
    Write-Host "Frontend URL: $frontendUrl" -ForegroundColor Cyan
    Write-Host "CloudWatch Dashboard: $dashboardUrl" -ForegroundColor Cyan
    Write-Host "EC2 Training Instance ID: $modelTrainingInstanceId" -ForegroundColor Cyan
} catch {
    Write-Host "Error retrieving CloudFormation stack outputs: $_" -ForegroundColor Red
}

# Clean up temporary directory
Remove-Item -Recurse -Force $tempDir

Write-Host "Deployment completed successfully." -ForegroundColor Green 