# ALB Demo Script
$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"
$ASG_NAME = "course-reg-asg"

Write-Host "`n=== AWS ALB Feature Demo ===" -ForegroundColor Cyan
Write-Host ""

# 1. Target Health
Write-Host "1. Target Health Status" -ForegroundColor Yellow
aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table

# 2. Health Check Config
Write-Host "`n2. Health Check Configuration" -ForegroundColor Yellow
aws elbv2 describe-target-groups --target-group-arns $TG_ARN --query 'TargetGroups[0].{Path:HealthCheckPath,Interval:HealthCheckIntervalSeconds,Timeout:HealthCheckTimeoutSeconds}' --output table

# 3. Load Distribution
Write-Host "`n3. Load Distribution Test (20 requests)" -ForegroundColor Yellow
$successCount = 0
$failCount = 0
$responseTimes = @()

for ($i = 1; $i -le 20; $i++) {
    $start = Get-Date
    try {
        $response = Invoke-RestMethod -Uri "$ALB_URL/health" -UseBasicParsing -TimeoutSec 5
        $duration = ((Get-Date) - $start).TotalMilliseconds
        $responseTimes += $duration
        $successCount++
        Write-Host "[OK] Request $i - ${duration}ms" -ForegroundColor Green
    } catch {
        $failCount++
        Write-Host "[FAIL] Request $i" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "`nResults:" -ForegroundColor Yellow
Write-Host "  Success: $successCount/20" -ForegroundColor Green
Write-Host "  Failed:  $failCount/20" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })

if ($responseTimes.Count -gt 0) {
    $avgTime = [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
    $minTime = [math]::Round(($responseTimes | Measure-Object -Minimum).Minimum, 2)
    $maxTime = [math]::Round(($responseTimes | Measure-Object -Maximum).Maximum, 2)
    Write-Host "  Avg Response: ${avgTime}ms" -ForegroundColor Cyan
    Write-Host "  Min/Max: ${minTime}ms / ${maxTime}ms" -ForegroundColor Cyan
}

# 4. Auto Scaling
Write-Host "`n4. Auto Scaling Integration" -ForegroundColor Yellow
$asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0]' | ConvertFrom-Json
Write-Host "  Min: $($asg.MinSize)  Max: $($asg.MaxSize)  Desired: $($asg.DesiredCapacity)  Current: $($asg.Instances.Count)" -ForegroundColor Cyan

Write-Host "`n  Instances:" -ForegroundColor Yellow
$asg.Instances | ForEach-Object {
    $color = if ($_.HealthStatus -eq "Healthy") { "Green" } else { "Red" }
    Write-Host "    $($_.InstanceId) - $($_.LifecycleState) / $($_.HealthStatus)" -ForegroundColor $color
}

# 5. CloudWatch Metrics
Write-Host "`n5. Recent Metrics (Last 10 min)" -ForegroundColor Yellow
$endTime = (Get-Date).ToUniversalTime()
$startTime = $endTime.AddMinutes(-10)

$reqCount = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") --period 600 --statistics Sum --query 'Datapoints[0].Sum' --output text

Write-Host "  Total Requests: " -NoNewline -ForegroundColor Gray
if ($reqCount -and $reqCount -ne "None") {
    Write-Host $reqCount -ForegroundColor Cyan
} else {
    Write-Host "N/A" -ForegroundColor Yellow
}

Write-Host "`n=== Demo Complete ===" -ForegroundColor Green
Write-Host "ALB URL: $ALB_URL" -ForegroundColor Cyan
Write-Host "API Docs: $ALB_URL/api/docs`n" -ForegroundColor Cyan
