# PowerShell script to upload frontend files to S3 bucket

param(
    [Parameter(Mandatory=$true, HelpMessage="S3 bucket name for frontend hosting")]
    [string]$S3BucketName,
    
    [Parameter(Mandatory=$false, HelpMessage="AWS region (e.g., us-east-1)")]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false, HelpMessage="Path to frontend files")]
    [string]$FrontendPath = "src/frontend"
)

Write-Host "=========================================="
Write-Host "Frontend Upload Script"
Write-Host "=========================================="
Write-Host "S3 Bucket: $S3BucketName"
Write-Host "Frontend Path: $FrontendPath"
Write-Host "==========================================" 

# Check if frontend directory exists
if (-not (Test-Path $FrontendPath)) {
    Write-Host "Error: Frontend directory not found at path: $FrontendPath" -ForegroundColor Red
    exit 1
}

# Check if the bucket exists
try {
    $bucketExists = aws s3api head-bucket --bucket $S3BucketName 2>$null
    Write-Host "S3 bucket exists: $S3BucketName"
} catch {
    Write-Host "Error: S3 bucket '$S3BucketName' not found or you don't have access to it." -ForegroundColor Red
    Write-Host "Please run the deploy_cloudformation.ps1 script first to create the bucket." -ForegroundColor Yellow
    exit 1
}

# Upload the frontend files to S3
Write-Host "`nUploading frontend files to S3..."
Write-Host "Command: aws s3 cp $FrontendPath s3://$S3BucketName/frontend/ --recursive --acl public-read"

aws s3 cp $FrontendPath "s3://$S3BucketName/frontend/" --recursive --acl public-read

if (-not $?) {
    Write-Host "Error: Failed to upload frontend files to S3." -ForegroundColor Red
    exit 1
}

# Set content type for index.html (and any other HTML files)
Write-Host "`nSetting proper content types..."

aws s3 cp "s3://$S3BucketName/frontend/index.html" "s3://$S3BucketName/frontend/index.html" --content-type "text/html" --metadata-directive REPLACE --acl public-read

if (-not $?) {
    Write-Host "Warning: Failed to set content type for index.html. This may affect how the browser interprets the file." -ForegroundColor Yellow
}

# Get website URL
$websiteUrl = "http://$S3BucketName.s3-website-$Region.amazonaws.com/frontend/index.html"

Write-Host "`n=========================================="
Write-Host "Upload Complete!"
Write-Host "=========================================="
Write-Host "Your website should be available at:"
Write-Host $websiteUrl
Write-Host "`nNote: It may take a few minutes for the changes to propagate."
Write-Host "If the website doesn't display correctly, make sure static website hosting is enabled for your bucket."
Write-Host "==========================================" 

# Open the website in the default browser
Write-Host "`nAttempting to open the website in your default browser..."
try {
    Start-Process $websiteUrl
} catch {
    Write-Host "Could not open the browser automatically. Please visit the URL manually." -ForegroundColor Yellow
} 