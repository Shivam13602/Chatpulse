# Smart deployment script for Real-Time Chat Application
# This script detects the environment and selects the appropriate deployment method

Write-Host "=============================================================="
Write-Host "Smart Deployment for Real-Time Chat Application" -ForegroundColor Cyan
Write-Host "=============================================================="
Write-Host "This script will detect your environment and choose the most appropriate"
Write-Host "deployment method for your AWS Academy account."
Write-Host "=============================================================="

# Prompt for AWS credentials
Write-Host "`nPlease enter your AWS Academy credentials:" -ForegroundColor Yellow
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
    $usingLabRole = $identity.Arn -match "LabRole"
    if ($usingLabRole) {
        Write-Host "✅ Detected LabRole which is good for AWS Academy deployments." -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Error: Failed to authenticate with AWS. Please check your credentials and try again." -ForegroundColor Red
    Write-Host $_
    exit 1
}

# Check for AWS CLI
$hasAwsCli = $true
try {
    $awsCliVersion = aws --version 2>&1
    Write-Host "✅ AWS CLI detected: $awsCliVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️ AWS CLI not found or not properly installed." -ForegroundColor Yellow
    $hasAwsCli = $false
}

# Check if LabRole exists and has permissions
$labRoleExists = $false
$hasIamPermissions = $false
$hasS3Permissions = $false

if ($hasAwsCli) {
    # Check LabRole existence
    try {
        $roleCheck = aws iam get-role --role-name LabRole 2>&1
        if ($LASTEXITCODE -eq 0) {
            $labRoleExists = $true
            Write-Host "✅ LabRole exists and is accessible." -ForegroundColor Green
        } else {
            if ($roleCheck -match "not authorized") {
                Write-Host "⚠️ Cannot verify LabRole due to permission restrictions." -ForegroundColor Yellow
                # In AWS Academy, this is normal - we'll assume LabRole exists
                $labRoleExists = $true
            } else {
                Write-Host "⚠️ LabRole not found: $roleCheck" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "⚠️ Error checking LabRole: $_" -ForegroundColor Yellow
    }
    
    # Test IAM permissions
    try {
        $iamTest = aws iam list-roles --max-items 1 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasIamPermissions = $true
            Write-Host "✅ Has permissions to list IAM roles." -ForegroundColor Green
        } else {
            Write-Host "⚠️ Limited IAM permissions detected." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Cannot verify IAM permissions: $_" -ForegroundColor Yellow
    }
    
    # Test S3 permissions
    try {
        $s3Test = aws s3 ls 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasS3Permissions = $true
            Write-Host "✅ Has permissions to list S3 buckets." -ForegroundColor Green
        } else {
            Write-Host "⚠️ Limited S3 permissions detected." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Cannot verify S3 permissions: $_" -ForegroundColor Yellow
    }
}

# Test if we can create an S3 bucket
$canCreateS3 = $false
if ($hasS3Permissions) {
    $testBucketName = "test-bucket-$((Get-Date).ToString('yyyyMMddHHmmss'))"
    try {
        Write-Host "`nTesting ability to create S3 bucket..." -ForegroundColor Cyan
        $createBucket = aws s3 mb "s3://$testBucketName" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $canCreateS3 = $true
            Write-Host "✅ Can create S3 buckets." -ForegroundColor Green
            # Clean up test bucket
            aws s3 rb "s3://$testBucketName" 2>&1 | Out-Null
        } else {
            Write-Host "⚠️ Cannot create S3 buckets: $createBucket" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Error testing S3 bucket creation: $_" -ForegroundColor Yellow
    }
}

# Determine best deployment method
Write-Host "`n=============================================================="
Write-Host "Determining optimal deployment method..." -ForegroundColor Cyan
Write-Host "=============================================================="

if ($hasAwsCli -and $labRoleExists -and $hasS3Permissions -and $canCreateS3) {
    Write-Host "`n✅ RECOMMENDED DEPLOYMENT METHOD: Full CloudFormation deployment" -ForegroundColor Green
    Write-Host "Your AWS Academy environment appears to have sufficient permissions for"
    Write-Host "deploying the application using CloudFormation with LabRole."
    
    Write-Host "`nDo you want to proceed with the full CloudFormation deployment? (Y/N): " -NoNewline -ForegroundColor Yellow
    $proceed = Read-Host
    
    if ($proceed -eq "Y" -or $proceed -eq "y") {
        Write-Host "`nLaunching CloudFormation deployment with LabRole..." -ForegroundColor Cyan
        & ./deploy_academy.ps1
        exit $LASTEXITCODE
    }
} elseif ($hasAwsCli -and $hasS3Permissions -and $canCreateS3) {
    Write-Host "`n✅ RECOMMENDED DEPLOYMENT METHOD: Simplified S3 deployment" -ForegroundColor Green
    Write-Host "Your AWS Academy environment has permissions to create S3 buckets,"
    Write-Host "but may lack permissions for full CloudFormation deployment."
    
    Write-Host "`nDo you want to proceed with simplified frontend-only deployment? (Y/N): " -NoNewline -ForegroundColor Yellow
    $proceed = Read-Host
    
    if ($proceed -eq "Y" -or $proceed -eq "y") {
        Write-Host "`nLaunching simplified S3 deployment..." -ForegroundColor Cyan
        & ./deploy_simple.ps1
        exit $LASTEXITCODE
    }
} else {
    Write-Host "`n✅ RECOMMENDED DEPLOYMENT METHOD: Manual deployment" -ForegroundColor Green
    Write-Host "Your AWS Academy environment has limited permissions."
    Write-Host "We recommend using the manual deployment guide to deploy through the AWS Console."
    
    Write-Host "`nDo you want to view the manual deployment instructions? (Y/N): " -NoNewline -ForegroundColor Yellow
    $proceed = Read-Host
    
    if ($proceed -eq "Y" -or $proceed -eq "y") {
        Write-Host "`nLaunching manual deployment guide..." -ForegroundColor Cyan
        & ./deploy_manual.ps1
        exit $LASTEXITCODE
    }
}

# If user declined the recommended method, ask what they want to try
Write-Host "`nWhich deployment method would you like to use?" -ForegroundColor Yellow
Write-Host "1. Full CloudFormation deployment (requires most permissions)"
Write-Host "2. Simplified S3 deployment (frontend only)"
Write-Host "3. Manual deployment guide"
Write-Host "4. Exit"
Write-Host "Enter your choice (1-4): " -NoNewline
$choice = Read-Host

switch ($choice) {
    "1" {
        Write-Host "`nLaunching CloudFormation deployment with LabRole..." -ForegroundColor Cyan
        & ./deploy_academy.ps1
        exit $LASTEXITCODE
    }
    "2" {
        Write-Host "`nLaunching simplified S3 deployment..." -ForegroundColor Cyan
        & ./deploy_simple.ps1
        exit $LASTEXITCODE
    }
    "3" {
        Write-Host "`nLaunching manual deployment guide..." -ForegroundColor Cyan
        & ./deploy_manual.ps1
        exit $LASTEXITCODE
    }
    "4" {
        Write-Host "`nExiting deployment script." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "`nInvalid choice. Exiting." -ForegroundColor Red
        exit 1
    }
} 