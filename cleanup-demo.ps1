# Real-Time Chat Application with Sentiment Analysis - Demonstration Cleanup Script
# This script removes all resources created by the demonstration deployment

# Set variables
$stackName = "RealTimeChatDemo"
$region = "us-west-2"  # Use the same region as your deployment

Write-Host "================================================================"
Write-Host "  Real-Time Chat Application with Sentiment Analysis - IaC Demo"
Write-Host "  Cleanup Script"
Write-Host "================================================================"
Write-Host ""
Write-Host "This script will delete the CloudFormation stack '$stackName' and all its resources:"
Write-Host "  - S3 Bucket for deployment artifacts (Storage category)"
Write-Host "  - DynamoDB Tables (Database category)"
Write-Host "  - Lambda Functions and EC2 Instance (Compute category)"
Write-Host "  - WebSocket API Gateway (Networking category)"
Write-Host "  - SNS Topic (Application Integration category)"
Write-Host "  - CloudWatch Dashboard and Alarms (Management & Governance category)"
Write-Host ""
Write-Host "WARNING: This action cannot be undone. All resources and data will be permanently deleted."
Write-Host ""

$confirmation = Read-Host "Do you want to proceed with the cleanup? (yes/no)"
if ($confirmation.ToLower() -ne "yes") {
    Write-Host "Cleanup cancelled."
    exit
}

# We need to empty the S3 bucket before CloudFormation can delete it
Write-Host "Getting S3 bucket name from stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $stackName --region $region --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
$bucketName = ($outputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue

if ($bucketName) {
    Write-Host "Emptying S3 bucket $bucketName before deletion..."
    aws s3 rm s3://$bucketName --recursive --region $region
    Write-Host "S3 bucket emptied."
}

# Create a timestamp for this cleanup operation
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "cleanup-log-$timestamp.txt"

Write-Host ""
Write-Host "Deleting CloudFormation stack: $stackName"
Write-Host "Region: $region"
Write-Host "Cleanup timestamp: $timestamp"
Write-Host "Log file: $logFile"
Write-Host ""

# Start the deletion and log the output
Write-Host "Starting stack deletion... (this may take a few minutes)"
$cleanupOutput = aws cloudformation delete-stack --stack-name $stackName --region $region
$cleanupOutput | Out-File -FilePath $logFile

# Wait for the stack to be deleted
Write-Host "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $stackName --region $region

# Verify deletion
$stackExists = $true
try {
    $stack = aws cloudformation describe-stacks --stack-name $stackName --region $region 2>&1
    if ($LASTEXITCODE -ne 0) {
        $stackExists = $false
    }
} catch {
    $stackExists = $false
}

if ($stackExists) {
    Write-Host ""
    Write-Host "WARNING: Stack deletion might still be in progress or encountered an error."
    Write-Host "Please check the AWS CloudFormation console for more details."
} else {
    Write-Host ""
    Write-Host "Cleanup completed successfully!"
    Write-Host "All demonstration resources have been removed."
    Write-Host "This includes all required service categories for the demo:"
    Write-Host "  - Compute services (Lambda, EC2)"
    Write-Host "  - Storage service (S3)"
    Write-Host "  - Networking service (API Gateway)"
    Write-Host "  - Database service (DynamoDB)"
    Write-Host "  - Application Integration service (SNS)"
    Write-Host "  - Management & Governance service (CloudWatch)"
}

Write-Host ""
Write-Host "Cleanup operation completed at $(Get-Date)"
Write-Host "Cleanup log saved to: $logFile" 