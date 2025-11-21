# Setup CloudWatch Dashboard and Alarms
$DASHBOARD_NAME = "CourseReg-LoadTest-Dashboard"
$REGION = "us-east-1"

Write-Host "`n=== Setting up CloudWatch Monitoring ===" -ForegroundColor Cyan

# 1. Create Dashboard
Write-Host "`n[1/3] Creating CloudWatch Dashboard..." -ForegroundColor Yellow
aws cloudwatch put-dashboard `
    --dashboard-name $DASHBOARD_NAME `
    --dashboard-body file://infrastructure/cloudwatch-dashboard.json `
    --region $REGION

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Dashboard created: $DASHBOARD_NAME" -ForegroundColor Green
    Write-Host "  View: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$DASHBOARD_NAME" -ForegroundColor Cyan
} else {
    Write-Host "[X] Dashboard creation failed" -ForegroundColor Red
}

# 2. Create SNS Topic for Alarms (optional)
Write-Host "`n[2/3] Setting up SNS for alarm notifications..." -ForegroundColor Yellow
$snsArn = aws sns list-topics --query "Topics[?contains(TopicArn, ``course-reg-alerts``)].TopicArn" --output text --region $REGION

if (!$snsArn) {
    Write-Host "Creating SNS topic..." -ForegroundColor Gray
    $snsArn = aws sns create-topic --name course-reg-alerts --region $REGION --query 'TopicArn' --output text
    Write-Host "[OK] SNS Topic created: $snsArn" -ForegroundColor Green
    
    $email = Read-Host "Enter email for alerts (or press Enter to skip)"
    if ($email) {
        aws sns subscribe --topic-arn $snsArn --protocol email --notification-endpoint $email --region $REGION
        Write-Host "[OK] Subscription request sent. Check your email to confirm." -ForegroundColor Green
    }
} else {
    Write-Host "[OK] SNS Topic already exists: $snsArn" -ForegroundColor Green
}

# 3. Create CloudWatch Alarms
Write-Host "`n[3/3] Creating CloudWatch Alarms..." -ForegroundColor Yellow

# High CPU Alarm
Write-Host "  Creating High CPU alarm..." -ForegroundColor Gray
aws cloudwatch put-metric-alarm `
    --alarm-name "CourseReg-HighCPU" `
    --alarm-description "Alert when CPU exceeds 80%" `
    --metric-name CPUUtilization `
    --namespace AWS/EC2 `
    --statistic Average `
    --period 300 `
    --threshold 80 `
    --comparison-operator GreaterThanThreshold `
    --evaluation-periods 2 `
    --dimensions Name=AutoScalingGroupName,Value=course-reg-asg `
    --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] High CPU alarm created" -ForegroundColor Green
}

# High Response Time Alarm
Write-Host "  Creating High Response Time alarm..." -ForegroundColor Gray
aws cloudwatch put-metric-alarm `
    --alarm-name "CourseReg-HighResponseTime" `
    --alarm-description "Alert when response time exceeds 1s" `
    --metric-name TargetResponseTime `
    --namespace AWS/ApplicationELB `
    --statistic Average `
    --period 60 `
    --threshold 1.0 `
    --comparison-operator GreaterThanThreshold `
    --evaluation-periods 3 `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] High Response Time alarm created" -ForegroundColor Green
}

# Unhealthy Hosts Alarm
Write-Host "  Creating Unhealthy Hosts alarm..." -ForegroundColor Gray
aws cloudwatch put-metric-alarm `
    --alarm-name "CourseReg-UnhealthyHosts" `
    --alarm-description "Alert when targets become unhealthy" `
    --metric-name UnHealthyHostCount `
    --namespace AWS/ApplicationELB `
    --statistic Average `
    --period 60 `
    --threshold 1 `
    --comparison-operator GreaterThanOrEqualToThreshold `
    --evaluation-periods 2 `
    --dimensions Name=TargetGroup,Value=targetgroup/course-reg-tg/e0dfed577c96c70c `
    --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Unhealthy Hosts alarm created" -ForegroundColor Green
}

# High 5xx Errors Alarm
Write-Host "  Creating High 5xx Errors alarm..." -ForegroundColor Gray
aws cloudwatch put-metric-alarm `
    --alarm-name "CourseReg-High5xxErrors" `
    --alarm-description "Alert on server errors" `
    --metric-name HTTPCode_Target_5XX_Count `
    --namespace AWS/ApplicationELB `
    --statistic Sum `
    --period 60 `
    --threshold 10 `
    --comparison-operator GreaterThanThreshold `
    --evaluation-periods 1 `
    --treat-missing-data notBreaching `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] High 5xx Errors alarm created" -ForegroundColor Green
}

Write-Host "`n" -ForegroundColor Green
Write-Host "          CloudWatch Setup Complete!                      " -ForegroundColor Green
Write-Host "`n" -ForegroundColor Green

Write-Host "View Dashboard:" -ForegroundColor Yellow
Write-Host "  https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$DASHBOARD_NAME" -ForegroundColor Cyan
Write-Host ""

Write-Host "View Alarms:" -ForegroundColor Yellow
Write-Host "  https://console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:" -ForegroundColor Cyan
Write-Host ""

Write-Host "To monitor during stress test:" -ForegroundColor Yellow
Write-Host "  .\infrastructure\monitor-realtime.ps1" -ForegroundColor Cyan
Write-Host "  OR open dashboard in browser" -ForegroundColor Cyan
Write-Host ""

