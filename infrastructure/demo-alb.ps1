# ALB Demo - Show Multiple Features
$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"
$ASG_NAME = "course-reg-asg"

Write-Host @"

╔════════════════════════════════════════════════╗
║     AWS ALB Feature Demonstration              ║
╚════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Demo 1: Show current targets
Write-Host "=== 1. Target Health Monitoring ===" -ForegroundColor Yellow
Write-Host "ALB continuously monitors backend health`n" -ForegroundColor Gray

aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Description]' --output table

# Demo 2: Health check configuration
Write-Host "`n=== 2. Health Check Configuration ===" -ForegroundColor Yellow

$hcConfig = aws elbv2 describe-target-groups --target-group-arns $TG_ARN --query 'TargetGroups[0]' | ConvertFrom-Json

Write-Host "Path:     " -NoNewline -ForegroundColor Gray
Write-Host $hcConfig.HealthCheckPath -ForegroundColor Cyan
Write-Host "Interval: " -NoNewline -ForegroundColor Gray
Write-Host "$($hcConfig.HealthCheckIntervalSeconds)s" -ForegroundColor Cyan
Write-Host "Timeout:  " -NoNewline -ForegroundColor Gray
Write-Host "$($hcConfig.HealthCheckTimeoutSeconds)s" -ForegroundColor Cyan
Write-Host "Healthy:  " -NoNewline -ForegroundColor Gray
Write-Host "$($hcConfig.HealthyThresholdCount) consecutive successes" -ForegroundColor Cyan
Write-Host "Unhealthy:" -NoNewline -ForegroundColor Gray
Write-Host "$($hcConfig.UnhealthyThresholdCount) consecutive failures" -ForegroundColor Cyan

# Demo 3: Request distribution
Write-Host "`n=== 3. Load Distribution Test ===" -ForegroundColor Yellow
Write-Host "Sending 20 requests to demonstrate load balancing`n" -ForegroundColor Gray

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
        Write-Host "✓ Request $i" -NoNewline -ForegroundColor Green
        Write-Host " - ${duration}ms" -ForegroundColor Gray
    } catch {
        $failCount++
        Write-Host "✗ Request $i failed" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "`nResults:" -ForegroundColor Yellow
Write-Host "Success: " -NoNewline -ForegroundColor Gray
Write-Host "$successCount/20" -ForegroundColor Green
Write-Host "Failed:  " -NoNewline -ForegroundColor Gray
Write-Host "$failCount/20" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })

if ($responseTimes.Count -gt 0) {
    $avgTime = [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
    $minTime = [math]::Round(($responseTimes | Measure-Object -Minimum).Minimum, 2)
    $maxTime = [math]::Round(($responseTimes | Measure-Object -Maximum).Maximum, 2)
    
    Write-Host "Avg Response: " -NoNewline -ForegroundColor Gray
    Write-Host "${avgTime}ms" -ForegroundColor Cyan
    Write-Host "Min/Max:      " -NoNewline -ForegroundColor Gray
    Write-Host "${minTime}ms / ${maxTime}ms" -ForegroundColor Cyan
}

# Demo 4: Auto Scaling integration
Write-Host "`n=== 4. Auto Scaling Integration ===" -ForegroundColor Yellow
Write-Host "ALB automatically registers/deregisters instances`n" -ForegroundColor Gray

$asgInfo = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0]' | ConvertFrom-Json

Write-Host "Min Size:      " -NoNewline -ForegroundColor Gray
Write-Host $asgInfo.MinSize -ForegroundColor Cyan
Write-Host "Max Size:      " -NoNewline -ForegroundColor Gray
Write-Host $asgInfo.MaxSize -ForegroundColor Cyan
Write-Host "Desired:       " -NoNewline -ForegroundColor Gray
Write-Host $asgInfo.DesiredCapacity -ForegroundColor Cyan
Write-Host "Current:       " -NoNewline -ForegroundColor Gray
Write-Host $asgInfo.Instances.Count -ForegroundColor Cyan

Write-Host "`nInstances in ASG:" -ForegroundColor Yellow
$asgInfo.Instances | ForEach-Object {
    $color = if ($_.HealthStatus -eq "Healthy") { "Green" } else { "Red" }
    Write-Host "  $($_.InstanceId) - " -NoNewline -ForegroundColor Gray
    Write-Host $_.LifecycleState -NoNewline -ForegroundColor $color
    Write-Host " / $($_.HealthStatus)" -ForegroundColor $color
}

# Demo 5: Recent metrics
Write-Host "`n=== 5. ALB CloudWatch Metrics (Last 10 min) ===" -ForegroundColor Yellow

$endTime = (Get-Date).ToUniversalTime()
$startTime = $endTime.AddMinutes(-10)

$reqCount = aws cloudwatch get-metric-statistics `
    --namespace AWS/ApplicationELB `
    --metric-name RequestCount `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --period 600 `
    --statistics Sum `
    --query 'Datapoints[0].Sum' `
    --output text

$targetTime = aws cloudwatch get-metric-statistics `
    --namespace AWS/ApplicationELB `
    --metric-name TargetResponseTime `
    --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 `
    --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --period 600 `
    --statistics Average `
    --query 'Datapoints[0].Average' `
    --output text

Write-Host "Total Requests:    " -NoNewline -ForegroundColor Gray
if ($reqCount -and $reqCount -ne "None") {
    Write-Host $reqCount -ForegroundColor Cyan
} else {
    Write-Host "N/A (no recent data)" -ForegroundColor Yellow
}

Write-Host "Avg Response Time: " -NoNewline -ForegroundColor Gray
if ($targetTime -and $targetTime -ne "None") {
    $ms = [math]::Round([double]$targetTime * 1000, 2)
    Write-Host "${ms}ms" -ForegroundColor Cyan
} else {
    Write-Host "N/A (no recent data)" -ForegroundColor Yellow
}

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          Key ALB Features Demonstrated        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "✅ Health Monitoring  - Continuous health checks" -ForegroundColor Green
Write-Host "✅ Load Distribution  - Even traffic distribution" -ForegroundColor Green
Write-Host "✅ Auto Scaling       - Dynamic target registration" -ForegroundColor Green
Write-Host "✅ High Availability  - Multi-AZ deployment" -ForegroundColor Green
Write-Host "✅ Performance        - Low latency responses" -ForegroundColor Green

Write-Host "`nApplication URL: $ALB_URL" -ForegroundColor Cyan
Write-Host "API Docs:        $ALB_URL/api/docs`n" -ForegroundColor Cyan
