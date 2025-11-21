# Quick CloudWatch Monitoring for Load Test
# Run this in a separate terminal while load test is running

$TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"
$ASG_NAME = "course-reg-asg"
$ALB_NAME = "app/course-reg-alb/7d13a6bcf5e0d9f7"

Write-Host "`n=== Real-time AWS Monitoring ===" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray

while ($true) {
    Clear-Host
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    Write-Host "" -ForegroundColor Cyan
    Write-Host "        AWS Monitoring Dashboard - $timestamp                " -ForegroundColor Cyan
    Write-Host "`n" -ForegroundColor Cyan
    
    # 1. Target Health
    Write-Host "[1] ALB Target Health:" -ForegroundColor Yellow
    $targets = aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output text
    $healthyCount = 0
    $unhealthyCount = 0
    
    if ($targets) {
        $targets -split "`n" | ForEach-Object {
            if ($_ -and $_.Trim()) {
                $parts = $_ -split "`t"
                if ($parts.Count -ge 2) {
                    $instanceId = $parts[0]
                    $state = $parts[1]
                    $reason = if ($parts.Count -ge 3) { $parts[2] } else { "" }
                    
                    if ($state -eq "healthy") {
                        $healthyCount++
                        Write-Host "  [OK] $instanceId - HEALTHY" -ForegroundColor Green
                    } else {
                        $unhealthyCount++
                        Write-Host "  [X] $instanceId - $state" -NoNewline -ForegroundColor Red
                        if ($reason) { Write-Host " ($reason)" -ForegroundColor Gray } else { Write-Host "" }
                    }
                }
            }
        }
    }
    
    Write-Host "  Total: $healthyCount healthy, $unhealthyCount unhealthy" -ForegroundColor Cyan
    
    # 2. Auto Scaling Status
    Write-Host "`n[2] Auto Scaling Group:" -ForegroundColor Yellow
    $asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0]' | ConvertFrom-Json
    Write-Host "  Min: $($asg.MinSize)  |  Max: $($asg.MaxSize)  |  Desired: $($asg.DesiredCapacity)  |  Running: $($asg.Instances.Count)" -ForegroundColor Cyan
    
    # Check for recent scaling activities
    $activities = aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME --max-records 1 --query 'Activities[0].[StartTime,Cause,StatusCode]' --output text 2>$null
    if ($activities) {
        $actParts = $activities -split "`t"
        if ($actParts[2] -eq "InProgress") {
            Write-Host "  [*] Scaling activity in progress!" -ForegroundColor Yellow
        }
    }
    
    # 3. ALB Metrics (Last 1 minute)
    $endTime = (Get-Date).ToUniversalTime()
    $startTime = $endTime.AddMinutes(-1)
    $startStr = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endStr = $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-Host "`n[3] Load Balancer Metrics (Last 60 seconds):" -ForegroundColor Yellow
    
    # Request count
    $reqCount = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    Write-Host "  Total Requests:  " -NoNewline -ForegroundColor Gray
    if ($reqCount -and $reqCount -ne "None") {
        $rps = [math]::Round([double]$reqCount / 60, 2)
        Write-Host "$reqCount ($rps requests per second)" -ForegroundColor Cyan
    } else {
        Write-Host "0" -ForegroundColor Gray
    }
    
    # Response time
    $respTime = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Average,Maximum --query 'Datapoints[0].[Average,Maximum]' --output text 2>$null
    Write-Host "  Response Time:   " -NoNewline -ForegroundColor Gray
    if ($respTime -and $respTime -ne "None") {
        $times = $respTime -split "`t"
        $avgMs = [math]::Round([double]$times[0] * 1000, 2)
        $maxMs = [math]::Round([double]$times[1] * 1000, 2)
        $color = if ($avgMs -gt 1000) { "Red" } elseif ($avgMs -gt 500) { "Yellow" } else { "Green" }
        Write-Host "Avg: ${avgMs}ms  Max: ${maxMs}ms" -ForegroundColor $color
    } else {
        Write-Host "N/A" -ForegroundColor Gray
    }
    
    # Success/Error rates
    $success2xx = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_2XX_Count --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    $error4xx = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_4XX_Count --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    $error5xx = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    
    $s2xx = if ($success2xx -and $success2xx -ne "None") { [int]$success2xx } else { 0 }
    $e4xx = if ($error4xx -and $error4xx -ne "None") { [int]$error4xx } else { 0 }
    $e5xx = if ($error5xx -and $error5xx -ne "None") { [int]$error5xx } else { 0 }
    
    $total = $s2xx + $e4xx + $e5xx
    $successRate = if ($total -gt 0) { [math]::Round(($s2xx / $total) * 100, 2) } else { 100 }
    
    Write-Host "  Status Codes:    " -NoNewline -ForegroundColor Gray
    Write-Host "2xx=$s2xx  " -NoNewline -ForegroundColor Green
    Write-Host "4xx=$e4xx  " -NoNewline -ForegroundColor $(if ($e4xx -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "5xx=$e5xx" -ForegroundColor $(if ($e5xx -gt 0) { "Red" } else { "Gray" })
    
    Write-Host "  Success Rate:    " -NoNewline -ForegroundColor Gray
    $rateColor = if ($successRate -ge 99) { "Green" } elseif ($successRate -ge 95) { "Yellow" } else { "Red" }
    Write-Host "$successRate%" -ForegroundColor $rateColor
    
    # 4. EC2 Metrics
    Write-Host "`n[4] EC2 Instance Metrics (Last 60 seconds):" -ForegroundColor Yellow
    
    # CPU
    $cpu = aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Average,Maximum --query 'Datapoints[0].[Average,Maximum]' --output text 2>$null
    Write-Host "  CPU Utilization: " -NoNewline -ForegroundColor Gray
    if ($cpu -and $cpu -ne "None") {
        $cpuParts = $cpu -split "`t"
        $avgCpu = [math]::Round([double]$cpuParts[0], 2)
        $maxCpu = [math]::Round([double]$cpuParts[1], 2)
        $color = if ($avgCpu -gt 80) { "Red" } elseif ($avgCpu -gt 70) { "Yellow" } else { "Green" }
        Write-Host "Avg: ${avgCpu}%  Max: ${maxCpu}%" -ForegroundColor $color
        
        if ($avgCpu -gt 70) {
            Write-Host "  [!] High CPU! Auto Scaling may trigger soon..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "N/A (metrics delayed ~2 min)" -ForegroundColor Gray
    }
    
    # Network
    $netIn = aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name NetworkIn --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    $netOut = aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name NetworkOut --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    
    Write-Host "  Network I/O:     " -NoNewline -ForegroundColor Gray
    if ($netIn -and $netIn -ne "None") {
        $inKB = [math]::Round([double]$netIn / 1024, 2)
        $outKB = [math]::Round([double]$netOut / 1024, 2)
        Write-Host "In: ${inKB}KB  Out: ${outKB}KB" -ForegroundColor Cyan
    } else {
        Write-Host "N/A" -ForegroundColor Gray
    }
    
    # 5. DynamoDB (if available)
    Write-Host "`n[5] DynamoDB Metrics (Last 60 seconds):" -ForegroundColor Yellow
    $readCap = aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ConsumedReadCapacityUnits --dimensions Name=TableName,Value=CourseReg_Courses --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    $writeCap = aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ConsumedWriteCapacityUnits --dimensions Name=TableName,Value=CourseReg_Courses --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
    
    Write-Host "  Consumed RCU:    " -NoNewline -ForegroundColor Gray
    if ($readCap -and $readCap -ne "None") {
        Write-Host "$readCap" -ForegroundColor Cyan
    } else {
        Write-Host "0" -ForegroundColor Gray
    }
    
    Write-Host "  Consumed WCU:    " -NoNewline -ForegroundColor Gray
    if ($writeCap -and $writeCap -ne "None") {
        Write-Host "$writeCap" -ForegroundColor Cyan
    } else {
        Write-Host "0" -ForegroundColor Gray
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "" -ForegroundColor DarkGray
    Write-Host "Refreshing in 10 seconds... (Ctrl+C to stop)" -ForegroundColor Gray
    
    Start-Sleep -Seconds 10
}

