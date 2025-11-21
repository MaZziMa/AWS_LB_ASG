# ALB Demo Scripts

Scripts để demo các tính năng của Application Load Balancer.

## Quick Start

### Demo tổng hợp (Recommended)
```powershell
.\infrastructure\demo-alb-simple.ps1
```

Hiển thị:
- ✅ Target health status
- ✅ Health check configuration  
- ✅ Load distribution (20 requests)
- ✅ Auto Scaling integration
- ✅ CloudWatch metrics

---

## Tính năng ALB được demo

### 1. Health Monitoring
ALB liên tục kiểm tra health của targets:
- Path: `/health`
- Interval: 30 giây
- Timeout: 5 giây
- Healthy threshold: 5 consecutive successes
- Unhealthy threshold: 2 consecutive failures

### 2. Load Distribution
ALB phân phối traffic đều across healthy targets:
- Round-robin algorithm
- Session stickiness (nếu enabled)
- Automatic failover khi target unhealthy

### 3. Auto Scaling Integration
ALB tự động register/deregister instances:
- Instances được add vào target group tự động
- Health checks bắt đầu ngay
- Traffic chỉ route đến healthy targets

### 4. High Availability
- Multi-AZ deployment
- Automatic failover
- Zero downtime scaling

---

## Advanced Demos

### Demo Load Balancing chi tiết
```powershell
.\infrastructure\demo-simple-load.ps1
```
Gửi 30 requests và hiển thị distribution statistics.

### Demo Full Features
```powershell
.\infrastructure\demo-alb-features.ps1 -Demo All
```
Chạy tất cả demos:
- LoadBalance
- HealthCheck
- AutoScale
- Failover (cần confirm)

### Demo Failover (Thận trọng!)
```powershell
.\infrastructure\demo-alb-features.ps1 -Demo Failover
```
⚠️ **Cảnh báo**: Script này sẽ stop một EC2 instance để demo failover!

---

## Monitoring Commands

### Check target health
```powershell
aws elbv2 describe-target-health `
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c
```

### View ALB metrics
```powershell
aws cloudwatch get-metric-statistics `
    --namespace AWS/ApplicationELB `
    --metric-name RequestCount `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --start-time 2025-11-20T00:00:00Z `
    --end-time 2025-11-20T23:59:59Z `
    --period 3600 `
    --statistics Sum
```

### View target response time
```powershell
aws cloudwatch get-metric-statistics `
    --namespace AWS/ApplicationELB `
    --metric-name TargetResponseTime `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --start-time 2025-11-20T00:00:00Z `
    --end-time 2025-11-20T23:59:59Z `
    --period 300 `
    --statistics Average,Maximum
```

---

## Performance Benchmarks

### Expected Results
- **Avg Response Time**: 200-400ms
- **Success Rate**: 100%
- **Load Distribution**: Even across targets (CV < 10%)
- **Health Check**: 30s interval, 5s timeout
- **Failover Time**: < 30s

### During Stress Test
```powershell
# Run stress test
.\infrastructure\run-stress-test.ps1 -Users 200 -RunTime "10m"

# Monitor in another terminal
.\infrastructure\demo-alb-simple.ps1
```

---

## Troubleshooting

### All targets unhealthy
```powershell
# Check instance health
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check Docker containers
ssh -i course-reg-key.pem ec2-user@<INSTANCE_IP>
sudo docker ps
sudo docker logs course-reg-backend
```

### High response time
```powershell
# Check CPU usage
aws cloudwatch get-metric-statistics `
    --namespace AWS/EC2 `
    --metric-name CPUUtilization `
    --dimensions Name=AutoScalingGroupName,Value=course-reg-asg `
    --start-time (Get-Date).AddMinutes(-10).ToUniversalTime() `
    --end-time (Get-Date).ToUniversalTime() `
    --period 60 `
    --statistics Average

# Scale up if needed
aws autoscaling set-desired-capacity `
    --auto-scaling-group-name course-reg-asg `
    --desired-capacity 4
```

### No traffic distribution
Check if sticky sessions enabled:
```powershell
aws elbv2 describe-target-group-attributes `
    --target-group-arn <TG_ARN> `
    --query 'Attributes[?Key==`stickiness.enabled`]'
```

---

## Resources

- **ALB Documentation**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- **CloudWatch Metrics**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html
- **Health Checks**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html

---

## URLs

- **ALB**: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
- **API Docs**: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/api/docs
- **Health Check**: http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health
- **Frontend**: http://course-reg-frontend-8157.s3-website-us-east-1.amazonaws.com
