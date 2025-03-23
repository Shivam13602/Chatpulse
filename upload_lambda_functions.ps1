# PowerShell script to upload packaged Lambda functions to an S3 bucket

param(
    [Parameter(Mandatory=$true, HelpMessage="S3 bucket name for Lambda function upload")]
    [string]$S3BucketName,
    
    [Parameter(Mandatory=$false, HelpMessage="AWS region (e.g., us-east-1)")]
    [string]$Region = "us-east-1"
)

Write-Host "=========================================="
Write-Host "Lambda Functions Upload Script"
Write-Host "=========================================="
Write-Host "S3 Bucket: $S3BucketName"
Write-Host "AWS Region: $Region"
Write-Host "==========================================" 

# Check if deployment directory exists
if (-not (Test-Path "deployment")) {
    Write-Host "Error: Deployment directory not found." -ForegroundColor Red
    exit 1
}

# Check if Lambda functions are packaged
$lambdaFunctions = @(
    "connection_manager",
    "message_processor",
    "default_handler"
)

foreach ($function in $lambdaFunctions) {
    $zipFile = "deployment/$function.zip"
    if (-not (Test-Path $zipFile)) {
        Write-Host "Error: Lambda function package $zipFile not found." -ForegroundColor Red
        Write-Host "Make sure to run package_lambda.ps1 first." -ForegroundColor Yellow
        exit 1
    }
}

# Check if the bucket exists
try {
    Write-Host "Checking if S3 bucket exists: $S3BucketName"
    $bucketExists = aws s3api head-bucket --bucket $S3BucketName 2>$null
    Write-Host "S3 bucket exists: $S3BucketName"
} catch {
    Write-Host "Error: S3 bucket '$S3BucketName' not found or you don't have access to it." -ForegroundColor Red
    
    $createBucket = Read-Host "Would you like to create the bucket? (y/n)"
    if ($createBucket -eq "y") {
        try {
            Write-Host "Creating S3 bucket: $S3BucketName in region $Region"
            aws s3api create-bucket --bucket $S3BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region
            
            if (-not $?) {
                # Some regions like us-east-1 don't use LocationConstraint
                aws s3api create-bucket --bucket $S3BucketName --region $Region
                
                if (-not $?) {
                    Write-Host "Error: Failed to create S3 bucket. Please choose a different bucket name." -ForegroundColor Red
                    exit 1
                }
            }
        } catch {
            Write-Host "Error creating S3 bucket: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Exiting without uploading Lambda functions." -ForegroundColor Yellow
        exit 0
    }
}

# Upload Lambda functions to S3
Write-Host "`nUploading Lambda function packages to S3..."

foreach ($function in $lambdaFunctions) {
    $zipFile = "deployment/$function.zip"
    $s3Key = "lambda/$function.zip"
    
    Write-Host "Uploading $zipFile to s3://$S3BucketName/$s3Key"
    aws s3 cp $zipFile "s3://$S3BucketName/$s3Key"
    
    if (-not $?) {
        Write-Host "Error: Failed to upload $zipFile to S3." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=========================================="
Write-Host "Upload Successful!"
Write-Host "=========================================="
Write-Host "Lambda functions have been uploaded to:"
Write-Host "s3://$S3BucketName/lambda/"
Write-Host ""
Write-Host "You can now proceed with deploying the CloudFormation stack using:"
Write-Host "./deploy_cloudformation.ps1 -Region $Region -S3BucketName $S3BucketName"
Write-Host "==========================================" 