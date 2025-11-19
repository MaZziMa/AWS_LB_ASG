# Quick Restart Guide

## Current Status (Stopped State)
- **EC2 Instances**: 0 (Auto Scaling Group set to 0)
- **Load Balancer**: ACTIVE (course-reg-alb-1073823580.us-east-1.elb.amazonaws.com)
- **Target Group**: ACTIVE (course-reg-tg)
- **Launch Template**: ACTIVE (course-reg-launch-template v4)
- **DynamoDB Tables**: ACTIVE with data
- **S3 Frontend**: ACTIVE (course-reg-frontend-8157)
- **CloudFront**: ACTIVE (d29n7tymvy4jvo.cloudfront.net)
- **ECR Image**: AVAILABLE (171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest)

**Monthly Cost (Stopped)**: ~$18-20 (ALB + minimal DynamoDB/S3/CloudFront)

---

## Quick Restart (2-3 minutes)

### Option 1: Via AWS CLI
```powershell
# Start 2 instances
aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name course-reg-asg `
    --min-size 2 `
    --max-size 10 `
    --desired-capacity 2 `
    --region us-east-1

# Wait 5 minutes for instances to be healthy
Start-Sleep -Seconds 300

# Check status
aws elbv2 describe-target-health `
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c
```

### Option 2: Via AWS Console
1. Go to: https://console.aws.amazon.com/ec2/autoscaling/home?region=us-east-1#/details/course-reg-asg?view=details
2. Click **Edit**
3. Set:
   - Min: 2
   - Max: 10
   - Desired: 2
4. Click **Update**
5. Wait 5 minutes for instances to launch and become healthy

---

## Verify Application is Running

### Backend Health Check
```powershell
curl http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health
```
Expected: `{"status":"healthy","version":"1.0.0","environment":"production"}`

### Frontend
- CloudFront URL: https://d29n7tymvy4jvo.cloudfront.net
- S3 URL: http://course-reg-frontend-8157.s3-website-us-east-1.amazonaws.com

### Test Login
- **Admin**: admin / admin123
- **Teacher**: teacher1 / teacher123
- **Student**: student1 / student123

---

## Infrastructure Details

### Network
- **VPC**: vpc-09099dfdf6a0b8e2e
- **ALB Security Group**: sg-057d743683ed68c8d (allows HTTP 80 from 0.0.0.0/0)
- **EC2 Security Group**: sg-0d841579862a385b4 (allows port 8000 from ALB, SSH 22 from 0.0.0.0/0)

### Compute
- **Instance Type**: t3.micro
- **AMI**: Amazon Linux 2023
- **IAM Role**: MyEC2Profile
  - AmazonEC2ContainerRegistryReadOnly
  - AmazonDynamoDBFullAccess

### Database
- **DynamoDB Tables**:
  - CourseReg_Users (GSI: username-index, email-index)
  - CourseReg_Courses
  - CourseReg_Enrollments (GSI: user-index, course-index)
- **Region**: us-east-1

### Container Registry
- **Backend Image**: 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest
- **Version**: production (Launch Template v4)

---

## Troubleshooting

### If instances don't become healthy:
1. Check instance logs:
```powershell
# Get instance ID
$instanceId = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names course-reg-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text

# Get system log
aws ec2 get-console-output --instance-id $instanceId --output text
```

2. SSH into instance:
```powershell
ssh -i "course-reg-key.pem" ec2-user@<INSTANCE-IP>

# Check Docker container
sudo docker ps
sudo docker logs course-reg-backend
```

### If need to update backend code:
```powershell
# Rebuild and push new image
cd d:\AWS_LB_ASG
.\infrastructure\deploy-complete.ps1
```

### If need to update frontend:
```powershell
cd d:\AWS_LB_ASG\frontend
npm run build
aws s3 sync dist/ s3://course-reg-frontend-8157/ --delete
aws cloudfront create-invalidation --distribution-id E2S4IFJP95G5RJ --paths "/*"
```

---

## Stop Again

To stop and minimize costs:
```powershell
aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name course-reg-asg `
    --min-size 0 `
    --max-size 0 `
    --desired-capacity 0 `
    --region us-east-1
```

---

## Complete Cleanup (Delete Everything)

If you want to delete all resources:
```powershell
cd d:\AWS_LB_ASG
.\infrastructure\cleanup-infrastructure.ps1
```

This will delete:
- Auto Scaling Group
- Load Balancer
- Target Group
- Launch Template
- Security Groups
- DynamoDB Tables
- S3 Bucket
- CloudFront Distribution
- ECR Repository
