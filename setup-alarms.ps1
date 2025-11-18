# Setup CloudWatch Alarms for Course Registration System
# PowerShell script - Chạy: .\setup-alarms.ps1

Write-Host "=== Setting up CloudWatch Alarms ===" -ForegroundColor Cyan

# Lưu ý: Trước khi chạy, cần tạo SNS Topic và subscribe email
# Thay thế ARN dưới đây bằng ARN của SNS Topic của bạn
$SNS_TOPIC_ARN = "arn:aws:sns:us-east-1:171308902397:course-reg-alerts"

Write-Host "`n1. Creating High CPU Utilization Alarm..." -ForegroundColor Yellow
aws cloudwatch put-metric-alarm `
  --alarm-name high-cpu-utilization `
  --alarm-description "Alert when CPU exceeds 80%" `
  --metric-name CPUUtilization `
  --namespace AWS/EC2 `
  --statistic Average `
  --period 300 `
  --threshold 80 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 2 `
  --alarm-actions $SNS_TOPIC_ARN

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ High CPU alarm created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create High CPU alarm" -ForegroundColor Red
}

Write-Host "`n2. Creating High Response Time Alarm..." -ForegroundColor Yellow
aws cloudwatch put-metric-alarm `
  --alarm-name high-response-time `
  --alarm-description "Alert when response time > 2s" `
  --metric-name TargetResponseTime `
  --namespace AWS/ApplicationELB `
  --statistic Average `
  --period 60 `
  --threshold 2.0 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 3 `
  --alarm-actions $SNS_TOPIC_ARN

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ High Response Time alarm created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create High Response Time alarm" -ForegroundColor Red
}

Write-Host "`n3. Creating DynamoDB Throttling Alarm..." -ForegroundColor Yellow
aws cloudwatch put-metric-alarm `
  --alarm-name dynamodb-throttled-requests `
  --alarm-description "Alert on DynamoDB throttling" `
  --metric-name UserErrors `
  --namespace AWS/DynamoDB `
  --statistic Sum `
  --period 60 `
  --threshold 10 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 2 `
  --alarm-actions $SNS_TOPIC_ARN

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DynamoDB Throttling alarm created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create DynamoDB Throttling alarm" -ForegroundColor Red
}

Write-Host "`n4. Creating Unhealthy Instances Alarm..." -ForegroundColor Yellow
aws cloudwatch put-metric-alarm `
  --alarm-name asg-unhealthy-instances `
  --alarm-description "Alert when instances become unhealthy" `
  --metric-name UnhealthyHostCount `
  --namespace AWS/ApplicationELB `
  --statistic Average `
  --period 60 `
  --threshold 1 `
  --comparison-operator GreaterThanOrEqualToThreshold `
  --evaluation-periods 1 `
  --alarm-actions $SNS_TOPIC_ARN

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Unhealthy Instances alarm created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create Unhealthy Instances alarm" -ForegroundColor Red
}

Write-Host "`n=== Alarm Setup Complete ===" -ForegroundColor Cyan
Write-Host "`nTo verify alarms:" -ForegroundColor Yellow
Write-Host "aws cloudwatch describe-alarms" -ForegroundColor White
