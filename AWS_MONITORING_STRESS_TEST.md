# 📊 AWS Monitoring & Stress Testing Guide

## Course Registration System - Performance Testing & Monitoring

---

## 📋 Table of Contents

1. [CloudWatch Monitoring](#cloudwatch-monitoring)
2. [Application Load Balancer Metrics](#alb-metrics)
3. [Auto Scaling Monitoring](#auto-scaling-monitoring)
4. [DynamoDB Monitoring](#dynamodb-monitoring)
5. [Stress Testing với AWS](#stress-testing)
6. [Performance Optimization](#performance-optimization)

---

## 🔍 CloudWatch Monitoring

### 1. **Setup CloudWatch Dashboard**

```bash
# Tạo CloudWatch Dashboard
aws cloudwatch put-dashboard --dashboard-name CourseRegistrationDashboard --dashboard-body file://dashboard.json
```

**dashboard.json:**
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", {"stat": "Average"}],
          [".", "RequestCount", {"stat": "Sum"}],
          [".", "HTTPCode_Target_2XX_Count", {"stat": "Sum"}],
          [".", "HTTPCode_Target_4XX_Count", {"stat": "Sum"}],
          [".", "HTTPCode_Target_5XX_Count", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ALB Metrics"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", {"stat": "Average"}],
          [".", "NetworkIn", {"stat": "Sum"}],
          [".", "NetworkOut", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "EC2 Instances"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/DynamoDB", "ConsumedReadCapacityUnits", {"stat": "Sum"}],
          [".", "ConsumedWriteCapacityUnits", {"stat": "Sum"}],
          [".", "UserErrors", {"stat": "Sum"}],
          [".", "SystemErrors", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "us-east-1",
        "title": "DynamoDB Performance"
      }
    }
  ]
}
```

### 2. **CloudWatch Logs Insights Queries**

```sql
-- Query 1: Top 10 slowest API endpoints
fields @timestamp, @message
| filter @message like /Duration:/
| parse @message /Duration: (?<duration>[0-9.]+)/
| sort duration desc
| limit 10

-- Query 2: Error rate by endpoint
fields @timestamp, endpoint, status
| filter status >= 400
| stats count() by endpoint
| sort count desc

-- Query 3: Request rate per minute
fields @timestamp
| stats count() as requests by bin(5m)

-- Query 4: Average response time
fields @timestamp, duration
| filter duration > 0
| stats avg(duration) as avg_duration, max(duration) as max_duration, min(duration) as min_duration
```

### 3. **CloudWatch Alarms**

```bash
# High CPU Alert
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu-utilization \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts

# High Response Time Alert
aws cloudwatch put-metric-alarm \
  --alarm-name high-response-time \
  --alarm-description "Alert when response time > 2s" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 2.0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts

# DynamoDB Throttling Alert
aws cloudwatch put-metric-alarm \
  --alarm-name dynamodb-throttled-requests \
  --alarm-description "Alert on DynamoDB throttling" \
  --metric-name UserErrors \
  --namespace AWS/DynamoDB \
  --statistic Sum \
  --period 60 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts

# Auto Scaling Group Unhealthy Instances
aws cloudwatch put-metric-alarm \
  --alarm-name asg-unhealthy-instances \
  --alarm-description "Alert when instances become unhealthy" \
  --metric-name UnhealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts
```

---

## 🎯 Application Load Balancer Metrics

### **Key Metrics to Monitor:**

1. **Request Count** - Tổng số requests
2. **Target Response Time** - Thời gian phản hồi
3. **HTTP 2xx/4xx/5xx Codes** - Status codes
4. **Active Connection Count** - Số connections đang active
5. **Healthy/Unhealthy Host Count** - Trạng thái instances

### **View ALB Metrics:**

```bash
# Get ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/course-reg-alb/xxxxx \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 3600 \
  --statistics Sum

# Get response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/course-reg-alb/xxxxx \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 300 \
  --statistics Average,Maximum
```

---

## 📈 Auto Scaling Monitoring

### **Auto Scaling Metrics:**

```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name course-reg-asg \
  --max-records 20

# View current capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names course-reg-asg \
  --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize,Instances[*].InstanceId]'

# View scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name course-reg-asg
```

### **Custom Scaling Metrics:**

```python
# backend/app/monitoring.py
import boto3
from datetime import datetime

cloudwatch = boto3.client('cloudwatch', region_name='us-east-1')

def put_custom_metric(metric_name, value, unit='Count'):
    """Send custom metric to CloudWatch"""
    cloudwatch.put_metric_data(
        Namespace='CourseRegistration',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow()
            }
        ]
    )

# Usage examples
put_custom_metric('EnrollmentRequests', 1, 'Count')
put_custom_metric('ActiveUsers', 150, 'Count')
put_custom_metric('DatabaseQueries', 1, 'Count')
put_custom_metric('CacheHits', 1, 'Count')
put_custom_metric('CacheMisses', 1, 'Count')
```

---

## 💾 DynamoDB Monitoring

### **Key DynamoDB Metrics:**

```bash
# Read/Write Capacity
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=CourseReg_Courses \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 300 \
  --statistics Sum,Average

# Throttled Requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=CourseReg_Users \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 300 \
  --statistics Sum

# Query Latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name SuccessfulRequestLatency \
  --dimensions Name=TableName,Value=CourseReg_Enrollments Name=Operation,Value=Query \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 60 \
  --statistics Average,Maximum
```

---

## 🔥 Stress Testing với AWS

### **Option 1: AWS Distributed Load Testing Solution**

```bash
# Deploy Distributed Load Testing Stack
aws cloudformation create-stack \
  --stack-name distributed-load-testing \
  --template-url https://s3.amazonaws.com/solutions-reference/distributed-load-testing/latest/distributed-load-testing.template \
  --capabilities CAPABILITY_IAM

# Sau khi deploy xong, truy cập CloudFront URL để tạo test
```

**Test Scenario JSON:**
```json
{
  "testName": "Course Registration Load Test",
  "testDescription": "Test enrollment peak load",
  "taskCount": 10,
  "testScenario": {
    "execution": [
      {
        "concurrency": 100,
        "ramp-up": "1m",
        "hold-for": "5m",
        "scenario": "course-enrollment"
      }
    ],
    "scenarios": {
      "course-enrollment": {
        "requests": [
          {
            "url": "https://your-alb-url.com/api/auth/login",
            "method": "POST",
            "headers": {
              "Content-Type": "application/json"
            },
            "body": "{\"username\":\"student1\",\"password\":\"student123\"}"
          },
          {
            "url": "https://your-alb-url.com/api/courses",
            "method": "GET",
            "headers": {
              "Authorization": "Bearer ${access_token}"
            }
          },
          {
            "url": "https://your-alb-url.com/api/enrollments",
            "method": "POST",
            "headers": {
              "Content-Type": "application/json",
              "Authorization": "Bearer ${access_token}"
            },
            "body": "{\"course_id\":\"${course_id}\"}"
          }
        ]
      }
    }
  }
}
```

### **Option 2: Apache JMeter (Chạy trên EC2)**

**Setup JMeter trên EC2:**

```bash
# Launch EC2 instance cho JMeter
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.large \
  --key-name your-key \
  --security-group-ids sg-xxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=JMeter-LoadTest}]'

# SSH vào instance
ssh -i your-key.pem ec2-user@<instance-ip>

# Install JMeter
sudo yum update -y
sudo yum install java-11-amazon-corretto -y
wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.2.tgz
tar -xzf apache-jmeter-5.6.2.tgz
cd apache-jmeter-5.6.2/bin
```

**JMeter Test Plan (course-reg-test.jmx):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Course Registration Test">
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">https://your-alb-url.com</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Users">
        <stringProp name="ThreadGroup.num_threads">100</stringProp>
        <stringProp name="ThreadGroup.ramp_time">60</stringProp>
        <stringProp name="ThreadGroup.duration">300</stringProp>
      </ThreadGroup>
      
      <hashTree>
        <!-- Login Request -->
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Login">
          <stringProp name="HTTPSampler.domain">${BASE_URL}</stringProp>
          <stringProp name="HTTPSampler.path">/api/auth/login</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <stringProp name="HTTPSampler.postBodyRaw">{"username":"student1","password":"student123"}</stringProp>
        </HTTPSamplerProxy>
        
        <!-- Get Courses -->
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Get Courses">
          <stringProp name="HTTPSampler.domain">${BASE_URL}</stringProp>
          <stringProp name="HTTPSampler.path">/api/courses</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
        </HTTPSamplerProxy>
        
        <!-- Enroll Course -->
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Enroll">
          <stringProp name="HTTPSampler.domain">${BASE_URL}</stringProp>
          <stringProp name="HTTPSampler.path">/api/enrollments</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <stringProp name="HTTPSampler.postBodyRaw">{"course_id":"xxx"}</stringProp>
        </HTTPSamplerProxy>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

**Run JMeter Test:**

```bash
# Non-GUI mode (recommended for load testing)
./jmeter -n -t course-reg-test.jmx -l results.jtl -e -o report

# View results
cd report && python3 -m http.server 8080
```

### **Option 3: Locust (Python-based)**

**Install Locust:**

```bash
pip install locust
```

**locustfile.py:**

```python
from locust import HttpUser, task, between
import random

class CourseRegistrationUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        """Login when user starts"""
        response = self.client.post("/api/auth/login", json={
            "username": f"student{random.randint(1, 100)}",
            "password": "student123"
        })
        if response.status_code == 200:
            data = response.json()
            self.token = data.get("access_token")
            self.headers = {"Authorization": f"Bearer {self.token}"}
        else:
            self.token = None
            self.headers = {}
    
    @task(3)
    def view_courses(self):
        """View all courses (frequent action)"""
        self.client.get("/api/courses", headers=self.headers)
    
    @task(2)
    def view_my_courses(self):
        """View my enrollments"""
        self.client.get("/api/enrollments/my-enrollments", headers=self.headers)
    
    @task(1)
    def enroll_course(self):
        """Enroll in a course (less frequent)"""
        # Get courses first
        response = self.client.get("/api/courses", headers=self.headers)
        if response.status_code == 200:
            courses = response.json()
            if courses:
                course = random.choice(courses)
                self.client.post("/api/enrollments", 
                    json={"course_id": course["course_id"]},
                    headers=self.headers
                )
    
    @task(1)
    def view_dashboard(self):
        """View user dashboard"""
        self.client.get("/api/auth/me", headers=self.headers)
```

**Run Locust:**

```bash
# Web UI mode
locust -f locustfile.py --host https://your-alb-url.com

# Headless mode (CLI)
locust -f locustfile.py --host https://your-alb-url.com \
  --users 500 --spawn-rate 10 --run-time 10m --headless
```

### **Option 4: AWS CLI Script**

**Simple bash script for quick testing:**

```bash
#!/bin/bash
# stress-test.sh

ALB_URL="https://your-alb-url.com"
CONCURRENT_REQUESTS=100
DURATION=300  # seconds

echo "Starting stress test..."
echo "Target: $ALB_URL"
echo "Concurrent requests: $CONCURRENT_REQUESTS"
echo "Duration: $DURATION seconds"

# Function to make requests
make_requests() {
  local count=0
  local end_time=$((SECONDS + DURATION))
  
  while [ $SECONDS -lt $end_time ]; do
    # Login
    TOKEN=$(curl -s -X POST "$ALB_URL/api/auth/login" \
      -H "Content-Type: application/json" \
      -d '{"username":"student1","password":"student123"}' \
      | jq -r '.access_token')
    
    # Get courses
    curl -s "$ALB_URL/api/courses" \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    # Get enrollments
    curl -s "$ALB_URL/api/enrollments/my-enrollments" \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    count=$((count + 1))
    echo "Thread $1: Request $count"
    
    sleep 0.1
  done
}

# Run concurrent threads
for i in $(seq 1 $CONCURRENT_REQUESTS); do
  make_requests $i &
done

wait
echo "Stress test completed!"
```

**Run script:**

```bash
chmod +x stress-test.sh
./stress-test.sh
```

---

## 📊 Performance Optimization Tips

### 1. **DynamoDB Optimization**

```python
# Enable Auto Scaling for DynamoDB
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id table/CourseReg_Courses \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --min-capacity 5 \
  --max-capacity 100

aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id table/CourseReg_Courses \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --policy-name CourseReadScaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

**scaling-policy.json:**
```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "DynamoDBReadCapacityUtilization"
  }
}
```

### 2. **Enable CloudFront CDN**

```bash
# Create CloudFront distribution for frontend
aws cloudfront create-distribution --distribution-config file://cf-config.json
```

### 3. **ElastiCache Redis Monitoring**

```bash
# Monitor Redis cache hit rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CacheHitRate \
  --dimensions Name=CacheClusterId,Value=course-reg-redis \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 300 \
  --statistics Average
```

---

## 📝 Monitoring Checklist

- [ ] CloudWatch Dashboard configured
- [ ] CloudWatch Alarms set up
- [ ] CloudWatch Logs Insights queries saved
- [ ] ALB access logs enabled
- [ ] DynamoDB metrics monitored
- [ ] Auto Scaling policies tested
- [ ] SNS notifications configured
- [ ] Stress test completed successfully
- [ ] Performance baseline established
- [ ] Scaling thresholds optimized

---

## 🎯 Expected Performance Metrics

**Target Metrics:**
- Response Time: < 200ms (p50), < 500ms (p99)
- Availability: > 99.9%
- Error Rate: < 0.1%
- Throughput: > 1000 requests/second
- Auto Scaling: < 2 minutes to scale up

**During Stress Test:**
- Monitor CPU: Should stay < 80%
- Monitor Memory: Should stay < 85%
- Monitor Network: No packet loss
- Monitor Database: No throttling
- Monitor Auto Scaling: Should trigger at 70% CPU

---

## 📞 Resources

- **AWS CloudWatch**: https://console.aws.amazon.com/cloudwatch
- **AWS X-Ray**: https://console.aws.amazon.com/xray
- **JMeter**: https://jmeter.apache.org
- **Locust**: https://locust.io
- **AWS Load Testing**: https://aws.amazon.com/solutions/implementations/distributed-load-testing-on-aws/

---

**Status:** ✅ Ready for Load Testing!
