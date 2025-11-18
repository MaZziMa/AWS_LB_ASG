# Deploy Full Project to EC2 with Auto Scaling
# Packages and uploads backend + frontend to S3, then deploys via new launch template

param(
    [string]$S3Bucket = "course-reg-deployment-$(Get-Random)",
    [string]$Region = "us-east-1"
)

Write-Host "=== Deploying Course Registration System ===" -ForegroundColor Cyan
Write-Host "S3 Bucket: $S3Bucket" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

# Navigate to project root
Set-Location $PSScriptRoot\..

# Step 1: Create deployment package
Write-Host "`n[1/6] Creating deployment package..." -ForegroundColor Green

# Create temp deployment directory
$deployDir = ".\temp-deploy"
if (Test-Path $deployDir) {
    Remove-Item -Path $deployDir -Recurse -Force
}
New-Item -ItemType Directory -Path $deployDir | Out-Null

# Copy backend
Write-Host "  - Copying backend files..." -ForegroundColor Gray
Copy-Item -Path ".\backend\*" -Destination "$deployDir\backend" -Recurse -Exclude ".env",".venv","__pycache__","*.pyc","node_modules"

# Build frontend
Write-Host "  - Building frontend..." -ForegroundColor Gray
Set-Location .\frontend
if (Test-Path ".\dist") {
    Remove-Item -Path ".\dist" -Recurse -Force
}

# Check if npm install is needed
if (!(Test-Path ".\node_modules")) {
    Write-Host "  - Installing frontend dependencies..." -ForegroundColor Yellow
    npm install
}

npm run build | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Frontend build failed!" -ForegroundColor Red
    exit 1
}

# Copy built frontend
Set-Location ..
Copy-Item -Path ".\frontend\dist\*" -Destination "$deployDir\frontend" -Recurse

# Create deployment archive
Write-Host "  - Creating archive..." -ForegroundColor Gray
$archivePath = ".\deploy-package.zip"
if (Test-Path $archivePath) {
    Remove-Item $archivePath
}

Compress-Archive -Path "$deployDir\*" -DestinationPath $archivePath

# Cleanup temp directory
Remove-Item -Path $deployDir -Recurse -Force

$archiveSize = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
Write-Host "  ✓ Package created: $archiveSize MB" -ForegroundColor Green

# Step 2: Create S3 bucket and upload
Write-Host "`n[2/6] Uploading to S3..." -ForegroundColor Green

# Create S3 bucket
Write-Host "  - Creating S3 bucket: $S3Bucket" -ForegroundColor Gray
aws s3 mb "s3://$S3Bucket" --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Note: Bucket may already exist" -ForegroundColor Yellow
}

# Upload package
Write-Host "  - Uploading deployment package..." -ForegroundColor Gray
aws s3 cp $archivePath "s3://$S3Bucket/deploy-package.zip" --region $Region
if ($LASTEXITCODE -ne 0) {
    Write-Host "S3 upload failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Uploaded to s3://$S3Bucket/deploy-package.zip" -ForegroundColor Green

# Step 3: Create DynamoDB tables
Write-Host "`n[3/6] Setting up DynamoDB tables..." -ForegroundColor Green
Set-Location .\infrastructure
.\create-dynamodb-tables.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Warning: Some DynamoDB tables may already exist" -ForegroundColor Yellow
}

# Step 4: Update IAM role permissions
Write-Host "`n[4/6] Updating IAM permissions..." -ForegroundColor Green

# Get role name from instance profile
$roleName = aws iam get-instance-profile --instance-profile-name MyEC2Profile --query 'InstanceProfile.Roles[0].RoleName' --output text

Write-Host "  - IAM Role: $roleName" -ForegroundColor Gray

# Create policy document for additional permissions
$policyDoc = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "dynamodb:ConditionCheckItem",
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:ListTables"
            )
            Resource = @(
                "arn:aws:dynamodb:${Region}:*:table/CourseReg_*"
            )
        },
        @{
            Effect = "Allow"
            Action = @(
                "s3:GetObject",
                "s3:ListBucket"
            )
            Resource = @(
                "arn:aws:s3:::$S3Bucket/*",
                "arn:aws:s3:::$S3Bucket"
            )
        }
    )
} | ConvertTo-Json -Depth 10

$policyFile = ".\temp-iam-policy.json"
$policyDoc | Out-File -FilePath $policyFile -Encoding utf8

# Create inline policy
Write-Host "  - Attaching DynamoDB + S3 policy..." -ForegroundColor Gray
aws iam put-role-policy `
    --role-name $roleName `
    --policy-name CourseRegAppPolicy `
    --policy-document "file://$policyFile"

Remove-Item $policyFile

Write-Host "  ✓ IAM permissions updated" -ForegroundColor Green

# Step 5: Create new user-data script
Write-Host "`n[5/6] Creating new user-data script..." -ForegroundColor Green

$userData = @"
#!/bin/bash
set -e

echo "=== Course Registration System Deployment ==="
echo "Starting at: `$(date)"

# Update system
sudo dnf update -y

# Install Python 3.11
echo "[1/7] Installing Python 3.11..."
sudo dnf install -y python3.11 python3.11-pip unzip

# Install Node.js (for potential frontend serving)
echo "[2/7] Installing Node.js..."
sudo dnf install -y nodejs npm

# Create application directory
echo "[3/7] Creating application directories..."
sudo mkdir -p /opt/course-registration
cd /opt/course-registration

# Download deployment package from S3
echo "[4/7] Downloading application from S3..."
aws s3 cp s3://$S3Bucket/deploy-package.zip . --region $Region
unzip -q deploy-package.zip
rm deploy-package.zip

# Install Python dependencies
echo "[5/7] Installing Python dependencies..."
cd /opt/course-registration/backend
python3.11 -m pip install --upgrade pip
python3.11 -m pip install -r requirements.txt

# Create .env file with all required variables
echo "[6/7] Creating environment configuration..."

# Get instance metadata for dynamic values
INSTANCE_ID=`$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=`$(ec2-metadata --availability-zone | cut -d " " -f 2)

cat > .env << ENV
# Application
APP_NAME=Course Registration System
APP_VERSION=1.0.0
DEBUG=False
ENVIRONMENT=production

# Server
HOST=0.0.0.0
PORT=8000
WORKERS=4

# DynamoDB Configuration
DYNAMODB_REGION=$Region
DYNAMODB_ENDPOINT_URL=
DYNAMODB_TABLE_PREFIX=CourseReg

# Redis (ElastiCache - localhost fallback for now)
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=
REDIS_MAX_CONNECTIONS=50

# JWT Authentication
SECRET_KEY=`$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# AWS Configuration (IAM Role automatically provides credentials)
AWS_REGION=$Region
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# SQS Queue (Update with your actual queue URL if using SQS)
SQS_QUEUE_URL=
SQS_EMAIL_QUEUE_URL=

# S3 Bucket
S3_BUCKET_NAME=$S3Bucket

# CloudWatch
CLOUDWATCH_NAMESPACE=CourseRegistration
CLOUDWATCH_LOG_GROUP=/aws/course-registration

# Rate Limiting
RATE_LIMIT_PER_MINUTE=100
MAX_ENROLLMENT_PER_REQUEST=5

# CORS (Allow all origins - restrict in production)
CORS_ORIGINS=["*"]

# Email (SES - configure if needed)
SES_SENDER_EMAIL=noreply@example.com
SES_REGION=$Region

# Celery (Background Tasks - not configured yet)
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/2

# Monitoring
PROMETHEUS_PORT=9090

# Instance Metadata (for debugging)
INSTANCE_ID=`$INSTANCE_ID
AVAILABILITY_ZONE=`$AVAILABILITY_ZONE
ENV

# Create systemd service
echo "[7/7] Creating systemd service..."
sudo tee /etc/systemd/system/course-registration.service > /dev/null << 'SERVICE'
[Unit]
Description=Course Registration FastAPI Application
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/course-registration/backend
Environment="PATH=/usr/bin:/usr/local/bin"
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Set permissions
sudo chown -R ec2-user:ec2-user /opt/course-registration

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable course-registration
sudo systemctl start course-registration

# Wait for service to start
sleep 5

# Check service status
if systemctl is-active --quiet course-registration; then
    echo "✓ Course Registration service started successfully"
    curl -s http://localhost:8000/health || echo "Health check pending..."
else
    echo "✗ Service failed to start"
    sudo systemctl status course-registration
    sudo journalctl -u course-registration -n 50
fi

echo "=== Deployment completed at: `$(date) ==="
"@

$userDataFile = ".\user-data-full-deploy.sh"
$userData | Out-File -FilePath $userDataFile -Encoding utf8

Write-Host "  ✓ User-data script created" -ForegroundColor Green

# Step 6: Update launch template and create new instance
Write-Host "`n[6/6] Updating infrastructure..." -ForegroundColor Green

# Create new launch template version
Write-Host "  - Creating new launch template version..." -ForegroundColor Gray

$launchTemplateData = @{
    ImageId = "ami-0cae6d6fe6048ca2c"
    InstanceType = "t3.micro"
    KeyName = "course-reg-key"
    IamInstanceProfile = @{
        Name = "MyEC2Profile"
    }
    SecurityGroupIds = @("sg-05d7200f233ca2a6b")
    UserData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))
    TagSpecifications = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{ Key = "Name"; Value = "CourseReg-App-Server" },
                @{ Key = "Project"; Value = "CourseRegistration" },
                @{ Key = "ManagedBy"; Value = "AutoScaling" }
            )
        }
    )
} | ConvertTo-Json -Depth 10

$ltFile = ".\temp-launch-template.json"
$launchTemplateData | Out-File -FilePath $ltFile -Encoding utf8

$newVersion = aws ec2 create-launch-template-version `
    --launch-template-name course-reg-launch-template `
    --launch-template-data "file://$ltFile" `
    --query 'LaunchTemplateVersion.VersionNumber' `
    --output text

Remove-Item $ltFile

if ($newVersion) {
    Write-Host "  ✓ Created launch template version: $newVersion" -ForegroundColor Green
    
    # Set as default version
    aws ec2 modify-launch-template `
        --launch-template-name course-reg-launch-template `
        --default-version $newVersion | Out-Null
    
    Write-Host "  ✓ Set as default version" -ForegroundColor Green
} else {
    Write-Host "  Failed to create launch template version" -ForegroundColor Red
    exit 1
}

# Refresh Auto Scaling Group
Write-Host "  - Refreshing Auto Scaling Group..." -ForegroundColor Gray
aws autoscaling start-instance-refresh `
    --auto-scaling-group-name course-reg-asg `
    --preferences '{"MinHealthyPercentage":50}' | Out-Null

Write-Host "  ✓ Instance refresh started" -ForegroundColor Green

# Cleanup
Write-Host "`n[Cleanup] Removing temporary files..." -ForegroundColor Gray
Remove-Item .\user-data-full-deploy.sh -ErrorAction SilentlyContinue
Remove-Item ..\deploy-package.zip -ErrorAction SilentlyContinue

Write-Host "`n=== Deployment Initiated Successfully ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Monitor instance refresh:" -ForegroundColor White
Write-Host "     aws autoscaling describe-instance-refreshes --auto-scaling-group-name course-reg-asg" -ForegroundColor Gray
Write-Host "`n  2. Check new instance health:" -ForegroundColor White
Write-Host "     .\monitor-target-health.ps1" -ForegroundColor Gray
Write-Host "`n  3. View application logs:" -ForegroundColor White
Write-Host "     ssh -i course-reg-key.pem ec2-user@<new-instance-ip>" -ForegroundColor Gray
Write-Host "     sudo journalctl -u course-registration -f" -ForegroundColor Gray
Write-Host "`n  4. Access application:" -ForegroundColor White
Write-Host "     http://course-reg-alb-118381901.us-east-1.elb.amazonaws.com" -ForegroundColor Cyan
Write-Host "`n  5. S3 Bucket created: $S3Bucket" -ForegroundColor White
Write-Host "     (You can delete it later if not needed)" -ForegroundColor Gray
