# Setup EC2, ALB, and ASG Infrastructure for Course Registration System
# PowerShell script - Chạy: .\setup-infrastructure.ps1

Write-Host "=== AWS Infrastructure Setup ===" -ForegroundColor Cyan
Write-Host "Setting up EC2, ALB, and Auto Scaling Group`n" -ForegroundColor Yellow

# Configuration
$PROJECT_NAME = "course-reg"
$REGION = "us-east-1"
$VPC_ID = "" # Để trống để auto-detect default VPC
$KEY_NAME = "course-reg-key" # Tên key pair của bạn
$ADMIN_IP = "" # IP của bạn để SSH (VD: "1.2.3.4/32"), để trống để auto-detect
$INSTANCE_TYPE = "t3.micro" # Free tier eligible
$INSTANCE_PROFILE_NAME = "MyEC2Profile" # Đặt tên instance profile IAM đã có ở đây

Write-Host "1. Detecting AWS configuration..." -ForegroundColor Yellow

# Get default VPC if not specified
if ([string]::IsNullOrEmpty($VPC_ID)) {
    $VPC_ID = aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION
    Write-Host "Using default VPC: $VPC_ID" -ForegroundColor Green
}

# Get all subnets in VPC
$SUBNETS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $REGION
$SUBNET_ARRAY = $SUBNETS -split '\s+'
Write-Host "Found $($SUBNET_ARRAY.Count) subnets: $SUBNETS" -ForegroundColor Green

# Get availability zones
$AZS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].AvailabilityZone" --output text --region $REGION
Write-Host "Availability Zones: $AZS" -ForegroundColor Green

# Auto-detect public IP if not specified
if ([string]::IsNullOrEmpty($ADMIN_IP)) {
    try {
        $MY_IP = (Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()
        $ADMIN_IP = "$MY_IP/32"
        Write-Host "Detected your IP: $ADMIN_IP" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not auto-detect IP. Please set ADMIN_IP manually." -ForegroundColor Yellow
        $ADMIN_IP = "0.0.0.0/0" # Fallback (not recommended for production)
    }
}

Write-Host "\n2. Creating Security Groups..." -ForegroundColor Yellow

# Create or get existing ALB Security Group
$ALB_SG_ID = aws ec2 describe-security-groups `
    --filters "Name=group-name,Values=$PROJECT_NAME-alb-sg" "Name=vpc-id,Values=$VPC_ID" `
    --query 'SecurityGroups[0].GroupId' `
    --output text `
    --region $REGION

if ($ALB_SG_ID -eq "None" -or [string]::IsNullOrEmpty($ALB_SG_ID)) {
    $ALB_SG_ID = aws ec2 create-security-group `
        --group-name "$PROJECT_NAME-alb-sg" `
        --description "Security group for Course Registration ALB" `
        --vpc-id $VPC_ID `
        --region $REGION `
        --query 'GroupId' `
        --output text
    Write-Host "Created ALB Security Group: $ALB_SG_ID" -ForegroundColor Green
} else {
    Write-Host "Using existing ALB Security Group: $ALB_SG_ID" -ForegroundColor Green
}

# Allow HTTP traffic to ALB (ignore if rule already exists)
aws ec2 authorize-security-group-ingress `
    --group-id $ALB_SG_ID `
    --protocol tcp `
    --port 80 `
    --cidr 0.0.0.0/0 `
    --region $REGION 2>$null

Write-Host "  OK: Allowed HTTP (80) from anywhere" -ForegroundColor Gray

# Create or get existing EC2 Security Group
$EC2_SG_ID = aws ec2 describe-security-groups `
    --filters "Name=group-name,Values=$PROJECT_NAME-ec2-sg" "Name=vpc-id,Values=$VPC_ID" `
    --query 'SecurityGroups[0].GroupId' `
    --output text `
    --region $REGION

if ($EC2_SG_ID -eq "None" -or [string]::IsNullOrEmpty($EC2_SG_ID)) {
    $EC2_SG_ID = aws ec2 create-security-group `
        --group-name "$PROJECT_NAME-ec2-sg" `
        --description "Security group for Course Registration EC2 instances" `
        --vpc-id $VPC_ID `
        --region $REGION `
        --query 'GroupId' `
        --output text
    Write-Host "Created EC2 Security Group: $EC2_SG_ID" -ForegroundColor Green
} else {
    Write-Host "Using existing EC2 Security Group: $EC2_SG_ID" -ForegroundColor Green
}

# Allow traffic from ALB to EC2 on port 8000 (ignore if rule already exists)
aws ec2 authorize-security-group-ingress `
    --group-id $EC2_SG_ID `
    --protocol tcp `
    --port 8000 `
    --source-group $ALB_SG_ID `
    --region $REGION 2>$null

Write-Host "  OK: Allowed port 8000 from ALB" -ForegroundColor Gray

# Allow SSH from anywhere (for easy access)
aws ec2 authorize-security-group-ingress `
    --group-id $EC2_SG_ID `
    --protocol tcp `
    --port 22 `
    --cidr 0.0.0.0/0 `
    --region $REGION 2>$null

Write-Host "  OK: Allowed SSH (22) from anywhere (0.0.0.0/0)" -ForegroundColor Gray


Write-Host "`n3. Using existing IAM Instance Profile for EC2..." -ForegroundColor Yellow
Write-Host "  Using instance profile: $INSTANCE_PROFILE_NAME" -ForegroundColor Green

Write-Host "`n4. Creating Launch Template..." -ForegroundColor Yellow

# Get latest Amazon Linux 2023 AMI
$AMI_ID = aws ec2 describe-images `
    --owners amazon `
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" `
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' `
    --output text `
    --region $REGION

Write-Host "Using AMI: $AMI_ID" -ForegroundColor Green


# Read user data script
$USER_DATA = Get-Content "user-data.sh" -Raw
$USER_DATA_BASE64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($USER_DATA))

# Prepare launch template data as hashtable and convert to JSON
$launchTemplateData = @{
    ImageId = $AMI_ID
    InstanceType = $INSTANCE_TYPE
    KeyName = $KEY_NAME
    SecurityGroupIds = @($EC2_SG_ID)
    IamInstanceProfile = @{
        Name = $INSTANCE_PROFILE_NAME
    }
    UserData = $USER_DATA_BASE64
    TagSpecifications = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{ Key = "Name"; Value = "$PROJECT_NAME-instance" }
                @{ Key = "Project"; Value = $PROJECT_NAME }
            )
        }
    )
}

# Convert to JSON and save to temp file (AWS CLI handles file better than inline JSON)
$tempJsonFile = "launch-template.json"
$launchTemplateData | ConvertTo-Json -Depth 10 | Set-Content $tempJsonFile

# Delete existing launch template if it exists
aws ec2 delete-launch-template `
    --launch-template-name "$PROJECT_NAME-launch-template" `
    --region $REGION 2>$null

# Create launch template
$LAUNCH_TEMPLATE = aws ec2 create-launch-template `
    --launch-template-name "$PROJECT_NAME-launch-template" `
    --version-description "Initial version" `
    --launch-template-data "file://$tempJsonFile" `
    --region $REGION

# Clean up temp file
Remove-Item $tempJsonFile -ErrorAction SilentlyContinue

Write-Host "Created Launch Template: $PROJECT_NAME-launch-template" -ForegroundColor Green

Write-Host "`n5. Creating Target Group..." -ForegroundColor Yellow

$TARGET_GROUP_ARN = aws elbv2 create-target-group `
    --name "$PROJECT_NAME-tg" `
    --protocol HTTP `
    --port 8000 `
    --vpc-id $VPC_ID `
    --health-check-enabled `
    --health-check-protocol HTTP `
    --health-check-path "/health" `
    --health-check-interval-seconds 30 `
    --health-check-timeout-seconds 5 `
    --healthy-threshold-count 2 `
    --unhealthy-threshold-count 3 `
    --region $REGION `
    --query 'TargetGroups[0].TargetGroupArn' `
    --output text

Write-Host "Created Target Group: $TARGET_GROUP_ARN" -ForegroundColor Green

Write-Host "\n6. Creating Application Load Balancer..." -ForegroundColor Yellow

# Check if ALB already exists
$ALB_ARN = aws elbv2 describe-load-balancers `
    --names "$PROJECT_NAME-alb" `
    --query 'LoadBalancers[0].LoadBalancerArn' `
    --output text `
    --region $REGION 2>$null

if ($ALB_ARN -eq "None" -or [string]::IsNullOrEmpty($ALB_ARN)) {
    $ALB_ARN = aws elbv2 create-load-balancer `
        --name "$PROJECT_NAME-alb" `
        --subnets $SUBNET_ARRAY `
        --security-groups $ALB_SG_ID `
        --scheme internet-facing `
        --type application `
        --ip-address-type ipv4 `
        --region $REGION `
        --query 'LoadBalancers[0].LoadBalancerArn' `
        --output text
    Write-Host "Created ALB: $ALB_ARN" -ForegroundColor Green
} else {
    Write-Host "Using existing ALB: $ALB_ARN" -ForegroundColor Green
}

# Get ALB DNS name
$ALB_DNS = aws elbv2 describe-load-balancers `
    --load-balancer-arns $ALB_ARN `
    --query 'LoadBalancers[0].DNSName' `
    --output text `
    --region $REGION

Write-Host "ALB DNS: $ALB_DNS" -ForegroundColor Cyan

# Create listener
$LISTENER_ARN = aws elbv2 create-listener `
    --load-balancer-arn $ALB_ARN `
    --protocol HTTP `
    --port 80 `
    --default-actions "Type=forward,TargetGroupArn=$TARGET_GROUP_ARN" `
    --region $REGION `
    --query 'Listeners[0].ListenerArn' `
    --output text

Write-Host "Created Listener on port 80" -ForegroundColor Green

Write-Host "`n7. Creating Auto Scaling Group..." -ForegroundColor Yellow

aws autoscaling create-auto-scaling-group `
    --auto-scaling-group-name "$PROJECT_NAME-asg" `
    --launch-template "LaunchTemplateName=$PROJECT_NAME-launch-template,Version=`$Latest" `
    --min-size 2 `
    --max-size 10 `
    --desired-capacity 2 `
    --default-cooldown 300 `
    --health-check-type ELB `
    --health-check-grace-period 300 `
    --vpc-zone-identifier "$($SUBNET_ARRAY -join ',')" `
    --target-group-arns $TARGET_GROUP_ARN `
    --region $REGION

Write-Host "Created Auto Scaling Group: $PROJECT_NAME-asg" -ForegroundColor Green

# Create scaling policies
Write-Host "`n8. Creating Auto Scaling Policies..." -ForegroundColor Yellow

# Target tracking scaling policy - CPU
$cpuPolicyConfig = @{
    PredefinedMetricSpecification = @{
        PredefinedMetricType = "ASGAverageCPUUtilization"
    }
    TargetValue = 70.0
}
$cpuPolicyJson = "cpu-policy.json"
$cpuPolicyConfig | ConvertTo-Json -Depth 10 | Set-Content $cpuPolicyJson

aws autoscaling put-scaling-policy `
    --auto-scaling-group-name "$PROJECT_NAME-asg" `
    --policy-name "$PROJECT_NAME-cpu-target-tracking" `
    --policy-type TargetTrackingScaling `
    --target-tracking-configuration "file://$cpuPolicyJson" `
    --region $REGION | Out-Null

Remove-Item $cpuPolicyJson -ErrorAction SilentlyContinue
Write-Host "  OK: Created CPU target tracking policy (70%)" -ForegroundColor Gray

# Target tracking scaling policy - ALB Request Count
$albPolicyConfig = @{
    PredefinedMetricSpecification = @{
        PredefinedMetricType = "ALBRequestCountPerTarget"
        ResourceLabel = "$(($ALB_ARN -split ':loadbalancer/')[1])/$(($TARGET_GROUP_ARN -split ':')[5])"
    }
    TargetValue = 1000.0
}
$albPolicyJson = "alb-policy.json"
$albPolicyConfig | ConvertTo-Json -Depth 10 | Set-Content $albPolicyJson

aws autoscaling put-scaling-policy `
    --auto-scaling-group-name "$PROJECT_NAME-asg" `
    --policy-name "$PROJECT_NAME-alb-request-count-tracking" `
    --policy-type TargetTrackingScaling `
    --target-tracking-configuration "file://$albPolicyJson" `
    --region $REGION | Out-Null

Remove-Item $albPolicyJson -ErrorAction SilentlyContinue
Write-Host "  OK: Created ALB request count tracking policy" -ForegroundColor Gray

Write-Host "`n=== Infrastructure Setup Complete ===" -ForegroundColor Cyan
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  VPC ID: $VPC_ID" -ForegroundColor White
Write-Host "  ALB Security Group: $ALB_SG_ID" -ForegroundColor White
Write-Host "  EC2 Security Group: $EC2_SG_ID" -ForegroundColor White
Write-Host "  Launch Template: $PROJECT_NAME-launch-template" -ForegroundColor White
Write-Host "  Target Group: $TARGET_GROUP_ARN" -ForegroundColor White
Write-Host "  Load Balancer: $ALB_ARN" -ForegroundColor White
Write-Host "  ALB DNS: $ALB_DNS" -ForegroundColor Cyan
Write-Host "  Auto Scaling Group: $PROJECT_NAME-asg (min=2 max=10 desired=2)" -ForegroundColor White

Write-Host ""
Write-Host "Waiting for instances to launch and become healthy (this may take 5-10 minutes)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "To check status:" -ForegroundColor Yellow
Write-Host "  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $PROJECT_NAME-asg" -ForegroundColor White
Write-Host "  aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN" -ForegroundColor White

Write-Host ""
Write-Host "Once healthy, test your application:" -ForegroundColor Yellow
Write-Host "  http://$ALB_DNS/health" -ForegroundColor White
Write-Host "  http://$ALB_DNS/api/courses" -ForegroundColor White

# Save configuration
$CONFIG = @{
    VPC_ID = $VPC_ID
    ALB_SG_ID = $ALB_SG_ID
    EC2_SG_ID = $EC2_SG_ID
    ALB_ARN = $ALB_ARN
    ALB_DNS = $ALB_DNS
    TARGET_GROUP_ARN = $TARGET_GROUP_ARN
    LAUNCH_TEMPLATE = "$PROJECT_NAME-launch-template"
    ASG_NAME = "$PROJECT_NAME-asg"
}
$CONFIG | ConvertTo-Json | Out-File "infrastructure-config.json"

Write-Host ""
Write-Host 'SUCCESS: Configuration saved to infrastructure-config.json' -ForegroundColor Green
