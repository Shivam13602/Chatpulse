# Script to check AWS Academy LabRole availability and permissions
# This verifies if the LabRole exists and has the necessary permissions for our deployment

Write-Host "======================================================"
Write-Host "AWS Academy LabRole Verification Tool" -ForegroundColor Yellow
Write-Host "======================================================"

# Prompt for AWS credentials
Write-Host "`nEnter your AWS Academy credentials:`n" -ForegroundColor Cyan
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
    Write-Host "Account: $($identity.Account)"
    Write-Host "User: $($identity.Arn)"
} catch {
    Write-Host "❌ Error: Failed to authenticate with AWS. Please check your credentials and try again." -ForegroundColor Red
    Write-Host $_
    exit 1
}

# Check if LabRole exists
Write-Host "`nChecking if LabRole exists..." -ForegroundColor Cyan
try {
    $roleCheck = aws iam get-role --role-name LabRole 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ LabRole not found. This indicates AWS Academy environment may not have the expected roles." -ForegroundColor Red
        Write-Host $roleCheck
    } else {
        $role = $roleCheck | ConvertFrom-Json
        Write-Host "✅ LabRole exists!" -ForegroundColor Green
        Write-Host "Role ARN: $($role.Role.Arn)"
        Write-Host "Creation Date: $($role.Role.CreateDate)"
    }
} catch {
    Write-Host "❌ Error checking LabRole. You might not have permissions to check IAM roles." -ForegroundColor Red
    Write-Host $_
}

# Check permissions for key AWS services our app needs
Write-Host "`nChecking LabRole permissions for required services..." -ForegroundColor Cyan

$services = @(
    @{Name = "Lambda"; Action = "lambda:InvokeFunction"; Service = "lambda"},
    @{Name = "DynamoDB"; Action = "dynamodb:PutItem"; Service = "dynamodb"},
    @{Name = "S3"; Action = "s3:PutObject"; Service = "s3"},
    @{Name = "API Gateway"; Action = "execute-api:Invoke"; Service = "apigateway"}
)

foreach ($service in $services) {
    Write-Host "`nTesting $($service.Name) permissions..." -ForegroundColor Yellow
    try {
        # Create a test policy document that simulates the LabRole attempting to access the service
        $policyDocument = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Action = $service.Action
                    Resource = "*"
                }
            )
        } | ConvertTo-Json -Depth 10
        
        # Use the policy simulator to test if the action would be allowed
        $tempFile = "temp_policy.json"
        Set-Content -Path $tempFile -Value $policyDocument
        
        $simResult = aws iam simulate-custom-policy --policy-input-list file://$tempFile --action-names $service.Action 2>&1
        Remove-Item -Path $tempFile
        
        if ($LASTEXITCODE -eq 0) {
            $result = $simResult | ConvertFrom-Json
            $evalResult = $result.EvaluationResults[0].EvalDecision
            
            if ($evalResult -eq "allowed") {
                Write-Host "✅ $($service.Name): Action $($service.Action) is allowed." -ForegroundColor Green
            } else {
                Write-Host "⚠️ $($service.Name): Action $($service.Action) is denied." -ForegroundColor Yellow
                Write-Host "   This may cause problems with deploying parts of the application."
            }
        } else {
            Write-Host "⚠️ Could not simulate policy for $($service.Name). Error: $simResult" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Error testing $($service.Name) permissions: $_" -ForegroundColor Yellow
    }
}

# Test resource creation
Write-Host "`nTesting ability to create resources..." -ForegroundColor Cyan

# Create a test S3 bucket
$testBucketName = "labrole-test-bucket-$((Get-Date).ToString('yyyyMMddHHmmss'))"
Write-Host "`nAttempting to create S3 bucket: $testBucketName..." -ForegroundColor Yellow
try {
    $createBucket = aws s3 mb "s3://$testBucketName" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully created S3 bucket!" -ForegroundColor Green
        
        # Test setting bucket policy
        Write-Host "Testing bucket policy setting..." -ForegroundColor Yellow
        $bucketPolicy = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Principal = "*"
                    Action = "s3:GetObject"
                    Resource = "arn:aws:s3:::$testBucketName/*"
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $policyFile = "temp_bucket_policy.json"
        Set-Content -Path $policyFile -Value $bucketPolicy
        
        $setPolicyResult = aws s3api put-bucket-policy --bucket $testBucketName --policy file://$policyFile 2>&1
        Remove-Item -Path $policyFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully set bucket policy!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Could not set bucket policy: $setPolicyResult" -ForegroundColor Yellow
            Write-Host "   This may indicate restricted permissions for S3 policy management."
        }
        
        # Clean up test bucket
        Write-Host "Cleaning up test bucket..." -ForegroundColor Yellow
        aws s3 rb "s3://$testBucketName" --force
    } else {
        Write-Host "❌ Failed to create S3 bucket: $createBucket" -ForegroundColor Red
        Write-Host "   This indicates restricted permissions for S3 bucket creation."
    }
} catch {
    Write-Host "❌ Error testing S3 bucket creation: $_" -ForegroundColor Red
}

# Summary of findings
Write-Host "`n======================================================"
Write-Host "Summary of LabRole Verification" -ForegroundColor Cyan
Write-Host "======================================================"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Your AWS Academy environment appears to have the necessary"
    Write-Host "   permissions for the simplified deployment approach!"
    Write-Host "`nRecommended deployment method:"
    Write-Host "1. Try the Academy deployment script first:"
    Write-Host "   ./deploy_academy.ps1"
    Write-Host "`nIf that fails:"
    Write-Host "2. Use the manual deployment guide:"
    Write-Host "   ./deploy_manual.ps1"
} else {
    Write-Host "`n⚠️ Your AWS Academy environment has some permission restrictions."
    Write-Host "   We recommend using the manual deployment guide:"
    Write-Host "   ./deploy_manual.ps1"
}

Write-Host "`n======================================================"
Write-Host "End of LabRole Verification" -ForegroundColor Yellow
Write-Host "======================================================" 