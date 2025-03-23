# PowerShell deployment script for Real-Time Chat Application in AWS Academy
# This script packages and deploys the application resources to AWS using the LabRole

Write-Host "==============================================="
Write-Host "Real-Time Chat Application Deployment for AWS Academy"
Write-Host "==============================================="

# Prompt for AWS credentials
Write-Host "Enter your AWS Academy credentials:" -ForegroundColor Yellow
Write-Host "AWS Access Key ID: " -NoNewline
$accessKeyId = Read-Host
Write-Host "AWS Secret Access Key: " -NoNewline
$secretAccessKey = Read-Host
Write-Host "AWS Session Token: " -NoNewline
$sessionToken = Read-Host

# Set AWS credentials as environment variables
$env:AWS_ACCESS_KEY_ID = $accessKeyId
$env:AWS_SECRET_ACCESS_KEY = $secretAccessKey
$env:AWS_SESSION_TOKEN = $sessionToken
$env:AWS_DEFAULT_REGION = "us-east-1"

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
    
    # Check if user is using LabRole
    if ($identity.Arn -match "LabRole") {
        Write-Host "✅ Using LabRole which is good for AWS Academy deployments." -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Error: Failed to authenticate with AWS. Please check your credentials and try again." -ForegroundColor Red
    Write-Host $_
    exit 1
}

# Variables
$timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
$STACK_NAME = "chat-app-$timestamp"
$S3_BUCKET = "real-time-chat-deployment-$timestamp"
$REGION = "us-east-1"
$TEMPLATE_FILE = "infrastructure/cloudformation/main-template-labmode.yml"

# Check for AWS CLI installation
Write-Host "`nChecking AWS CLI installation..." -ForegroundColor Cyan
try {
    $awsCliVersion = aws --version 2>&1
    Write-Host "Using $awsCliVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: AWS CLI not found or not properly installed." -ForegroundColor Red
    Write-Host "Please install AWS CLI and try again: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Verify LabRole exists
Write-Host "`nVerifying LabRole exists..." -ForegroundColor Cyan
try {
    $roleCheck = aws iam get-role --role-name LabRole 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($roleCheck -match "not authorized") {
            Write-Host "⚠️ Warning: Unable to verify LabRole due to permission restrictions." -ForegroundColor Yellow
            Write-Host "This is common in AWS Academy environments. We'll proceed assuming LabRole exists." -ForegroundColor Yellow
        } else {
            Write-Host "⚠️ Warning: LabRole might not exist: $roleCheck" -ForegroundColor Yellow
            Write-Host "We'll continue anyway, but deployment might fail later." -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ LabRole exists and is accessible." -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Warning: Could not verify LabRole: $_" -ForegroundColor Yellow
    Write-Host "This is common in AWS Academy. We'll proceed assuming LabRole exists." -ForegroundColor Yellow
}

# Create deployment bucket
Write-Host "`nCreating S3 bucket for deployment artifacts: $S3_BUCKET" -ForegroundColor Cyan
try {
    $createBucket = aws s3 mb "s3://$S3_BUCKET" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Failed to create S3 bucket. Reason: $createBucket" -ForegroundColor Red
        Write-Host "Falling back to simplified deployment method..." -ForegroundColor Yellow
        
        # Call the simplified deployment script
        Write-Host "`nLaunching simplified deployment (frontend only)..." -ForegroundColor Cyan
        & ./deploy_simple.ps1
        exit $LASTEXITCODE
    }
    Write-Host "✅ S3 bucket created successfully." -ForegroundColor Green
    
    # Make bucket public for website hosting
    Write-Host "`nConfiguring bucket for public website hosting..." -ForegroundColor Cyan
    aws s3api put-public-access-block --bucket $S3_BUCKET --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" 2>&1
    
    # Enable website hosting
    aws s3 website "s3://$S3_BUCKET" --index-document index.html --error-document index.html 2>&1
    
    # Set bucket policy
    $bucketPolicy = @"
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
    $policyFile = "temp_bucket_policy.json"
    Set-Content -Path $policyFile -Value $bucketPolicy
    $policyResult = aws s3api put-bucket-policy --bucket $S3_BUCKET --policy file://$policyFile 2>&1
    Remove-Item -Path $policyFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Warning: Could not set bucket policy: $policyResult" -ForegroundColor Yellow
        Write-Host "Website hosting may not work properly, but we'll continue." -ForegroundColor Yellow
    } else {
        Write-Host "✅ Bucket configured for website hosting." -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Error: Failed to create or configure S3 bucket: $_" -ForegroundColor Red
    Write-Host "Falling back to simplified deployment method..." -ForegroundColor Yellow
    
    # Call the simplified deployment script
    Write-Host "`nLaunching simplified deployment (frontend only)..." -ForegroundColor Cyan
    & ./deploy_simple.ps1
    exit $LASTEXITCODE
}

# Package Lambda functions
Write-Host "`nPackaging Lambda functions..." -ForegroundColor Cyan
try {
    # Check if Lambda functions exist
    if (-not (Test-Path -Path "lambda/functions/connection_manager.py") -or 
        -not (Test-Path -Path "lambda/functions/message_processor.js") -or 
        -not (Test-Path -Path "lambda/functions/default_handler.js")) {
        
        Write-Host "❌ Error: Lambda function source files not found." -ForegroundColor Red
        Write-Host "Please ensure the project structure is correct and try again." -ForegroundColor Yellow
        exit 1
    }
    
    # Create lambda directory if it doesn't exist
    if (-not (Test-Path -Path "lambda/packages")) {
        New-Item -Path "lambda/packages" -ItemType Directory | Out-Null
    }
    
    # Package Python Lambda (connection_manager)
    Write-Host "Packaging connection_manager.py..." -ForegroundColor Yellow
    Copy-Item -Path "lambda/functions/connection_manager.py" -Destination "lambda/packages/connection_manager.py"
    Compress-Archive -Path "lambda/packages/connection_manager.py" -DestinationPath "lambda/packages/connection_manager.zip" -Force
    
    # Package Node.js Lambda (message_processor)
    Write-Host "Packaging message_processor.js..." -ForegroundColor Yellow
    Copy-Item -Path "lambda/functions/message_processor.js" -Destination "lambda/packages/message_processor.js"
    Compress-Archive -Path "lambda/packages/message_processor.js" -DestinationPath "lambda/packages/message_processor.zip" -Force
    
    # Package Node.js Lambda (default_handler)
    Write-Host "Packaging default_handler.js..." -ForegroundColor Yellow
    Copy-Item -Path "lambda/functions/default_handler.js" -Destination "lambda/packages/default_handler.js"
    Compress-Archive -Path "lambda/packages/default_handler.js" -DestinationPath "lambda/packages/default_handler.zip" -Force
    
    # Upload packages to S3
    Write-Host "Uploading Lambda packages to S3..." -ForegroundColor Yellow
    aws s3 cp "lambda/packages/connection_manager.zip" "s3://$S3_BUCKET/lambda/connection_manager.zip" 2>&1
    aws s3 cp "lambda/packages/message_processor.zip" "s3://$S3_BUCKET/lambda/message_processor.zip" 2>&1
    aws s3 cp "lambda/packages/default_handler.zip" "s3://$S3_BUCKET/lambda/default_handler.zip" 2>&1
    
    Write-Host "✅ Lambda functions packaged and uploaded successfully." -ForegroundColor Green
} catch {
    Write-Host "❌ Error packaging Lambda functions: $_" -ForegroundColor Red
    Write-Host "Falling back to frontend-only deployment..." -ForegroundColor Yellow
    
    # Continue with frontend-only deployment
}

# Package and deploy CloudFormation template
Write-Host "`nPackaging CloudFormation template..." -ForegroundColor Cyan
try {
    aws cloudformation package `
        --template-file $TEMPLATE_FILE `
        --s3-bucket $S3_BUCKET `
        --s3-prefix cfn-templates `
        --output-template-file packaged-template.yml 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Warning: Could not package CloudFormation template. Proceeding with frontend-only deployment." -ForegroundColor Yellow
    } else {
        Write-Host "✅ CloudFormation template packaged successfully." -ForegroundColor Green
        
        # Deploy CloudFormation stack
        Write-Host "`nDeploying CloudFormation stack: $STACK_NAME" -ForegroundColor Cyan
        $stackOutput = aws cloudformation deploy `
            --template-file packaged-template.yml `
            --stack-name $STACK_NAME `
            --capabilities CAPABILITY_NAMED_IAM `
            --parameter-overrides `
                EnvironmentName=Prod `
                S3BucketName=$S3_BUCKET 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            if ($stackOutput -match "not authorized") {
                Write-Host "❌ Error: Permission denied when deploying CloudFormation stack." -ForegroundColor Red
                Write-Host "This is a common limitation in AWS Academy environments." -ForegroundColor Yellow
                Write-Host "Error details: $stackOutput" -ForegroundColor Yellow
                Write-Host "Proceeding with frontend-only deployment..." -ForegroundColor Yellow
            } else {
                Write-Host "❌ Error deploying CloudFormation stack: $stackOutput" -ForegroundColor Red
                Write-Host "Proceeding with frontend-only deployment..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "✅ CloudFormation stack deployed successfully." -ForegroundColor Green
            
            # Get stack outputs
            Write-Host "`nGetting stack outputs..." -ForegroundColor Cyan
            $outputs = aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs" | ConvertFrom-Json
            
            # Update frontend with WebSocket URL
            $wsURL = ($outputs | Where-Object { $_.OutputKey -eq "WebSocketURL" }).OutputValue
            if ($wsURL) {
                Write-Host "`nUpdating frontend with WebSocket URL: $wsURL" -ForegroundColor Yellow
                
                # Read the frontend HTML file
                $htmlContent = Get-Content -Path "src/frontend/index.html" -Raw
                
                # Replace the placeholder with the actual WebSocket URL
                $updatedContent = $htmlContent -replace "WEBSOCKET_ENDPOINT_PLACEHOLDER", $wsURL
                
                # Create a temporary file with the updated content
                $tempFile = "temp_index.html"
                Set-Content -Path $tempFile -Value $updatedContent
                
                # Upload the updated frontend to S3
                aws s3 cp $tempFile "s3://$S3_BUCKET/index.html" --content-type "text/html" --acl public-read 2>&1
                
                # Clean up temporary file
                Remove-Item -Path $tempFile
                
                Write-Host "✅ Frontend updated successfully with WebSocket endpoint." -ForegroundColor Green
            } else {
                Write-Host "⚠️ WebSocket URL not found in stack outputs. Using demo mode." -ForegroundColor Yellow
                # Upload the demo frontend
                $demoFrontend = Get-Content -Path "src/frontend/index.html" -Raw
                Set-Content -Path "temp_index.html" -Value $demoFrontend
                aws s3 cp "temp_index.html" "s3://$S3_BUCKET/index.html" --content-type "text/html" --acl public-read 2>&1
                Remove-Item -Path "temp_index.html"
            }
            
            # Display outputs
            Write-Host "`n=========== Deployment Complete ===========" -ForegroundColor Green
            Write-Host "Application Endpoints:" -ForegroundColor Yellow
            foreach ($output in $outputs) {
                Write-Host "$($output.OutputKey): $($output.OutputValue)" -ForegroundColor White
            }
        }
    }
} catch {
    Write-Host "❌ Error with CloudFormation operations: $_" -ForegroundColor Red
    Write-Host "Proceeding with frontend-only deployment..." -ForegroundColor Yellow
}

# If we reach here, either the CloudFormation deployment worked or we're falling back to frontend-only
if (-not $outputs -or -not ($outputs | Where-Object { $_.OutputKey -eq "WebSocketURL" })) {
    Write-Host "`nDeploying frontend in demo mode (without backend)..." -ForegroundColor Cyan
    
    try {
        # Upload the demo frontend
        $htmlContent = Get-Content -Path "src/frontend/index.html" -Raw
        
        # Ensure demo mode is enabled
        if (-not ($htmlContent -match "demoMode = true")) {
            $htmlContent = $htmlContent -replace "const demoMode = false;", "const demoMode = true;"
        }
        
        # Add demo notice if not already present
        if (-not ($htmlContent -match "DEMO MODE")) {
            $demoNotice = @"
<div class="demo-notice">
    <strong>DEMO MODE:</strong> This is running in demo mode without a backend. 
    Messages are simulated and not sent to a real server.
</div>
"@
            $htmlContent = $htmlContent -replace "<body>", "<body>`n    $demoNotice"
        }
        
        # Create a temporary file with the demo content
        $tempFile = "temp_index.html"
        Set-Content -Path $tempFile -Value $htmlContent
        
        # Upload the frontend to S3
        aws s3 cp $tempFile "s3://$S3_BUCKET/index.html" --content-type "text/html" --acl public-read 2>&1
        
        # Clean up temporary file
        Remove-Item -Path $tempFile
        
        Write-Host "✅ Frontend deployed successfully in demo mode." -ForegroundColor Green
    } catch {
        Write-Host "❌ Error deploying frontend: $_" -ForegroundColor Red
        exit 1
    }
}

# Display S3 website URL
Write-Host "`n=========== Deployment Complete ===========" -ForegroundColor Green
$websiteUrl = "http://$S3_BUCKET.s3-website-$REGION.amazonaws.com"
Write-Host "Website URL: $websiteUrl" -ForegroundColor Yellow

# Provide cleanup instructions
Write-Host "`nTo clean up all resources, run:" -ForegroundColor Yellow
Write-Host "aws cloudformation delete-stack --stack-name $STACK_NAME" -ForegroundColor White
Write-Host "aws s3 rb s3://$S3_BUCKET --force" -ForegroundColor White

Write-Host "`nTo test if the website is accessible, run:" -ForegroundColor Yellow
Write-Host "./test_page.ps1" -ForegroundColor White
Write-Host "When prompted, enter: $websiteUrl" -ForegroundColor White 