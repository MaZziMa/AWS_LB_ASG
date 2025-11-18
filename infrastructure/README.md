# AWS Infrastructure Setup Guide

## Course Registration System - EC2, ALB, and Auto Scaling

Hướng dẫn setup infrastructure AWS cho hệ thống đăng ký môn học với Auto Scaling và Load Balancing.

---

## 📋 Prerequisites

1. **AWS CLI đã cài đặt và cấu hình**
   ```powershell
   aws configure
   ```

2. **AWS Account với quyền:**
   - EC2 (Launch instances, Security Groups)
   - ELB (Application Load Balancer)
   - Auto Scaling
   - IAM (Create roles và policies)
   - DynamoDB (nếu chưa có tables)

3. **EC2 Key Pair**
   ```powershell
   # Tạo key pair mới
   aws ec2 create-key-pair --key-name course-reg-key --query 'KeyMaterial' --output text > course-reg-key.pem
   ```

4. **DynamoDB Tables đã được tạo** (xem `backend/scripts/create_tables.py`)

---

## 🚀 Quick Start

### Option 1: Tự động với Script (Khuyến nghị)

```powershell
cd infrastructure
.\setup-infrastructure.ps1
```

Script này sẽ tự động tạo:
- ✅ Security Groups (ALB + EC2)
- ✅ IAM Role và Instance Profile
- ✅ Launch Template với User Data
- ✅ Target Group
- ✅ Application Load Balancer
- ✅ Auto Scaling Group (min=2, max=10)
- ✅ Auto Scaling Policies (CPU 70%)

### Option 2: Setup Manual (Chi tiết từng bước)

Xem phần [📖 Manual Setup Guide](#-manual-setup-guide) bên dưới.

---

### Bước tiếp theo: Chờ instances khởi động (5-10 phút)

```powershell
# Kiểm tra Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names course-reg-asg

# Kiểm tra Target Health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
```

### Bước 3: Test Application

```powershell
# Lấy ALB DNS từ file config
$CONFIG = Get-Content infrastructure-config.json | ConvertFrom-Json
$ALB_DNS = $CONFIG.ALB_DNS

# Test health endpoint
curl http://$ALB_DNS/health

# Test API
curl http://$ALB_DNS/api/courses
```

---

## 📖 Manual Setup Guide

Hướng dẫn tạo từng resource bằng tay thông qua AWS CLI hoặc Console.

### Bước 1: Tạo Security Groups

#### 1.1. Tạo Security Group cho ALB

**AWS CLI:**
```powershell
# Lấy VPC ID
$VPC_ID = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text

# Tạo ALB Security Group
$ALB_SG_ID = aws ec2 create-security-group `
  --group-name "course-reg-alb-sg" `
  --description "Security group for Course Registration ALB" `
  --vpc-id $VPC_ID `
  --query 'GroupId' --output text

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress `
  --group-id $ALB_SG_ID `
  --protocol tcp `
  --port 80 `
  --cidr 0.0.0.0/0

# Allow HTTPS from anywhere (optional)
aws ec2 authorize-security-group-ingress `
  --group-id $ALB_SG_ID `
  --protocol tcp `
  --port 443 `
  --cidr 0.0.0.0/0

# Tag
aws ec2 create-tags --resources $ALB_SG_ID --tags Key=Name,Value=course-reg-alb-sg

Write-Host "ALB Security Group ID: $ALB_SG_ID"
```

**AWS Console:**
1. EC2 Dashboard → Security Groups → Create security group
2. Name: `course-reg-alb-sg`
3. VPC: Default VPC
4. Inbound rules:
   - Type: HTTP, Port: 80, Source: 0.0.0.0/0
   - Type: HTTPS, Port: 443, Source: 0.0.0.0/0 (optional)
5. Create security group

#### 1.2. Tạo Security Group cho EC2

**AWS CLI:**
```powershell
# Lấy public IP của máy bạn
$ADMIN_IP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content.Trim()

# Tạo EC2 Security Group
$EC2_SG_ID = aws ec2 create-security-group `
  --group-name "course-reg-ec2-sg" `
  --description "Security group for Course Registration EC2 instances" `
  --vpc-id $VPC_ID `
  --query 'GroupId' --output text

# Allow port 8000 from ALB
aws ec2 authorize-security-group-ingress `
  --group-id $EC2_SG_ID `
  --protocol tcp `
  --port 8000 `
  --source-group $ALB_SG_ID

# Allow SSH from admin IP
aws ec2 authorize-security-group-ingress `
  --group-id $EC2_SG_ID `
  --protocol tcp `
  --port 22 `
  --cidr "$ADMIN_IP/32"

# Tag
aws ec2 create-tags --resources $EC2_SG_ID --tags Key=Name,Value=course-reg-ec2-sg

Write-Host "EC2 Security Group ID: $EC2_SG_ID"
```

**AWS Console:**
1. EC2 Dashboard → Security Groups → Create security group
2. Name: `course-reg-ec2-sg`
3. VPC: Default VPC
4. Inbound rules:
   - Type: Custom TCP, Port: 8000, Source: course-reg-alb-sg
   - Type: SSH, Port: 22, Source: My IP
5. Create security group

---

### Bước 2: Tạo IAM Role cho EC2

#### 2.1. Tạo Trust Policy

**AWS CLI:**
```powershell
# Tạo trust policy file
$TRUST_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

$TRUST_POLICY | Out-File -FilePath trust-policy.json -Encoding utf8

# Tạo IAM Role
aws iam create-role `
  --role-name course-reg-ec2-role `
  --assume-role-policy-document file://trust-policy.json

# Attach managed policies
aws iam attach-role-policy `
  --role-name course-reg-ec2-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam attach-role-policy `
  --role-name course-reg-ec2-role `
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

aws iam attach-role-policy `
  --role-name course-reg-ec2-role `
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Tạo Instance Profile
aws iam create-instance-profile `
  --instance-profile-name course-reg-instance-profile

# Add role to instance profile
aws iam add-role-to-instance-profile `
  --instance-profile-name course-reg-instance-profile `
  --role-name course-reg-ec2-role

Write-Host "IAM Role created: course-reg-ec2-role"
Write-Host "Instance Profile: course-reg-instance-profile"
```

**AWS Console:**
1. IAM Dashboard → Roles → Create role
2. Trusted entity: AWS service → EC2
3. Permissions policies (attach):
   - `AmazonDynamoDBFullAccess`
   - `CloudWatchAgentServerPolicy`
   - `AmazonSSMManagedInstanceCore`
4. Role name: `course-reg-ec2-role`
5. Create role

---

### Bước 3: Tạo Launch Template

#### 3.1. Chuẩn bị User Data Script

User data script đã có sẵn tại `infrastructure/user-data.sh`. Encode sang base64:

```powershell
$USER_DATA_CONTENT = Get-Content -Path user-data.sh -Raw
$USER_DATA_BASE64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($USER_DATA_CONTENT))
```

#### 3.2. Tạo Launch Template

**AWS CLI:**
```powershell
# Lấy AMI ID mới nhất (Amazon Linux 2023)
$AMI_ID = aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" `
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' `
  --output text

# Tạo launch template
aws ec2 create-launch-template `
  --launch-template-name course-reg-launch-template `
  --version-description "v1.0" `
  --launch-template-data @"
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.micro",
  "KeyName": "course-reg-key",
  "IamInstanceProfile": {
    "Name": "course-reg-instance-profile"
  },
  "SecurityGroupIds": ["$EC2_SG_ID"],
  "UserData": "$USER_DATA_BASE64",
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "course-reg-instance"},
        {"Key": "Project", "Value": "course-registration"}
      ]
    }
  ]
}
"@

Write-Host "Launch Template created: course-reg-launch-template"
```

**AWS Console:**
1. EC2 Dashboard → Launch Templates → Create launch template
2. Template name: `course-reg-launch-template`
3. AMI: Amazon Linux 2023 (latest)
4. Instance type: `t3.micro`
5. Key pair: `course-reg-key`
6. Network settings:
   - Security groups: `course-reg-ec2-sg`
7. Advanced details:
   - IAM instance profile: `course-reg-instance-profile`
   - User data: Copy nội dung từ `user-data.sh`
8. Create launch template

---

### Bước 4: Tạo Target Group

**AWS CLI:**
```powershell
# Tạo Target Group
$TG_ARN = aws elbv2 create-target-group `
  --name course-reg-tg `
  --protocol HTTP `
  --port 8000 `
  --vpc-id $VPC_ID `
  --health-check-protocol HTTP `
  --health-check-path /health `
  --health-check-interval-seconds 30 `
  --health-check-timeout-seconds 5 `
  --healthy-threshold-count 2 `
  --unhealthy-threshold-count 3 `
  --matcher HttpCode=200 `
  --target-type instance `
  --query 'TargetGroups[0].TargetGroupArn' --output text

# Modify deregistration delay
aws elbv2 modify-target-group-attributes `
  --target-group-arn $TG_ARN `
  --attributes Key=deregistration_delay.timeout_seconds,Value=30

Write-Host "Target Group ARN: $TG_ARN"
```

**AWS Console:**
1. EC2 Dashboard → Target Groups → Create target group
2. Target type: Instances
3. Target group name: `course-reg-tg`
4. Protocol: HTTP, Port: 8000
5. VPC: Default VPC
6. Health check:
   - Protocol: HTTP
   - Path: `/health`
   - Interval: 30 seconds
   - Timeout: 5 seconds
   - Healthy threshold: 2
   - Unhealthy threshold: 3
7. Create target group

---

### Bước 5: Tạo Application Load Balancer

**AWS CLI:**
```powershell
# Lấy subnet IDs
$SUBNET_IDS = aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" `
  --query 'Subnets[*].SubnetId' --output text

# Convert to array
$SUBNET_ARRAY = $SUBNET_IDS -split '\s+'

# Tạo ALB
$ALB_ARN = aws elbv2 create-load-balancer `
  --name course-reg-alb `
  --subnets $SUBNET_ARRAY `
  --security-groups $ALB_SG_ID `
  --scheme internet-facing `
  --type application `
  --ip-address-type ipv4 `
  --query 'LoadBalancers[0].LoadBalancerArn' --output text

# Chờ ALB active
Write-Host "Waiting for ALB to become active..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

# Tạo Listener
aws elbv2 create-listener `
  --load-balancer-arn $ALB_ARN `
  --protocol HTTP `
  --port 80 `
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Lấy ALB DNS
$ALB_DNS = aws elbv2 describe-load-balancers `
  --load-balancer-arns $ALB_ARN `
  --query 'LoadBalancers[0].DNSName' --output text

Write-Host "ALB DNS: $ALB_DNS"
```

**AWS Console:**
1. EC2 Dashboard → Load Balancers → Create load balancer
2. Type: Application Load Balancer
3. Name: `course-reg-alb`
4. Scheme: Internet-facing
5. Network mapping:
   - VPC: Default VPC
   - Mappings: Select all availability zones
6. Security groups: `course-reg-alb-sg`
7. Listeners:
   - Protocol: HTTP, Port: 80
   - Default action: Forward to `course-reg-tg`
8. Create load balancer

---

### Bước 6: Tạo Auto Scaling Group

**AWS CLI:**
```powershell
# Tạo Auto Scaling Group
aws autoscaling create-auto-scaling-group `
  --auto-scaling-group-name course-reg-asg `
  --launch-template LaunchTemplateName=course-reg-launch-template `
  --min-size 2 `
  --max-size 10 `
  --desired-capacity 2 `
  --default-cooldown 300 `
  --health-check-type ELB `
  --health-check-grace-period 300 `
  --vpc-zone-identifier "$($SUBNET_ARRAY -join ',')" `
  --target-group-arns $TG_ARN `
  --tags "Key=Name,Value=course-reg-asg-instance,PropagateAtLaunch=true" "Key=Project,Value=course-registration,PropagateAtLaunch=true"

Write-Host "Auto Scaling Group created: course-reg-asg"
```

**AWS Console:**
1. EC2 Dashboard → Auto Scaling Groups → Create Auto Scaling group
2. Name: `course-reg-asg`
3. Launch template: `course-reg-launch-template`
4. Network:
   - VPC: Default VPC
   - Subnets: Select all available subnets
5. Load balancing:
   - Attach to existing load balancer
   - Target group: `course-reg-tg`
6. Health checks:
   - Type: ELB
   - Grace period: 300 seconds
7. Group size:
   - Desired: 2
   - Minimum: 2
   - Maximum: 10
8. Scaling policies: (sẽ thêm ở bước 7)
9. Create Auto Scaling group

---

### Bước 7: Tạo Auto Scaling Policies

#### 7.1. Target Tracking Policy - CPU Utilization

**AWS CLI:**
```powershell
# Tạo policy config file
$CPU_POLICY = @"
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  }
}
"@

$CPU_POLICY | Out-File -FilePath cpu-policy.json -Encoding utf8

# Tạo scaling policy
aws autoscaling put-scaling-policy `
  --auto-scaling-group-name course-reg-asg `
  --policy-name course-reg-cpu-policy `
  --policy-type TargetTrackingScaling `
  --target-tracking-configuration file://cpu-policy.json

Write-Host "CPU Scaling Policy created"
```

**AWS Console:**
1. EC2 → Auto Scaling Groups → course-reg-asg → Automatic scaling
2. Create dynamic scaling policy
3. Policy type: Target tracking scaling
4. Metric type: Average CPU utilization
5. Target value: 70
6. Policy name: `course-reg-cpu-policy`
7. Create

#### 7.2. Target Tracking Policy - ALB Request Count

**AWS CLI:**
```powershell
# Tạo request count policy
$REQUEST_POLICY = @"
{
  "TargetValue": 1000.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ALBRequestCountPerTarget",
    "ResourceLabel": "app/course-reg-alb/<alb-id>/<alb-version>/targetgroup/course-reg-tg/<tg-id>"
  }
}
"@

# Lấy resource label
$ALB_SUFFIX = ($ALB_ARN -split ':loadbalancer/')[1]
$TG_SUFFIX = ($TG_ARN -split ':')[5] -replace 'targetgroup/', ''
$RESOURCE_LABEL = "$ALB_SUFFIX/$TG_SUFFIX"

$REQUEST_POLICY = $REQUEST_POLICY -replace '<alb-id>/<alb-version>/targetgroup/course-reg-tg/<tg-id>', $RESOURCE_LABEL
$REQUEST_POLICY | Out-File -FilePath request-policy.json -Encoding utf8

aws autoscaling put-scaling-policy `
  --auto-scaling-group-name course-reg-asg `
  --policy-name course-reg-request-policy `
  --policy-type TargetTrackingScaling `
  --target-tracking-configuration file://request-policy.json

Write-Host "Request Count Scaling Policy created"
```

**AWS Console:**
1. EC2 → Auto Scaling Groups → course-reg-asg → Automatic scaling
2. Create dynamic scaling policy
3. Policy type: Target tracking scaling
4. Metric type: Application Load Balancer request count per target
5. Target group: `course-reg-tg`
6. Target value: 1000
7. Policy name: `course-reg-request-policy`
8. Create

---

### Bước 8: Verify và Test

```powershell
# 1. Kiểm tra Auto Scaling Group
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names course-reg-asg

# 2. Kiểm tra instances
aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=course-reg-asg-instance" `
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' `
  --output table

# 3. Kiểm tra target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# 4. Test ALB endpoint
curl http://$ALB_DNS/health

# 5. Test API
curl http://$ALB_DNS/api/courses
```

---

### Bước 9: Lưu Configuration

Lưu tất cả IDs và ARNs để dễ quản lý sau này:

```powershell
$CONFIG = @{
    VPC_ID = $VPC_ID
    ALB_SG_ID = $ALB_SG_ID
    EC2_SG_ID = $EC2_SG_ID
    IAM_ROLE = "course-reg-ec2-role"
    INSTANCE_PROFILE = "course-reg-instance-profile"
    LAUNCH_TEMPLATE = "course-reg-launch-template"
    TARGET_GROUP_ARN = $TG_ARN
    ALB_ARN = $ALB_ARN
    ALB_DNS = $ALB_DNS
    ASG_NAME = "course-reg-asg"
    REGION = "us-east-1"
}

$CONFIG | ConvertTo-Json | Out-File -FilePath infrastructure-config.json

Write-Host "Configuration saved to infrastructure-config.json"
```

---

## 📁 File Structure

```
infrastructure/
├── setup-infrastructure.ps1   # Main setup script
├── user-data.sh               # EC2 initialization script
├── cleanup-infrastructure.ps1 # Cleanup script
├── infrastructure-config.json # Generated config (gitignored)
└── README.md                  # This file
```

---

## 🔧 Configuration

### Tùy chỉnh trong `setup-infrastructure.ps1`:

```powershell
$PROJECT_NAME = "course-reg"          # Prefix cho tất cả resources
$REGION = "us-east-1"                  # AWS region
$INSTANCE_TYPE = "t3.micro"            # Instance type (free tier)
$KEY_NAME = "course-reg-key"           # EC2 key pair name
```

### Auto Scaling Configuration:

```powershell
# Min, Max, Desired capacity
--min-size 2 --max-size 10 --desired-capacity 2

# Health check grace period
--health-check-grace-period 300  # 5 minutes

# Cooldown period
--default-cooldown 300  # 5 minutes between scaling actions
```

### Scaling Policies:

1. **CPU Target Tracking (70%)**
   - Scale out khi CPU > 70%
   - Scale in khi CPU < 70%

2. **ALB Request Count (1000 requests/target)**
   - Scale out khi requests/target > 1000
   - Scale in khi < 1000

---

## 🏗️ Architecture

```
                    Internet
                       │
                       ▼
              ┌────────────────┐
              │ Application    │
              │ Load Balancer  │
              │ (Port 80)      │
              └────────┬───────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    ┌────────┐    ┌────────┐    ┌────────┐
    │  EC2   │    │  EC2   │    │  EC2   │
    │ :8000  │    │ :8000  │    │ :8000  │
    └───┬────┘    └───┬────┘    └───┬────┘
        │             │             │
        └─────────────┼─────────────┘
                      ▼
              ┌────────────────┐
              │   DynamoDB     │
              │ (3 tables)     │
              └────────────────┘
```

### Components:

1. **ALB (Application Load Balancer)**
   - Internet-facing
   - Health check: `/health`
   - Target: EC2 instances port 8000

2. **Auto Scaling Group**
   - Maintains 2-10 instances
   - Distributes across multiple AZs
   - Auto-replaces unhealthy instances

3. **EC2 Instances**
   - Amazon Linux 2023
   - Python 3.11 + FastAPI
   - CloudWatch agent installed
   - IAM role for DynamoDB access

4. **Security Groups**
   - ALB SG: Allow 80 from anywhere
   - EC2 SG: Allow 8000 from ALB, 22 from admin IP

---

## 🔍 Monitoring

### CloudWatch Metrics

Metrics tự động được gửi:
- CPU Utilization (EC2)
- Memory Usage (CloudWatch Agent)
- Disk Usage (CloudWatch Agent)
- Request Count (ALB)
- Target Response Time (ALB)
- Healthy/Unhealthy Host Count

### View Metrics:

```powershell
# EC2 CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=course-reg-asg \
  --start-time 2025-11-17T00:00:00Z \
  --end-time 2025-11-17T23:59:59Z \
  --period 300 \
  --statistics Average

# ALB Request Count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/course-reg-alb/xxxxx \
  --start-time 2025-11-17T00:00:00Z \
  --end-time 2025-11-17T23:59:59Z \
  --period 300 \
  --statistics Sum
```

### CloudWatch Logs:

```powershell
# View user-data logs
aws logs tail /aws/ec2/course-registration/user-data --follow

# View system logs
aws logs tail /aws/ec2/course-registration/system --follow
```

---

## 🔄 Scaling Behavior

### Scale Out (Add instances):
- CPU > 70% for 2 consecutive periods (10 minutes)
- OR ALB requests/target > 1000 for 2 consecutive periods
- Cooldown: 5 minutes

### Scale In (Remove instances):
- CPU < 70% for 15 consecutive periods (~75 minutes)
- AND ALB requests/target < 1000
- Cooldown: 5 minutes

### Manual Scaling:

```powershell
# Set desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name course-reg-asg \
  --desired-capacity 5

# Update min/max
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name course-reg-asg \
  --min-size 3 \
  --max-size 15
```

---

## 🐛 Troubleshooting

### Instance không healthy

```powershell
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# SSH vào instance
ssh -i course-reg-key.pem ec2-user@<INSTANCE_IP>

# Check application logs
sudo journalctl -u course-registration -f

# Check user-data logs
sudo cat /var/log/user-data.log
```

### ALB trả 503 Service Unavailable

- Instances đang khởi động (chờ health check pass)
- Health check path sai (`/health` phải return 200)
- Security group chặn traffic từ ALB đến EC2

### Auto Scaling không trigger

```powershell
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name course-reg-asg

# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name course-reg-asg \
  --max-records 20

# Check CloudWatch alarms
aws cloudwatch describe-alarms
```

### Application không kết nối DynamoDB

- Kiểm tra IAM role có quyền DynamoDB
- Kiểm tra table names trong `.env`
- Kiểm tra region đúng

---

## 💰 Cost Estimate

**Monthly costs (us-east-1, on-demand pricing):**

| Service | Configuration | Cost/month |
|---------|--------------|-----------|
| EC2 (t3.micro) | 2 instances × 730 hours | ~$15 |
| ALB | 730 hours + data processed | ~$20 |
| DynamoDB | On-demand (light usage) | ~$5 |
| CloudWatch | Metrics + Logs | ~$5 |
| Data Transfer | First 100GB free | $0-10 |
| **Total** | | **~$45-55/month** |

**Free Tier eligible:**
- EC2 t2.micro: 750 hours/month (first 12 months)
- ALB: 750 hours/month (first 12 months)
- DynamoDB: 25GB storage + 25 WCU/RCU (always free)

**Cost savings tips:**
- Dùng Reserved Instances (-40% cost)
- Dùng Savings Plans
- Scale in vào ban đêm/cuối tuần
- Enable DynamoDB auto-scaling với min capacity thấp

---

## 🧹 Cleanup

### Xóa toàn bộ infrastructure:

```powershell
cd infrastructure
.\cleanup-infrastructure.ps1
```

### Xóa thủ công nếu cần:

```powershell
# Delete ASG
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name course-reg-asg \
  --force-delete

# Delete ALB
aws elbv2 delete-load-balancer \
  --load-balancer-arn <ARN>

# Delete Target Group
aws elbv2 delete-target-group \
  --target-group-arn <ARN>

# Delete Launch Template
aws ec2 delete-launch-template \
  --launch-template-name course-reg-launch-template

# Delete Security Groups
aws ec2 delete-security-group --group-id <ALB_SG_ID>
aws ec2 delete-security-group --group-id <EC2_SG_ID>
```

---

## 📚 Additional Resources

- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/)
- [EC2 User Data Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [CloudWatch Metrics Documentation](https://docs.aws.amazon.com/cloudwatch/)

---

## 🆘 Support

Nếu gặp vấn đề:

1. Kiểm tra CloudWatch Logs
2. Kiểm tra Security Groups
3. Kiểm tra IAM permissions
4. Review User Data script logs
5. SSH vào instance để debug

---

**Status:** ✅ Production Ready
**Last Updated:** November 17, 2025
