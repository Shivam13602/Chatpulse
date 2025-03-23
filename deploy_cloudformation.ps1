# PowerShell script to deploy the Real-Time Chat Application using CloudFormation

# Parameters
param(
    [Parameter(Mandatory=$true, HelpMessage="AWS region to deploy to (e.g., us-east-1)")]
    [string]$Region,
    
    [Parameter(Mandatory=$true, HelpMessage="Unique S3 bucket name for deployment artifacts")]
    [string]$S3BucketName,
    
    [Parameter(Mandatory=$false, HelpMessage="Environment name for resource naming (Dev, Test, Prod)")]
    [string]$EnvironmentName = "Dev",
    
    [Parameter(Mandatory=$false, HelpMessage="Stack name for CloudFormation")]
    [string]$StackName = "RealTimeChat",
    
    [Parameter(Mandatory=$false, HelpMessage="Set to true to use the AWS Academy lab mode template")]
    [bool]$UseLabMode = $true
)

Write-Host "=========================================="
Write-Host "Real-Time Chat Application Deployment"
Write-Host "=========================================="
Write-Host "- Region: $Region"
Write-Host "- S3 Bucket: $S3BucketName"
Write-Host "- Environment: $EnvironmentName"
Write-Host "- Stack Name: $StackName"
Write-Host "- Using Lab Mode: $UseLabMode"
Write-Host "=========================================="

# Step 1: Package Lambda functions
Write-Host "`nStep 1: Packaging Lambda functions..."
if (-not (Test-Path "./package_lambda.ps1")) {
    Write-Host "Error: Lambda packaging script not found." -ForegroundColor Red
    exit 1
}

./package_lambda.ps1
if (-not $?) {
    Write-Host "Error: Lambda packaging failed." -ForegroundColor Red
    exit 1
}

# Step 2: Create or verify S3 bucket
Write-Host "`nStep 2: Creating S3 bucket for deployment artifacts..."
$bucketExists = $false
try {
    $bucketList = aws s3api list-buckets --query "Buckets[].Name" --output text
    $bucketExists = $bucketList -split "\s+" | Where-Object { $_ -eq $S3BucketName }
} catch {
    Write-Host "Error checking S3 buckets: $_" -ForegroundColor Yellow
}

if (-not $bucketExists) {
    Write-Host "Creating S3 bucket: $S3BucketName"
    try {
        aws s3api create-bucket --bucket $S3BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region
        if (-not $?) {
            # Some regions like us-east-1 don't use LocationConstraint
            aws s3api create-bucket --bucket $S3BucketName --region $Region
        }
    } catch {
        Write-Host "Error creating S3 bucket: $_" -ForegroundColor Red
        Write-Host "You may need to choose a more unique bucket name as S3 bucket names are globally unique."
        exit 1
    }
} else {
    Write-Host "S3 bucket '$S3BucketName' already exists."
}

# Step 3: Upload Lambda functions to S3
Write-Host "`nStep 3: Uploading Lambda function packages to S3..."
$lambdaFunctions = @(
    "connection_manager",
    "message_processor",
    "default_handler"
)

foreach ($function in $lambdaFunctions) {
    $zipFile = "deployment/$function.zip"
    $s3Key = "lambda/$function.zip"
    
    if (Test-Path $zipFile) {
        Write-Host "Uploading $zipFile to s3://$S3BucketName/$s3Key"
        aws s3 cp $zipFile "s3://$S3BucketName/$s3Key"
        if (-not $?) {
            Write-Host "Error uploading Lambda function package to S3." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: Lambda function package $zipFile not found." -ForegroundColor Red
        exit 1
    }
}

# Step 4: Deploy CloudFormation stack
Write-Host "`nStep 4: Deploying CloudFormation stack..."

# Select the appropriate template
$templateFile = if ($UseLabMode) {
    "infrastructure/cloudformation/main-template-labmode.yml"
} else {
    "infrastructure/cloudformation/main-template.yml"
}

# Validate template
Write-Host "Validating CloudFormation template: $templateFile"
aws cloudformation validate-template --template-body file://$templateFile

if (-not $?) {
    Write-Host "Error: CloudFormation template validation failed." -ForegroundColor Red
    exit 1
}

# Deploy the stack
Write-Host "Deploying CloudFormation stack: $StackName"
aws cloudformation deploy `
    --template-file $templateFile `
    --stack-name $StackName `
    --parameter-overrides `
        EnvironmentName=$EnvironmentName `
        S3BucketName=$S3BucketName `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region

if (-not $?) {
    Write-Host "Error: CloudFormation stack deployment failed." -ForegroundColor Red
    Write-Host "Check the AWS CloudFormation console for detailed error messages."
    exit 1
}

# Step 5: Get stack outputs
Write-Host "`nStep 5: Getting CloudFormation stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs" --output json | ConvertFrom-Json

if ($outputs) {
    Write-Host "`n=========================================="
    Write-Host "Deployment Successful!"
    Write-Host "=========================================="
    Write-Host "Application Endpoints:"
    
    foreach ($output in $outputs) {
        Write-Host "- $($output.OutputKey): $($output.OutputValue)"
    }
    
    Write-Host "`nTo test the application, follow these steps:"
    Write-Host "1. Upload the frontend files to the S3 bucket:"
    Write-Host "   aws s3 cp src/frontend/ s3://$S3BucketName/frontend/ --recursive"
    Write-Host "2. Access the frontend using the FrontendURL shown above"
    Write-Host "3. Connect to the WebSocket API using the WebSocketURL"
    Write-Host "4. Follow the testing guide for additional functionality tests"
    Write-Host "==========================================" 
} else {
    Write-Host "Warning: Could not retrieve stack outputs." -ForegroundColor Yellow
}

Write-Host "`nDeployment process completed!" 