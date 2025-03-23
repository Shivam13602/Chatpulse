# Simple PowerShell script to test if the S3 hosted website is accessible
Write-Host "=========================================="
Write-Host "S3 Website Accessibility Test"
Write-Host "=========================================="

# Prompt for the S3 website URL
Write-Host "Enter the S3 website URL to test (e.g., http://your-bucket-name.s3-website-us-east-1.amazonaws.com):"
$websiteUrl = Read-Host

if (-not $websiteUrl) {
    Write-Host "Error: No URL provided." -ForegroundColor Red
    exit 1
}

# Try to access the website
Write-Host "`nTesting website accessibility for: $websiteUrl" -ForegroundColor Yellow
try {
    # Create a web request object
    $request = [System.Net.WebRequest]::Create($websiteUrl)
    $request.Method = "HEAD"
    $request.Timeout = 15000 # 15 seconds
    
    # Get the response
    $response = $request.GetResponse()
    
    # Check if the response was successful
    if ($response.StatusCode -eq "OK") {
        Write-Host "`n✅ SUCCESS: Website is accessible!" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Content Type: $($response.ContentType)" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️ WARNING: Got response but with status: $($response.StatusCode)" -ForegroundColor Yellow
    }
    
    # Close the response
    $response.Close()
}
catch [System.Net.WebException] {
    Write-Host "`n❌ ERROR: Website is not accessible!" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    
    # Provide troubleshooting tips
    Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Check if your bucket name is correct in the URL"
    Write-Host "2. Verify that static website hosting is enabled for the bucket"
    Write-Host "3. Ensure your bucket policy allows public read access"
    Write-Host "4. Confirm that the index.html file was uploaded successfully"
    Write-Host "5. Check that the content type was set to 'text/html'"
}

Write-Host "`n=========================================="
Write-Host "If the website is accessible, you can now proceed with testing the chat functionality."
Write-Host "See the TESTING_GUIDE.md for detailed testing instructions."
Write-Host "===========================================" 