# Deploy Frontend to S3 + CloudFront
# Static website hosting for React app

param(
    [string]$Region = "us-east-1",
    [string]$BucketName = "course-reg-frontend-$(Get-Random -Maximum 9999)",
    [string]$BackendUrl = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
)

Write-Host "=== Deploying Frontend to AWS S3 ===" -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

# Step 1: Update API URL in frontend
Write-Host "`n[1/5] Updating API URL..." -ForegroundColor Green

$envContent = @"
VITE_API_URL=$BackendUrl
"@

Set-Content -Path "frontend\.env.production" -Value $envContent
Write-Host "  [OK] API URL set to: $BackendUrl" -ForegroundColor Green

# Step 2: Build frontend
Write-Host "`n[2/5] Building frontend..." -ForegroundColor Green

Set-Location frontend
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}

Set-Location ..
Write-Host "  [OK] Frontend built" -ForegroundColor Green

# Step 3: Create S3 bucket
Write-Host "`n[3/5] Creating S3 bucket..." -ForegroundColor Green
Write-Host "  Bucket name: $BucketName" -ForegroundColor Cyan

try {
    aws s3api create-bucket --bucket $BucketName --region $Region 2>&1 | Out-Null
    Write-Host "  [OK] Bucket created: $BucketName" -ForegroundColor Green
} catch {
    Write-Host "  [OK] Using existing bucket: $BucketName" -ForegroundColor Green
}

# Configure bucket for website hosting
aws s3 website s3://$BucketName/ --index-document index.html --error-document index.html

# Make bucket public
$bucketPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BucketName/*"
    }
  ]
}
"@

Set-Content -Path "infrastructure\bucket-policy.json" -Value $bucketPolicy
aws s3api put-bucket-policy --bucket $BucketName --policy file://infrastructure/bucket-policy.json

Write-Host "  [OK] Bucket configured for public access" -ForegroundColor Green

# Step 4: Upload files to S3
Write-Host "`n[4/5] Uploading files to S3..." -ForegroundColor Green

aws s3 sync frontend/dist s3://$BucketName/ --delete

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Files uploaded" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Upload failed!" -ForegroundColor Red
    exit 1
}

# Step 5: Get website URL
Write-Host "`n[5/5] Getting website URL..." -ForegroundColor Green

$websiteUrl = "http://$BucketName.s3-website-$Region.amazonaws.com"

# Summary
Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Bucket Name: $BucketName" -ForegroundColor White
Write-Host "Website URL: $websiteUrl" -ForegroundColor Cyan
Write-Host "Backend API: $BackendUrl" -ForegroundColor White

Write-Host "`n[SUCCESS] Frontend deployed!" -ForegroundColor Green
Write-Host "Visit: $websiteUrl" -ForegroundColor Yellow

Write-Host "`nOptional - Setup CloudFront for HTTPS:" -ForegroundColor Yellow
Write-Host "  1. Go to CloudFront console" -ForegroundColor White
Write-Host "  2. Create distribution with origin: $BucketName.s3-website-$Region.amazonaws.com" -ForegroundColor White
Write-Host "  3. Configure custom domain if needed" -ForegroundColor White
