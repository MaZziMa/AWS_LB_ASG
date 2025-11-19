# Infrastructure Status - Stopped State

**Date**: November 19, 2025
**Status**: ✅ All infrastructure preserved, EC2 instances stopped

---

## 💰 Current Monthly Cost: ~$18-20

### Cost Breakdown:
- **Application Load Balancer**: ~$16.20/month ($0.0225/hour)
- **DynamoDB**: $0 (Free tier: 25GB storage, 200M requests/month)
- **S3**: ~$0.05/month (minimal storage)
- **CloudFront**: $0 (Free tier: 1TB data transfer)
- **ECR**: $0.10/GB/month (~$0.50 for Docker images)
- **EC2**: $0 (0 instances running)

---

## ✅ Preserved Resources

### Compute Infrastructure
- ✅ **Auto Scaling Group**: course-reg-asg (Min: 0, Max: 0, Desired: 0)
- ✅ **Launch Template**: course-reg-launch-template (v4 - latest with Docker config)
- ✅ **Load Balancer**: course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
- ✅ **Target Group**: course-reg-tg (port 8000, health check: /health)
- ✅ **Security Groups**:
  - ALB SG: sg-057d743683ed68c8d
  - EC2 SG: sg-0d841579862a385b4

### Data & Storage
- ✅ **DynamoDB Tables** (with data):
  - CourseReg_Users
  - CourseReg_Courses
  - CourseReg_Enrollments
- ✅ **S3 Bucket**: course-reg-frontend-8157 (with frontend files)
- ✅ **ECR Repository**: course-reg-backend (latest image ready)

### CDN & Distribution
- ✅ **CloudFront**: E2S4IFJP95G5RJ (d29n7tymvy4jvo.cloudfront.net)
- ✅ **Status**: Deployed and Enabled

### IAM & Access
- ✅ **IAM Role**: MyEC2Profile
  - AmazonEC2ContainerRegistryReadOnly
  - AmazonDynamoDBFullAccess
- ✅ **Key Pair**: course-reg-key.pem (local file)

---

## 🚀 Quick Restart Command

### Start 2 EC2 instances (Ready in 5 minutes):
```powershell
aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name course-reg-asg `
    --min-size 2 `
    --max-size 10 `
    --desired-capacity 2 `
    --region us-east-1
```

### Verify after 5 minutes:
```powershell
# Check instances
aws autoscaling describe-auto-scaling-groups `
    --auto-scaling-group-names course-reg-asg `
    --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' `
    --output table

# Check target health
aws elbv2 describe-target-health `
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c

# Test backend
curl http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health
```

### Access Application:
- **Frontend**: https://d29n7tymvy4jvo.cloudfront.net
- **Backend API**: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/api/docs

---

## 📝 Test Accounts (Data Preserved)

- **Admin**: admin / admin123
- **Teacher**: teacher1 / teacher123
- **Student**: student1 / student123

---

## 🔧 Configuration Details

### Backend Configuration (Launch Template v4)
- **Base Image**: 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest
- **Instance Type**: t3.micro
- **Docker Compose**: Auto-installs on launch
- **Environment Variables**:
  - DYNAMODB_REGION: us-east-1
  - DYNAMODB_TABLE_PREFIX: CourseReg
  - REDIS_URL: redis://redis:6379/0
  - CORS_ORIGINS: localhost, S3, CloudFront URLs
  - PORT: 8000

### Frontend Configuration
- **S3 Bucket**: course-reg-frontend-8157
- **CloudFront Distribution**: E2S4IFJP95G5RJ
- **Build**: Vite production build
- **API URL**: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/api

---

## 📚 Documentation Files

- **RESTART_GUIDE.md** - Detailed restart instructions
- **DEPLOYMENT_SUMMARY.md** - Initial deployment details
- **README.md** - Project overview
- **HOW_TO_RUN.md** - Local development guide

---

## ⚠️ Important Notes

1. **Launch Template v4** is the latest with correct CORS configuration
2. **DynamoDB data** is preserved (5 users, 5 courses, 4 enrollments)
3. **ECR image** is production-ready with latest backend code
4. **CloudFront** is active and will serve cached frontend immediately
5. **Security Groups** allow SSH from anywhere (0.0.0.0/0) for troubleshooting

---

## 🗑️ Complete Cleanup (if needed)

To delete everything and stop all costs:
```powershell
cd d:\AWS_LB_ASG
.\infrastructure\cleanup-infrastructure.ps1
```

⚠️ **Warning**: This will delete all data and cannot be undone!

---

**Status Last Updated**: November 19, 2025, 4:15 PM UTC
**Next Action**: Run restart command when ready to use the application
