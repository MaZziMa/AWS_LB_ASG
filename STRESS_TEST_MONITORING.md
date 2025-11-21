# Stress Test Monitoring Guide

## Setup Complete! ✓

CloudWatch Dashboard and Alarms have been created successfully.

## View Monitoring

### Option 1: Real-time PowerShell Monitor (Recommended for testing)
```powershell
.\infrastructure\monitor-realtime.ps1
```
- Updates every 10 seconds
- Shows target health, ASG status, ALB metrics, EC2 CPU, DynamoDB
- Color-coded output (Green=healthy, Yellow=warning, Red=critical)
- Press Ctrl+C to stop

### Option 2: AWS CloudWatch Dashboard
Open in browser: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=CourseReg-LoadTest-Dashboard

Features:
- ALB Request Count & Active Connections
- ALB Response Time (Average + p99)
- HTTP Status Codes (2xx/4xx/5xx)
- Target Health Count
- EC2 CPU Utilization (with 70% threshold line)
- EC2 Network Traffic
- DynamoDB Consumed Capacity
- DynamoDB Errors
- Recent Error Logs

### Option 3: CloudWatch Alarms
View alarms: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:

Created Alarms:
- **CourseReg-HighCPU**: Triggers when CPU > 80% for 10 minutes
- **CourseReg-HighResponseTime**: Triggers when response time > 1s for 3 minutes
- **CourseReg-UnhealthyHosts**: Triggers when any target becomes unhealthy
- **CourseReg-High5xxErrors**: Triggers when 5xx errors > 10 per minute

## Run Stress Test

### Method 1: Integrated Monitoring (Single Terminal)
```powershell
.\infrastructure\run-stress-test-monitored.ps1 -Users 200 -SpawnRate 20 -RunTime "10m"
```

### Method 2: Separate Terminals (Best visibility)

**Terminal 1 - Real-time Monitoring:**
```powershell
.\infrastructure\monitor-realtime.ps1
```

**Terminal 2 - Run Load Test:**
```powershell
# Start with baseline test
.\infrastructure\run-stress-test.ps1 -Users 50 -SpawnRate 10 -RunTime "5m"

# Then scale up to trigger Auto Scaling
.\infrastructure\run-stress-test.ps1 -Users 300 -SpawnRate 30 -RunTime "10m"
```

## What to Watch For

### 1. Initial Baseline (50 users)
- Response time: Should be < 500ms
- CPU: Should be < 40%
- Error rate: Should be 0%
- Targets: 2 healthy

### 2. Scale Trigger (200-300 users)
- CPU: Will rise above 70%
- ASG: Watch for "[*] Scaling activity in progress!"
- Response time: May increase to 800-1000ms
- After 2-3 minutes: New instances should appear
- Targets: Should increase to 3-4 healthy

### 3. Post-Scale Performance
- Response time: Should improve back to 400-600ms
- CPU: Should drop below 60%
- Load distribution: Requests spread across all targets
- Error rate: Should remain < 1%

## Locust Web UI (Optional)

If you want interactive control:

```powershell
cd loadtest
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
locust -f locustfile.py --host http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
```

Then open: http://localhost:8089

## Test Scenarios

### Scenario 1: Baseline Performance Test
```powershell
# 50 concurrent users, 5 minutes
.\infrastructure\run-stress-test.ps1 -Users 50 -SpawnRate 10 -RunTime "5m"
```
**Expected**: Stable performance, no scaling

### Scenario 2: Auto Scaling Test
```powershell
# 300 concurrent users, 15 minutes
.\infrastructure\run-stress-test.ps1 -Users 300 -SpawnRate 30 -RunTime "15m"
```
**Expected**: 
- CPU hits 70-80% within 2-3 minutes
- ASG scales from 2 to 4 instances
- Response time spikes then recovers
- New instances healthy in 3-4 minutes

### Scenario 3: Peak Load Test
```powershell
# 500 concurrent users, 10 minutes
.\infrastructure\run-stress-test.ps1 -Users 500 -SpawnRate 50 -RunTime "10m"
```
**Expected**:
- ASG scales to max (10 instances)
- Response time may reach 1-2s during scaling
- Some 4xx errors possible (enrollment conflicts)
- Should stabilize once all instances healthy

### Scenario 4: Sustained Load Test
```powershell
# 200 users, 30 minutes
.\infrastructure\run-stress-test.ps1 -Users 200 -SpawnRate 20 -RunTime "30m"
```
**Expected**:
- Test sustained performance over time
- Watch for memory leaks or degradation
- Verify ASG maintains stable instance count

## Troubleshooting

### High Error Rate (>5%)
- Check target health in monitor
- Look for 5xx errors in CloudWatch
- Verify DynamoDB capacity not throttled

### Slow Response Time (>2s)
- Check EC2 CPU utilization
- Verify all targets are healthy
- Check DynamoDB consumed capacity

### Scaling Not Triggering
- Verify ASG scaling policy is active
- Check CloudWatch CPU metrics (delayed ~2 min)
- May need more users to reach 70% CPU

### Instances Unhealthy
- Check health check endpoint: http://ALB/health
- Verify security group allows ALB health checks
- Check EC2 instance logs

## Clean Up After Testing

### Scale Down to Save Costs
```powershell
# Reduce to 1 instance
aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name course-reg-asg `
    --min-size 1 --max-size 10 --desired-capacity 1

# Or stop completely (minimum cost)
.\infrastructure\quick-stop.ps1
```

### Delete Monitoring Resources (Optional)
```powershell
# Delete dashboard
aws cloudwatch delete-dashboards --dashboard-names CourseReg-LoadTest-Dashboard

# Delete alarms
aws cloudwatch delete-alarms --alarm-names `
    CourseReg-HighCPU `
    CourseReg-HighResponseTime `
    CourseReg-UnhealthyHosts `
    CourseReg-High5xxErrors
```

## Current Infrastructure

- **ALB**: course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
- **ASG**: course-reg-asg (Min: 2, Max: 10, Target CPU: 70%)
- **Running Instances**: 2 (i-023e4035ca8f2b4bc, i-0edb3c9260934cd2e)
- **DynamoDB**: CourseReg_Users, CourseReg_Courses, CourseReg_Enrollments
- **Region**: us-east-1

## Next Steps

1. **Run baseline test** to establish normal performance metrics
2. **Run scale test** to verify Auto Scaling works correctly
3. **Document results** - response times, CPU, scaling behavior
4. **Optimize if needed** - adjust scaling thresholds, instance types, etc.

Happy Testing! 🚀
