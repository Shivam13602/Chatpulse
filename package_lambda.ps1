# PowerShell script to package Lambda functions for deployment

Write-Host "=========================================="
Write-Host "Lambda Functions Packaging Script"
Write-Host "=========================================="

# Creating deployment directory if it doesn't exist
$deploymentDir = "deployment"
if (-not (Test-Path $deploymentDir)) {
    New-Item -ItemType Directory -Path $deploymentDir | Out-Null
    Write-Host "Created deployment directory: $deploymentDir"
}

# Function to create a ZIP package for Lambda
function Package-Lambda {
    param(
        [string]$functionName,
        [string]$packageType
    )

    Write-Host "`nPackaging $functionName ($packageType)..."

    # Create temporary directory for packaging
    $tempDir = Join-Path $deploymentDir "temp_$functionName"
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    # Copy function files based on type
    if ($packageType -eq "python") {
        # Copy Python requirements and install dependencies
        Copy-Item "lambda/functions/requirements.txt" -Destination $tempDir
        Copy-Item "lambda/functions/$functionName.py" -Destination $tempDir
        
        Write-Host "Installing Python dependencies..."
        Push-Location $tempDir
        pip install -r requirements.txt -t .
        # Remove tests directories to reduce size
        Get-ChildItem -Path . -Include "tests", "test", "__pycache__" -Recurse -Directory | Remove-Item -Recurse -Force
        Pop-Location
    }
    elseif ($packageType -eq "nodejs") {
        # Copy package.json and install dependencies
        Copy-Item "lambda/functions/package.json" -Destination $tempDir
        Copy-Item "lambda/functions/$functionName.js" -Destination $tempDir
        
        Write-Host "Installing Node.js dependencies..."
        Push-Location $tempDir
        npm install --production
        Pop-Location
    }

    # Create ZIP file
    $zipFile = Join-Path $deploymentDir "$functionName.zip"
    if (Test-Path $zipFile) {
        Remove-Item -Path $zipFile -Force
    }

    Write-Host "Creating ZIP file: $zipFile"
    Push-Location $tempDir
    Compress-Archive -Path ".\*" -DestinationPath $zipFile -Force
    Pop-Location

    # Clean up temp directory
    Remove-Item -Path $tempDir -Recurse -Force

    Write-Host "Package created: $zipFile"
    return $zipFile
}

# Package Python Lambda functions
$connectionManagerZip = Package-Lambda -functionName "connection_manager" -packageType "python"

# Package Node.js Lambda functions
$messageProcessorZip = Package-Lambda -functionName "message_processor" -packageType "nodejs"
$defaultHandlerZip = Package-Lambda -functionName "default_handler" -packageType "nodejs"

Write-Host "`n=========================================="
Write-Host "Packaging complete!"
Write-Host "Lambda function packages saved to the deployment directory:"
Write-Host "- $connectionManagerZip"
Write-Host "- $messageProcessorZip"
Write-Host "- $defaultHandlerZip"
Write-Host "=========================================="`n 