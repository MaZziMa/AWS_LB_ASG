# Auto-Scaling & Load Balancing Demo Guide

## 🎯 Mục Tiêu
Trigger AWS Auto-Scaling để scale từ 1 → 4 instances thông qua:
1. **CPU-based scaling**: CPU > 70%
2. **Request-based scaling**: Requests > 1000 per target per minute

---

## 📋 Prerequisites

```powershell
# Check current setup
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names course-reg-asg --region us-east-1
```

---

## 🚀 Quick Start Demo

### **Option 1: PowerShell Load Test (Recommended)**

**Terminal 1 - Monitor (Start First):**
```powershell
cd d:\AWS_LB_ASG\infrastructure
.\monitor-autoscaling.ps1 -RefreshSeconds 10 -DurationMinutes 10
```

**Terminal 2 - Load Generator:**
```powershell
cd d:\AWS_LB_ASG\infrastructure
.\trigger-autoscaling.ps1 -DurationMinutes 5 -ConcurrentUsers 200
```

**Expected Result:**
- Initial: 1 instance
- After 2-3 minutes: 2-3 instances (scaling up)
- Peak load: Up to 4 instances

---

### **Option 2: Locust Load Test (More Powerful)**

**Terminal 1 - Monitor:**
```powershell
cd d:\AWS_LB_ASG\infrastructure
.\monitor-autoscaling.ps1
```

**Terminal 2 - Start Locust:**
```powershell
cd d:\AWS_LB_ASG
locust -f infrastructure/locustfile-autoscaling.py --host=http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
```

**Then open browser:** http://localhost:8089

**Configuration for Auto-Scaling:**
- Number of users: **300-500**
- Spawn rate: **20**
- Duration: **10 minutes**

**Expected Timeline:**
- 0-1 min: Load building up
- 1-3 min: CPU/Requests exceed threshold
- 3-5 min: New instance(s) launching (pending state)
- 5-7 min: New instances healthy, load distributed
- 7+ min: System stable with multiple instances

---

## 📊 What to Watch

### **Monitor Terminal Will Show:**

1. **Instance Count Changes:**
   ```
   Running instances: 1
   ↓
   Pending instances: 1 (LAUNCHING!)
   ↓
   Running instances: 2
   ```

2. **Target Health:**
   ```
   Healthy targets: 1/1
   ↓
   Healthy targets: 1/2 (initializing)
   ↓
   Healthy targets: 2/2
   ```

3. **Metrics:**
   ```
   CPU Utilization: 75% ⚠️ WARNING: Above 70%!
   Request Count: 2500
   Requests per target: 1250 ⚠️ Above threshold!
   ```

4. **Scaling Activities:**
   ```
   [14:23:15] InProgress - Launching a new EC2 instance
   [14:25:30] Successful - Successfully launched instance i-xxx
   ```

---

## 🎓 Demo Talking Points

### **1. Initial State (Before Load)**
```powershell
# Show current setup
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names course-reg-asg `
  --region us-east-1 `
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]"
```
**Say:** "Bắt đầu với 1 instance, có thể scale lên tối đa 4 instances"

### **2. During Load Test**
**Point to monitor terminal:**
- "CPU đang tăng lên 75%, vượt threshold 70%"
- "Requests per target đạt 1250, vượt threshold 1000"
- "Auto-Scaling đã trigger, đang launch instance mới"

### **3. Load Distribution**
```powershell
# Show target health in real-time
aws elbv2 describe-target-health `
  --target-group-arn (aws elbv2 describe-target-groups --names course-reg-tg --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1) `
  --region us-east-1
```
**Say:** "ALB tự động phân phối load đều giữa các instances"

### **4. Performance Under Scale**
**Show Locust UI:** http://localhost:8089
- Response time giảm khi có thêm instances
- Error rate thấp (~0%)
- Throughput tăng

### **5. Cost & Efficiency**
**Say:** 
- "Scale up: Khi traffic cao (giờ rush đăng ký)"
- "Scale down: Tự động giảm khi traffic thấp (tiết kiệm chi phí)"
- "Pay per use: Chỉ trả tiền khi cần"

---

## 🔍 Verify Auto-Scaling

### **Check Scaling Activities:**
```powershell
aws autoscaling describe-scaling-activities `
  --auto-scaling-group-name course-reg-asg `
  --max-records 5 `
  --region us-east-1 `
  --query "Activities[].[StartTime,StatusCode,Description]" `
  --output table
```

### **View CloudWatch Alarms:**
```powershell
aws cloudwatch describe-alarms `
  --alarm-name-prefix course-reg `
  --region us-east-1 `
  --query "MetricAlarms[].[AlarmName,StateValue,Threshold]" `
  --output table
```

### **Check EC2 Instances:**
```powershell
aws ec2 describe-instances `
  --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running" `
  --region us-east-1 `
  --query "Reservations[].Instances[].[InstanceId,LaunchTime,State.Name]" `
  --output table
```

---

## 💡 Troubleshooting

### **Auto-Scaling Not Triggering?**

1. **Increase load intensity:**
   ```powershell
   .\trigger-autoscaling.ps1 -ConcurrentUsers 300 -DurationMinutes 10
   ```

2. **Lower scaling threshold (for demo only):**
   ```powershell
   aws autoscaling put-scaling-policy `
     --auto-scaling-group-name course-reg-asg `
     --policy-name cpu-target-tracking-low `
     --policy-type TargetTrackingScaling `
     --target-tracking-configuration '{
       "PredefinedMetricSpecification": {
         "PredefinedMetricType": "ASGAverageCPUUtilization"
       },
       "TargetValue": 40.0
     }' `
     --region us-east-1
   ```

3. **Manually trigger scale (for testing):**
   ```powershell
   aws autoscaling set-desired-capacity `
     --auto-scaling-group-name course-reg-asg `
     --desired-capacity 2 `
     --region us-east-1
   ```

### **Not Enough Load?**

Use Locust with higher settings:
- Users: **500+**
- Spawn rate: **50**
- Focus on CPU-intensive endpoints

---

## 🎬 Full Demo Script

### **Preparation (Before Audience):**
```powershell
# 1. Ensure 1 instance running
aws autoscaling set-desired-capacity `
  --auto-scaling-group-name course-reg-asg `
  --desired-capacity 1 `
  --region us-east-1

# 2. Wait 2 minutes for stabilization

# 3. Test endpoint
curl http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health
```

### **Live Demo:**

1. **Show architecture** (2 min)
   - Open `demo/index.html`
   - Explain: ALB → ASG → Targets

2. **Start monitor** (1 min)
   ```powershell
   .\monitor-autoscaling.ps1
   ```
   - Show: 1 instance, healthy

3. **Start load test** (1 min)
   ```powershell
   .\trigger-autoscaling.ps1 -ConcurrentUsers 250 -DurationMinutes 7
   ```

4. **Watch scaling happen** (5 min)
   - Point out CPU metrics
   - Show pending instances
   - Explain ALB distributing load

5. **Show results** (2 min)
   - Multiple instances running
   - Healthy targets
   - Performance maintained

**Total: ~11 minutes**

---

## 📈 Expected Results

### **Metrics:**
- Initial RPS: ~100
- Peak RPS: ~2000-3000
- CPU: 70-90% (triggers scaling)
- Response time: <500ms maintained

### **Scaling Timeline:**
- T+0: Start load test, 1 instance
- T+2: CPU hits 70%, scaling decision
- T+3: New instance launching
- T+5: 2 instances healthy
- T+6: Load continues, might trigger 3rd
- T+8: Stable with 2-3 instances

### **Evidence of Success:**
✅ Instance count increased
✅ All targets healthy
✅ Response time stable
✅ Error rate minimal
✅ Scaling activities logged

---

## 🧹 Cleanup After Demo

```powershell
# Scale back to 1 instance
aws autoscaling set-desired-capacity `
  --auto-scaling-group-name course-reg-asg `
  --desired-capacity 1 `
  --region us-east-1

# Stop load test
# Press Ctrl+C in load test terminal

# Stop monitor
# Press Ctrl+C in monitor terminal
```

---

## 📚 Additional Resources

- **AWS Console**: EC2 → Auto Scaling Groups → course-reg-asg
- **CloudWatch Dashboard**: View metrics graphs
- **Scaling History**: ASG → Activity History tab

---

**Ready to demo? Start with Option 1 (PowerShell) - it's simpler and more controlled!**
