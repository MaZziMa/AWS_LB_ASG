# Deploy Docker to Existing EC2 Instances
# Uses existing ASG instances with Docker

param(
    [string]$Region = "us-east-1",
    [string]$KeyPairName = "course-reg-key",
    [string]$AsgName = "course-reg-asg"
)

Write-Host "=== Deploying Docker to EC2 Instances ===" -ForegroundColor Cyan

# Step 1: Get EC2 instances from ASG
Write-Host "`n[1/5] Getting EC2 instances..." -ForegroundColor Green

$instanceIds = aws autoscaling describe-auto-scaling-groups `
    --auto-scaling-group-names $AsgName `
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' `
    --output json | ConvertFrom-Json

if (-not $instanceIds -or $instanceIds.Count -eq 0) {
    Write-Host "[ERROR] No instances found in ASG!" -ForegroundColor Red
    exit 1
}

Write-Host "  Found $($instanceIds.Count) instances" -ForegroundColor Green

# Get first instance IP
$instanceIp = aws ec2 describe-instances `
    --instance-ids $instanceIds[0] `
    --query 'Reservations[0].Instances[0].PublicIpAddress' `
    --output text

Write-Host "  Instance IP: $instanceIp" -ForegroundColor Cyan

# Step 2: Create deployment package
Write-Host "`n[2/5] Creating deployment package..." -ForegroundColor Green

$deployDir = "infrastructure\ec2-deploy"
if (Test-Path $deployDir) {
    Remove-Item -Recurse -Force $deployDir
}
New-Item -ItemType Directory -Path $deployDir | Out-Null

# Copy docker-compose for production
$prodCompose = @"
version: '3.9'

services:
  redis:
    image: redis:7
    container_name: course-reg-redis
    restart: always
    ports:
      - "6379:6379"

  backend:
    image: aws_lb_asg-backend:latest
    container_name: course-reg-backend
    restart: always
    depends_on:
      - redis
    environment:
      APP_NAME: Course Registration System
      APP_VERSION: "1.0.0"
      DEBUG: "false"
      ENVIRONMENT: production
      HOST: 0.0.0.0
      PORT: "8000"
      WORKERS: "2"
      DYNAMODB_REGION: $Region
      DYNAMODB_ENDPOINT_URL: ""
      DYNAMODB_TABLE_PREFIX: CourseReg
      REDIS_URL: redis://redis:6379/0
      CORS_ORIGINS: '["*"]'
      AWS_REGION: $Region
    ports:
      - "8000:8000"

networks:
  default:
    name: course-reg-net
"@

Set-Content -Path "$deployDir\docker-compose.yml" -Value $prodCompose

# Create deployment script
$deployScript = @"
#!/bin/bash
set -e

echo "=== Installing Docker ==="
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

echo "=== Installing Docker Compose ==="
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "=== Creating app directory ==="
sudo mkdir -p /opt/course-reg
cd /opt/course-reg

echo "=== Building Docker images ==="
# Images will be built from local Dockerfile or pulled from ECR

echo "=== Starting services ==="
sudo /usr/local/bin/docker-compose up -d

echo "=== Deployment complete! ==="
sudo docker ps
"@

Set-Content -Path "$deployDir\deploy.sh" -Value $deployScript

Write-Host "  [OK] Package created" -ForegroundColor Green

# Step 3: Build and save Docker images locally
Write-Host "`n[3/5] Building Docker images..." -ForegroundColor Green

Set-Location backend
docker build -t aws_lb_asg-backend:latest . --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Backend build failed!" -ForegroundColor Red
    exit 1
}
Set-Location ..

Write-Host "  [OK] Images built" -ForegroundColor Green

# Step 4: Save image as tar
Write-Host "`n[4/5] Exporting Docker image..." -ForegroundColor Green

docker save aws_lb_asg-backend:latest -o "$deployDir\backend-image.tar"
Write-Host "  [OK] Image exported" -ForegroundColor Green

# Step 5: Display manual instructions
Write-Host "`n[5/5] Manual Deployment Steps:" -ForegroundColor Green
Write-Host @"

📦 Deployment package created in: $deployDir

To deploy manually:

1. Copy files to EC2:
   scp -i $KeyPairName.pem -r $deployDir ec2-user@${instanceIp}:/home/ec2-user/

2. SSH to EC2:
   ssh -i $KeyPairName.pem ec2-user@$instanceIp

3. On EC2, run:
   cd ec2-deploy
   chmod +x deploy.sh
   sudo ./deploy.sh
   
   # Load Docker image
   sudo docker load -i backend-image.tar
   
   # Start services
   sudo docker-compose up -d

4. Verify:
   curl http://localhost:8000/health

Your app will be accessible via ALB:
http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com

"@ -ForegroundColor Yellow

Write-Host "`n[SUCCESS] Deployment package ready!" -ForegroundColor Green
