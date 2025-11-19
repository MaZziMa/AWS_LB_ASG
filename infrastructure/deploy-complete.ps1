# Complete AWS Deployment - Push to ECR and Update ASG
# Automated deployment to existing infrastructure

param(
    [string]$Region = "us-east-1",
    [string]$AccountId = "171308902397",
    [string]$AsgName = "course-reg-asg"
)

Write-Host "=== Complete AWS Deployment ===" -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

# Step 1: Build and push Docker image to ECR
Write-Host "`n[1/6] Building Docker image..." -ForegroundColor Green

Set-Location backend
docker build -t course-reg-backend:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}
Set-Location ..

Write-Host "  [OK] Image built" -ForegroundColor Green

# Step 2: Login to ECR
Write-Host "`n[2/6] Logging into ECR..." -ForegroundColor Green

$ecrUri = "$AccountId.dkr.ecr.$Region.amazonaws.com"
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ecrUri

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] ECR login failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] ECR login successful" -ForegroundColor Green

# Step 3: Tag and push image
Write-Host "`n[3/6] Pushing image to ECR..." -ForegroundColor Green

docker tag course-reg-backend:latest $ecrUri/course-reg-backend:latest
docker tag course-reg-backend:latest $ecrUri/course-reg-backend:production

docker push $ecrUri/course-reg-backend:latest
docker push $ecrUri/course-reg-backend:production

Write-Host "  [OK] Image pushed to ECR" -ForegroundColor Green

# Step 4: Create new Launch Template version
Write-Host "`n[4/6] Creating new Launch Template version..." -ForegroundColor Green

# Get current Launch Template
$ltName = aws autoscaling describe-auto-scaling-groups `
    --auto-scaling-group-names $AsgName `
    --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateName' `
    --output text

if (-not $ltName -or $ltName -eq "None") {
    Write-Host "[ERROR] Launch Template not found!" -ForegroundColor Red
    exit 1
}

Write-Host "  Launch Template: $ltName" -ForegroundColor Cyan

# Read and encode user-data
$userDataContent = Get-Content infrastructure\user-data-docker.sh -Raw
$userDataBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userDataContent))

# Create launch template data JSON
$ltData = @{
    UserData = $userDataBase64
} | ConvertTo-Json

Set-Content -Path "infrastructure\lt-data.json" -Value $ltData

# Create new version with Docker user-data
$newVersion = aws ec2 create-launch-template-version `
    --launch-template-name $ltName `
    --source-version '$Latest' `
    --launch-template-data file://infrastructure/lt-data.json `
    --query 'LaunchTemplateVersion.VersionNumber' `
    --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create Launch Template version!" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Created version $newVersion" -ForegroundColor Green

# Step 5: Update ASG to use new Launch Template version
Write-Host "`n[5/6] Updating Auto Scaling Group..." -ForegroundColor Green

aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name $AsgName `
    --launch-template "LaunchTemplateName=$ltName,Version=$newVersion"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] ASG updated" -ForegroundColor Green
} else {
    Write-Host "[ERROR] ASG update failed!" -ForegroundColor Red
    exit 1
}

# Step 6: Refresh instances (optional)
Write-Host "`n[6/6] Refreshing instances..." -ForegroundColor Green
Write-Host "  This will gradually replace old instances with new ones" -ForegroundColor Yellow

$choice = Read-Host "Start instance refresh? (y/n)"

if ($choice -eq 'y') {
    aws autoscaling start-instance-refresh `
        --auto-scaling-group-name $AsgName `
        --preferences "MinHealthyPercentage=50,InstanceWarmup=300"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Instance refresh started" -ForegroundColor Green
        Write-Host "  Monitor progress with:" -ForegroundColor Cyan
        Write-Host "  aws autoscaling describe-instance-refreshes --auto-scaling-group-name $AsgName" -ForegroundColor Gray
    }
} else {
    Write-Host "  Skipped. Manually terminate instances to refresh:" -ForegroundColor Yellow
    Write-Host "  1. Terminate old instances" -ForegroundColor White
    Write-Host "  2. ASG will launch new instances with Docker" -ForegroundColor White
}

# Summary
Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Docker Image: $ecrUri/course-reg-backend:production" -ForegroundColor White
Write-Host "Launch Template: $ltName (version $newVersion)" -ForegroundColor White
Write-Host "Auto Scaling Group: $AsgName" -ForegroundColor White
Write-Host "`nApplication URL:" -ForegroundColor Yellow
Write-Host "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health" -ForegroundColor Cyan

Write-Host "`n[SUCCESS] Deployment completed!" -ForegroundColor Green
Write-Host "Wait 5-10 minutes for instances to refresh and become healthy" -ForegroundColor Yellow
