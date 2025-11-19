# 🚀 Deploy Docker lên AWS - Course Registration System

## Tổng quan các phương án

AWS cung cấp nhiều service để chạy Docker containers. Dưới đây là so sánh và hướng dẫn chi tiết:

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Container Services                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ECS (Elastic Container Service) - AWS Native ✅ RECOMMENDED │
│  2. ECS Fargate - Serverless Containers                         │
│  3. EKS (Elastic Kubernetes Service) - For K8s                  │
│  4. EC2 + Docker - Manual Setup                                 │
│  5. App Runner - Simple & Fast                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 So sánh các phương án

| Service | Complexity | Cost | Scalability | Best For |
|---------|------------|------|-------------|----------|
| **ECS + EC2** | ⭐⭐⭐ | $$ | ⭐⭐⭐⭐⭐ | Production với full control |
| **ECS Fargate** | ⭐⭐ | $$$ | ⭐⭐⭐⭐ | Không muốn quản lý servers |
| **EKS** | ⭐⭐⭐⭐⭐ | $$$$ | ⭐⭐⭐⭐⭐ | Đã dùng Kubernetes |
| **EC2 + Docker** | ⭐⭐⭐⭐ | $$ | ⭐⭐⭐ | Simple, full SSH access |
| **App Runner** | ⭐ | $$$ | ⭐⭐⭐ | Prototype nhanh |

---

## 🎯 Phương án 1: ECS + EC2 (RECOMMENDED)

### Ưu điểm:
- ✅ Auto scaling dễ dàng
- ✅ Tích hợp ALB, CloudWatch
- ✅ Rolling updates tự động
- ✅ Cost-effective với EC2 instances
- ✅ Full control infrastructure

### Kiến trúc:

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                          │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────▼──────────────┐
        │  Application Load Balancer │
        │      (Port 80/443)         │
        └────────────┬────────────────┘
                     │
        ┌────────────▼────────────────┐
        │    ECS Service (Backend)     │
        │  ┌──────────────────────┐   │
        │  │  Task (Container)    │   │
        │  │  - Backend (8000)    │───┼──► DynamoDB
        │  │  - Redis (6379)      │   │
        │  └──────────────────────┘   │
        │                              │
        │  Auto Scaling: 2-10 tasks   │
        └──────────────────────────────┘
                     │
        ┌────────────▼────────────────┐
        │   EC2 Instances (ECS Nodes) │
        │   t3.medium x 2-4           │
        └─────────────────────────────┘
```

### Bước 1: Push Docker images lên ECR

**Tạo ECR repositories:**

```powershell
# Login AWS CLI
aws configure

# Tạo repository cho backend
aws ecr create-repository `
    --repository-name course-reg-backend `
    --region us-east-1

# Tạo repository cho frontend (optional - có thể dùng S3/CloudFront)
aws ecr create-repository `
    --repository-name course-reg-frontend `
    --region us-east-1

# Get login password
$ECR_URI = "171308902397.dkr.ecr.us-east-1.amazonaws.com"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI
```

**Build và push images:**

```powershell
# Build backend image
cd backend
docker build -t course-reg-backend:latest .

# Tag cho ECR
docker tag course-reg-backend:latest $ECR_URI/course-reg-backend:latest

# Push lên ECR
docker push $ECR_URI/course-reg-backend:latest

# Tương tự cho frontend (nếu cần)
cd ../frontend
docker build -t course-reg-frontend:latest .
docker tag course-reg-frontend:latest $ECR_URI/course-reg-frontend:latest
docker push $ECR_URI/course-reg-frontend:latest
```

### Bước 2: Tạo ECS Task Definition

**File: `infrastructure/ecs-task-definition.json`**

```json
{
  "family": "course-reg-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["EC2"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::171308902397:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::171308902397:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "APP_NAME", "value": "Course Registration System"},
        {"name": "ENVIRONMENT", "value": "production"},
        {"name": "DYNAMODB_REGION", "value": "us-east-1"},
        {"name": "DYNAMODB_TABLE_PREFIX", "value": "CourseReg"},
        {"name": "REDIS_URL", "value": "redis://course-reg-redis.abc123.ng.0001.use1.cache.amazonaws.com:6379"},
        {"name": "CORS_ORIGINS", "value": "[\"*\"]"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/course-registration",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "backend"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    },
    {
      "name": "redis",
      "image": "redis:7-alpine",
      "cpu": 128,
      "memory": 256,
      "essential": false,
      "portMappings": [
        {
          "containerPort": 6379,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/course-registration",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "redis"
        }
      }
    }
  ]
}
```

**Register task definition:**

```powershell
aws ecs register-task-definition `
    --cli-input-json file://infrastructure/ecs-task-definition.json `
    --region us-east-1
```

### Bước 3: Tạo ECS Cluster

```powershell
# Tạo ECS cluster
aws ecs create-cluster `
    --cluster-name course-reg-cluster `
    --region us-east-1

# Tạo Launch Template cho ECS-optimized AMI
$ECS_AMI = "ami-0c94855ba95c574c8"  # ECS-optimized Amazon Linux 2023

$userData = @"
#!/bin/bash
echo ECS_CLUSTER=course-reg-cluster >> /etc/ecs/ecs.config
echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
"@

$userDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Tạo launch template
aws ec2 create-launch-template `
    --launch-template-name course-reg-ecs-template `
    --version-description "ECS optimized template" `
    --launch-template-data "{
        \"ImageId\": \"$ECS_AMI\",
        \"InstanceType\": \"t3.medium\",
        \"IamInstanceProfile\": {\"Name\": \"ecsInstanceRole\"},
        \"SecurityGroupIds\": [\"sg-0d841579862a385b4\"],
        \"UserData\": \"$userDataBase64\",
        \"TagSpecifications\": [{
            \"ResourceType\": \"instance\",
            \"Tags\": [{\"Key\": \"Name\", \"Value\": \"ECS-CourseReg\"}]
        }]
    }"

# Tạo ASG cho ECS cluster
aws autoscaling create-auto-scaling-group `
    --auto-scaling-group-name course-reg-ecs-asg `
    --launch-template "LaunchTemplateName=course-reg-ecs-template" `
    --min-size 2 `
    --max-size 4 `
    --desired-capacity 2 `
    --vpc-zone-identifier "subnet-0c9c1602591be9e78,subnet-0f7540a024afe6066" `
    --tags "Key=Name,Value=ECS-CourseReg,PropagateAtLaunch=true"
```

### Bước 4: Tạo ECS Service với ALB

```powershell
# Tạo target group cho ECS service
$TG_ARN = aws elbv2 create-target-group `
    --name course-reg-ecs-tg `
    --protocol HTTP `
    --port 8000 `
    --vpc-id vpc-09099dfdf6a0b8e2e `
    --target-type ip `
    --health-check-path /health `
    --health-check-interval-seconds 30 `
    --query 'TargetGroups[0].TargetGroupArn' `
    --output text

# Tạo ECS service
aws ecs create-service `
    --cluster course-reg-cluster `
    --service-name course-reg-backend-service `
    --task-definition course-reg-backend `
    --desired-count 2 `
    --launch-type EC2 `
    --load-balancers "targetGroupArn=$TG_ARN,containerName=backend,containerPort=8000" `
    --network-configuration "awsvpcConfiguration={subnets=[subnet-0c9c1602591be9e78,subnet-0f7540a024afe6066],securityGroups=[sg-0d841579862a385b4],assignPublicIp=ENABLED}" `
    --scheduling-strategy REPLICA `
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"

# Add listener rule cho ALB hiện tại
$LISTENER_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:listener/app/course-reg-alb/7d13a6bcf5e0d9f7/..."

aws elbv2 create-rule `
    --listener-arn $LISTENER_ARN `
    --priority 10 `
    --conditions "Field=path-pattern,Values=/api/*" `
    --actions "Type=forward,TargetGroupArn=$TG_ARN"
```

### Bước 5: Enable Auto Scaling cho ECS Service

```powershell
# Register scalable target
aws application-autoscaling register-scalable-target `
    --service-namespace ecs `
    --resource-id service/course-reg-cluster/course-reg-backend-service `
    --scalable-dimension ecs:service:DesiredCount `
    --min-capacity 2 `
    --max-capacity 10

# Target tracking scaling policy (CPU)
aws application-autoscaling put-scaling-policy `
    --service-namespace ecs `
    --resource-id service/course-reg-cluster/course-reg-backend-service `
    --scalable-dimension ecs:service:DesiredCount `
    --policy-name cpu-scaling `
    --policy-type TargetTrackingScaling `
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleInCooldown": 300,
        "ScaleOutCooldown": 60
    }'
```

---

## 🚀 Phương án 2: ECS Fargate (Serverless)

### Ưu điểm:
- ✅ Không cần quản lý EC2
- ✅ Pay per second
- ✅ Auto scaling tự động
- ❌ Chi phí cao hơn EC2

### Deploy Fargate:

```powershell
# Chỉ cần thay đổi launch type
aws ecs create-service `
    --cluster course-reg-cluster `
    --service-name course-reg-backend-fargate `
    --task-definition course-reg-backend:1 `
    --desired-count 2 `
    --launch-type FARGATE `
    --platform-version LATEST `
    --network-configuration "awsvpcConfiguration={
        subnets=[subnet-0c9c1602591be9e78,subnet-0f7540a024afe6066],
        securityGroups=[sg-0d841579862a385b4],
        assignPublicIp=ENABLED
    }" `
    --load-balancers "targetGroupArn=$TG_ARN,containerName=backend,containerPort=8000"
```

**Fargate Task Definition khác biệt:**
```json
{
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",       // 0.5 vCPU
  "memory": "1024",   // 1 GB
  "networkMode": "awsvpc"  // Required for Fargate
}
```

---

## 🔧 Phương án 3: EC2 với Docker Compose

### Ưu điểm:
- ✅ Đơn giản nhất
- ✅ Giống local development
- ✅ Full SSH access
- ❌ Phải quản lý EC2 thủ công

### Deploy:

**1. Launch EC2 instance:**

```powershell
# Tạo EC2 với Docker pre-installed
$INSTANCE_ID = aws ec2 run-instances `
    --image-id ami-0c94855ba95c574c8 `
    --instance-type t3.medium `
    --key-name course-reg-key `
    --security-group-ids sg-0d841579862a385b4 `
    --subnet-id subnet-0c9c1602591be9e78 `
    --iam-instance-profile Name=MyEC2Profile `
    --user-data file://infrastructure/docker-user-data.sh `
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=CourseReg-Docker}]' `
    --query 'Instances[0].InstanceId' `
    --output text
```

**2. User Data Script (`docker-user-data.sh`):**

```bash
#!/bin/bash
set -e

# Install Docker
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone repository
git clone https://github.com/MaZziMa/AWS_LB_ASG.git /opt/course-reg
cd /opt/course-reg

# Create production docker-compose
cat > docker-compose.prod.yml <<EOF
version: "3.9"
services:
  backend:
    image: 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest
    container_name: backend
    environment:
      - DYNAMODB_REGION=us-east-1
      - DYNAMODB_ENDPOINT_URL=
      - REDIS_URL=redis://redis:6379
    ports:
      - "8000:8000"
    restart: always
  
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: always
    
  frontend:
    image: 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-frontend:latest
    container_name: frontend
    ports:
      - "3000:3000"
    restart: always
EOF

# ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 171308902397.dkr.ecr.us-east-1.amazonaws.com

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Setup auto-restart on boot
cat > /etc/systemd/system/docker-compose-app.service <<EOF
[Unit]
Description=Docker Compose Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/course-reg
ExecStart=/usr/local/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.prod.yml down

[Install]
WantedBy=multi-user.target
EOF

systemctl enable docker-compose-app.service
```

**3. Deploy updates:**

```powershell
# SSH vào instance
$EC2_IP = aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

ssh -i course-reg-key.pem ec2-user@$EC2_IP

# Trên EC2:
cd /opt/course-reg
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

---

## 📦 Phương án 4: AWS App Runner

### Ưu điểm:
- ✅ Deploy nhanh nhất
- ✅ Không config gì
- ✅ Auto scaling tự động
- ❌ Chi phí cao nhất
- ❌ Ít control

### Deploy:

```powershell
# Tạo App Runner service từ ECR
aws apprunner create-service `
    --service-name course-reg-backend `
    --source-configuration '{
        "ImageRepository": {
            "ImageIdentifier": "171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest",
            "ImageRepositoryType": "ECR",
            "ImageConfiguration": {
                "Port": "8000",
                "RuntimeEnvironmentVariables": {
                    "DYNAMODB_REGION": "us-east-1",
                    "REDIS_URL": "redis://..."
                }
            }
        },
        "AutoDeploymentsEnabled": true,
        "AuthenticationConfiguration": {
            "AccessRoleArn": "arn:aws:iam::171308902397:role/AppRunnerECRAccessRole"
        }
    }' `
    --instance-configuration '{
        "Cpu": "1 vCPU",
        "Memory": "2 GB"
    }'
```

---

## 🎨 Kiến trúc Production hoàn chỉnh

```
                          ┌──────────────────┐
                          │   Route 53 DNS   │
                          │  course-reg.com  │
                          └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │   CloudFront     │
                          │  (CDN + HTTPS)   │
                          └────────┬─────────┘
                                   │
                 ┌─────────────────┴──────────────────┐
                 │                                     │
        ┌────────▼─────────┐              ┌───────────▼──────────┐
        │   S3 Bucket      │              │   Application LB     │
        │  (Frontend)      │              │   (Backend API)      │
        └──────────────────┘              └───────────┬──────────┘
                                                      │
                                          ┌───────────▼──────────┐
                                          │   ECS Cluster        │
                                          │  ┌────────────────┐  │
                                          │  │ Backend Tasks  │  │
                                          │  │ (2-10 tasks)   │  │
                                          │  └────────┬───────┘  │
                                          └───────────┼──────────┘
                                                      │
                            ┌─────────────────────────┼─────────────────────┐
                            │                         │                     │
                   ┌────────▼────────┐    ┌──────────▼────────┐   ┌────────▼────────┐
                   │   DynamoDB      │    │  ElastiCache      │   │   CloudWatch    │
                   │   (Database)    │    │   (Redis)         │   │   (Logs/Metrics)│
                   └─────────────────┘    └───────────────────┘   └─────────────────┘
```

### Services cần thiết:

1. **Frontend**: S3 + CloudFront
2. **Backend**: ECS + EC2 hoặc Fargate
3. **Database**: DynamoDB (đã có)
4. **Cache**: ElastiCache Redis
5. **Load Balancer**: ALB (đã có)
6. **DNS**: Route 53
7. **SSL**: ACM Certificate
8. **Monitoring**: CloudWatch
9. **CI/CD**: CodePipeline + CodeBuild

---

## 💰 Chi phí ước tính (us-east-1)

### Option 1: ECS + EC2
- **EC2**: 2x t3.medium = ~$60/month
- **ALB**: ~$20/month
- **DynamoDB**: ~$5/month (on-demand)
- **ElastiCache**: t3.micro = ~$12/month
- **CloudWatch**: ~$5/month
- **Data Transfer**: ~$10/month
- **Total**: ~$112/month

### Option 2: ECS Fargate
- **Fargate**: 2 tasks x $35 = ~$70/month
- **ALB**: ~$20/month
- **DynamoDB**: ~$5/month
- **ElastiCache**: ~$12/month
- **CloudWatch**: ~$5/month
- **Total**: ~$112/month (tương đương nhưng easier)

### Option 3: App Runner
- **App Runner**: 2 instances = ~$50/month
- **DynamoDB**: ~$5/month
- **ElastiCache**: ~$12/month
- **Total**: ~$67/month (simplest)

---

## 🚀 Script tự động hoá deploy

**File: `infrastructure/deploy-to-ecs.ps1`**

```powershell
param(
    [string]$Environment = "production",
    [string]$Region = "us-east-1"
)

Write-Host "=== Deploying to ECS ===" -ForegroundColor Cyan

# 1. Build and push images
Write-Host "[1/5] Building Docker images..." -ForegroundColor Yellow
cd backend
docker build -t course-reg-backend:latest .
cd ../frontend
docker build -t course-reg-frontend:latest .

# 2. Push to ECR
Write-Host "[2/5] Pushing to ECR..." -ForegroundColor Yellow
$ECR_URI = "171308902397.dkr.ecr.$Region.amazonaws.com"
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ECR_URI

docker tag course-reg-backend:latest $ECR_URI/course-reg-backend:latest
docker push $ECR_URI/course-reg-backend:latest

docker tag course-reg-frontend:latest $ECR_URI/course-reg-frontend:latest
docker push $ECR_URI/course-reg-frontend:latest

# 3. Update task definition
Write-Host "[3/5] Updating task definition..." -ForegroundColor Yellow
$TASK_DEF = aws ecs register-task-definition `
    --cli-input-json file://infrastructure/ecs-task-definition.json `
    --query 'taskDefinition.taskDefinitionArn' `
    --output text

# 4. Update service
Write-Host "[4/5] Updating ECS service..." -ForegroundColor Yellow
aws ecs update-service `
    --cluster course-reg-cluster `
    --service course-reg-backend-service `
    --task-definition $TASK_DEF `
    --force-new-deployment

# 5. Wait for deployment
Write-Host "[5/5] Waiting for deployment to complete..." -ForegroundColor Yellow
aws ecs wait services-stable `
    --cluster course-reg-cluster `
    --services course-reg-backend-service

Write-Host "✅ Deployment complete!" -ForegroundColor Green
```

**Chạy deploy:**

```powershell
.\infrastructure\deploy-to-ecs.ps1 -Environment production
```

---

## 📋 Checklist Deploy

- [ ] Push Docker images lên ECR
- [ ] Tạo ECS Cluster
- [ ] Register Task Definition
- [ ] Tạo ECS Service với ALB
- [ ] Setup Auto Scaling
- [ ] Configure ElastiCache Redis (thay local Redis)
- [ ] Update environment variables
- [ ] Setup CloudWatch Logs
- [ ] Configure SSL certificate
- [ ] Setup Route 53 DNS
- [ ] Deploy frontend lên S3 + CloudFront
- [ ] Test health checks
- [ ] Monitor metrics

---

## 🔍 Monitoring & Troubleshooting

### Xem logs:

```powershell
# ECS service logs
aws logs tail /ecs/course-registration --follow

# Specific task logs
aws ecs describe-tasks --cluster course-reg-cluster --tasks <task-id>
```

### Debug container:

```powershell
# Execute command trong running task
aws ecs execute-command `
    --cluster course-reg-cluster `
    --task <task-id> `
    --container backend `
    --interactive `
    --command "/bin/bash"
```

### Rollback:

```powershell
# Rollback về task definition cũ
aws ecs update-service `
    --cluster course-reg-cluster `
    --service course-reg-backend-service `
    --task-definition course-reg-backend:3  # previous version
```

---

## 🎓 Best Practices

1. **Use ECR Lifecycle Policies**: Tự động xóa old images
2. **Enable Container Insights**: Monitor CPU/Memory chi tiết
3. **Use Secrets Manager**: Lưu credentials, không hardcode
4. **Blue/Green Deployment**: Zero downtime updates
5. **Health Checks**: Configure đúng để ALB route traffic
6. **Resource Limits**: Set CPU/Memory limits để tránh OOM
7. **Logging**: Centralize logs vào CloudWatch
8. **Tagging**: Tag resources để tracking cost

---

## 📚 Next Steps

1. **Setup CI/CD**: GitHub Actions → Build → Push ECR → Deploy ECS
2. **Add Monitoring**: CloudWatch Dashboards + Alarms
3. **Security**: WAF, Security Groups, IAM least privilege
4. **Backup**: DynamoDB Point-in-Time Recovery
5. **Performance**: ElastiCache query caching
6. **CDN**: CloudFront cho static assets

Bạn muốn mình tạo script tự động cho phương án nào? ECS + EC2 hay Fargate?
