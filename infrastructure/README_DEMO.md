# 🚀 Auto-Scaling & Load Balancing Demo - Quick Reference

## ✅ Setup Complete!

Bạn đã có **complete test suite** để demo auto-scaling và load balancing.

---

## 🎯 Demo Nhanh (30 giây)

```powershell
cd d:\AWS_LB_ASG\infrastructure
.\demo-launcher.ps1
```

Chọn option 1 → Automatic demo sẽ chạy!

---

## 📁 Files Đã Tạo

### **PowerShell Scripts**
| File | Mục đích | Khi nào dùng |
|------|----------|--------------|
| `demo-launcher.ps1` | **START HERE** - Menu chọn demo | Luôn luôn dùng đầu tiên |
| `trigger-autoscaling.ps1` | Tạo load để trigger scaling | Demo auto-scaling |
| `monitor-autoscaling.ps1` | Monitor real-time ASG activity | Xem scaling diễn ra |
| `demo-test.ps1` | Quick API tests | Test endpoints |

### **Python Scripts**
| File | Mục đích | Khi nào dùng |
|------|----------|--------------|
| `locustfile-autoscaling.py` | Advanced load testing với Web UI | Demo chi tiết hơn |

### **Documentation**
| File | Nội dung |
|------|----------|
| `DEMO_AUTOSCALING_GUIDE.md` | Complete guide với timeline và talking points |

### **Web Demo**
| File | Mục đích |
|------|----------|
| `../demo/index.html` | Interactive demo page với UI đẹp |

---

## 🎬 3 Cách Demo

### **1. Quick Demo (5 phút) - Recommended cho presentation**

```powershell
cd d:\AWS_LB_ASG\infrastructure
.\demo-launcher.ps1
# Chọn [1] PowerShell Load Test
```

**Kết quả:**
- Monitor window tự động mở
- Load test chạy 5 phút
- Sẽ thấy scaling từ 1 → 2-3 instances

**Talking Points:**
1. "Bắt đầu với 1 instance"
2. "Load tăng → CPU > 70%"
3. "Auto-scaling trigger → Launch instance mới"
4. "Load được distribute đều"

---

### **2. Full Demo (10-15 phút) - Cho demo chi tiết**

**Terminal 1 - Monitor:**
```powershell
cd d:\AWS_LB_ASG\infrastructure
.\monitor-autoscaling.ps1 -RefreshSeconds 10 -DurationMinutes 15
```

**Terminal 2 - Locust:**
```powershell
cd d:\AWS_LB_ASG
locust -f infrastructure/locustfile-autoscaling.py --host=http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
```

**Browser:** http://localhost:8089
- Users: 300
- Spawn rate: 20
- Duration: 10 minutes

**Kết quả:**
- Real-time graphs
- Detailed metrics
- Clear scaling timeline

---

### **3. Web Demo (Interactive) - Cho client demo**

```powershell
Start-Process "d:\AWS_LB_ASG\demo\index.html"
```

**Features:**
- Click buttons để test endpoints
- Tự động show metrics
- Professional UI
- No technical knowledge required

---

## 📊 Expected Results

### **Metrics You'll See:**

| Metric | Initial | During Load | After Scale |
|--------|---------|-------------|-------------|
| Instances | 1 | 1→2 (pending) | 2-3 (running) |
| CPU | 5-10% | 75-90% | 40-50% |
| RPS | ~50 | 2000+ | 1500+ |
| Response Time | 300ms | 800ms | 350ms |

### **Timeline:**
- **T+0**: Start test, 1 instance
- **T+1-2**: CPU/Requests exceed threshold
- **T+3**: Scaling decision made
- **T+4**: New instance launching (pending)
- **T+5-6**: New instance healthy
- **T+7+**: Stable with multiple instances

---

## 🎓 Key Demo Points

### **1. Problem Statement**
"Hệ thống cần handle traffic không đều - giờ rush vs giờ thấp điểm"

### **2. Solution**
"Auto-Scaling: Tự động scale up/down dựa trên CPU và request count"

### **3. Benefits**
- ✅ **Performance**: Maintained under high load
- ✅ **Availability**: No downtime during scaling
- ✅ **Cost**: Pay only for what you use
- ✅ **Automatic**: No manual intervention

### **4. Evidence** (Show monitor terminal)
- CPU threshold exceeded → Scaling triggered
- New instance launched automatically
- Load balanced across all instances
- Response time recovered

---

## 🔧 Scaling Configuration

### **Current Setup:**
```
Min: 1 instance
Max: 4 instances
Desired: 1 instance (auto-adjusted)

Scaling Policies:
1. CPU-based: Scale when CPU > 70%
2. Request-based: Scale when > 1000 req/target/min
```

### **How It Works:**
```
High Load → Metrics Exceeded → CloudWatch Alarm → 
Auto-Scaling Policy → Launch New Instance → 
Register with ALB → Health Check → Receive Traffic
```

---

## 🐛 Troubleshooting

### **Not Scaling?**

1. **Check current load:**
   ```powershell
   aws cloudwatch get-metric-statistics `
     --namespace AWS/EC2 `
     --metric-name CPUUtilization `
     --dimensions Name=AutoScalingGroupName,Value=course-reg-asg `
     --start-time (Get-Date).AddMinutes(-5).ToString("yyyy-MM-ddTHH:mm:ss") `
     --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
     --period 60 --statistics Average --region us-east-1
   ```

2. **Increase load:**
   ```powershell
   .\trigger-autoscaling.ps1 -ConcurrentUsers 300 -DurationMinutes 10
   ```

3. **Manual scale (for testing):**
   ```powershell
   aws autoscaling set-desired-capacity `
     --auto-scaling-group-name course-reg-asg `
     --desired-capacity 2 --region us-east-1
   ```

### **Instances Not Healthy?**

```powershell
# Check target health
aws elbv2 describe-target-health `
  --target-group-arn (aws elbv2 describe-target-groups --names course-reg-tg --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1) `
  --region us-east-1
```

---

## 📈 Advanced: Load Distribution Demo

### **Show How ALB Distributes Load:**

**While load test is running:**

```powershell
# Watch requests being distributed
while ($true) {
    Write-Host "`nTarget Health & Connections:" -ForegroundColor Cyan
    aws elbv2 describe-target-health `
      --target-group-arn (aws elbv2 describe-target-groups --names course-reg-tg --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1) `
      --region us-east-1 `
      --query "TargetHealthDescriptions[].[Target.Id,TargetHealth.State]" `
      --output table
    Start-Sleep -Seconds 5
}
```

**Talking Point:**
"ALB automatically distributes requests evenly - round-robin algorithm"

---

## 💰 Cost Analysis During Demo

**Show real costs:**

```
During Demo (10 minutes):
- 1 instance: $0.01 (normal)
- +2 instances: $0.02 (scaled up)
- Total: $0.03 for 10 min demo

Production scenario:
- Rush hour (2 hrs/day): 4 instances
- Normal hours: 1 instance
- Savings: ~60% vs always running 4 instances
```

---

## 🧹 Cleanup After Demo

```powershell
# Scale back to 1
aws autoscaling set-desired-capacity `
  --auto-scaling-group-name course-reg-asg `
  --desired-capacity 1 `
  --region us-east-1

# Wait 2 minutes for termination

# Verify
aws ec2 describe-instances `
  --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running" `
  --region us-east-1 `
  --query "Reservations[].Instances[].InstanceId"
```

---

## ✨ Pro Tips

1. **Pre-test** trước khi demo thật:
   ```powershell
   .\demo-launcher.ps1
   # Chọn [1], wait 5 min, verify scaling works
   ```

2. **Have backup plan**: Nếu scaling chậm, manual trigger:
   ```powershell
   aws autoscaling set-desired-capacity --auto-scaling-group-name course-reg-asg --desired-capacity 2 --region us-east-1
   ```

3. **Open multiple terminals** sẵn với commands ready

4. **Screenshot evidence**:
   - Before: 1 instance
   - During: Scaling activity
   - After: Multiple instances healthy

---

## 📞 Quick Reference Commands

### **Check Status:**
```powershell
# Instances
aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running" --region us-east-1 --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table

# Target Health
aws elbv2 describe-target-health --target-group-arn (aws elbv2 describe-target-groups --names course-reg-tg --query "TargetGroups[0].TargetGroupArn" --output text --region us-east-1) --region us-east-1 --query "TargetHealthDescriptions[].[Target.Id,TargetHealth.State]" --output table

# Scaling Activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name course-reg-asg --max-records 3 --region us-east-1 --query "Activities[].[StartTime,StatusCode,Description]" --output table
```

---

## 🎉 Ready to Demo!

**Checklist:**
- ✅ All scripts created
- ✅ Infrastructure verified (1 instance healthy)
- ✅ Endpoints responsive
- ✅ Commands tested
- ✅ Documentation ready

**To start:**
```powershell
cd d:\AWS_LB_ASG\infrastructure
.\demo-launcher.ps1
```

**Good luck with your demo! 🚀**
