# Real-time Auto-Scaling Monitor
# Run this while load testing to see live scaling activity

param(
    [int]$RefreshSeconds = 10,
    [int]$DurationMinutes = 10
)

$ErrorActionPreference = "Continue"

Write-Host @"

========================================
  REAL-TIME ASG MONITOR
========================================
Refresh interval: ${RefreshSeconds}s
Duration: ${DurationMinutes} minutes
Press Ctrl+C to stop
========================================

"@ -ForegroundColor Cyan

$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)
$iteration = 0
$previousInstanceCount = 0

# Get initial state
Write-Host "[INITIAL STATE]" -ForegroundColor Yellow
$asgInfo = aws autoscaling describe-auto-scaling-groups `
    --auto-scaling-group-names course-reg-asg `
    --region us-east-1 `
    --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]" `
    --output text

$sizes = $asgInfo -split "`t"
Write-Host "  Min: $($sizes[0]) | Desired: $($sizes[1]) | Max: $($sizes[2])" -ForegroundColor White

while ((Get-Date) -lt $endTime) {
    $iteration++
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Clear-Host
    
    Write-Host @"

========================================
  AUTO-SCALING MONITOR - Iteration $iteration
========================================
Time: $(Get-Date -Format 'HH:mm:ss')
Elapsed: ${elapsed}m / ${DurationMinutes}m
========================================

"@ -ForegroundColor Cyan
    
    # 1. EC2 Instances Status
    Write-Host "[EC2 INSTANCES]" -ForegroundColor Yellow
    $instances = aws ec2 describe-instances `
        --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running,pending,stopping,stopped" `
        --query "Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,LaunchTime]" `
        --region us-east-1 --output text
    
    if ($instances) {
        $instanceList = $instances -split "`n" | Where-Object { $_ }
        $runningCount = ($instanceList | Where-Object { $_ -like "*running*" }).Count
        $pendingCount = ($instanceList | Where-Object { $_ -like "*pending*" }).Count
        
        Write-Host "  Total instances: $($instanceList.Count)" -ForegroundColor White
        Write-Host "  Running: $runningCount" -ForegroundColor Green
        
        if ($pendingCount -gt 0) {
            Write-Host "  Pending: $pendingCount (LAUNCHING!)" -ForegroundColor Yellow -BackgroundColor Black
        }
        
        # Show scaling activity
        if ($runningCount -gt $previousInstanceCount) {
            Write-Host "`n  SCALE UP DETECTED! +$($runningCount - $previousInstanceCount) instance(s)" -ForegroundColor Green -BackgroundColor Black
        }
        elseif ($runningCount -lt $previousInstanceCount) {
            Write-Host "`n  SCALE DOWN DETECTED! -$($previousInstanceCount - $runningCount) instance(s)" -ForegroundColor Red
        }
        
        $previousInstanceCount = $runningCount
        
        Write-Host "`n  Instance Details:" -ForegroundColor Gray
        foreach ($inst in $instanceList) {
            $parts = $inst -split "`t"
            $id = $parts[0]
            $state = $parts[1]
            $stateColor = switch ($state) {
                "running" { "Green" }
                "pending" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "    $id - $state" -ForegroundColor $stateColor
        }
    }
    
    # 2. Target Health
    Write-Host "`n[TARGET GROUP HEALTH]" -ForegroundColor Yellow
    $tgArn = aws elbv2 describe-target-groups `
        --names course-reg-tg `
        --query "TargetGroups[0].TargetGroupArn" `
        --output text `
        --region us-east-1 2>$null
    
    if ($tgArn) {
        $health = aws elbv2 describe-target-health `
            --target-group-arn $tgArn `
            --region us-east-1 `
            --query "TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]" `
            --output text
        
        if ($health) {
            $healthList = $health -split "`n" | Where-Object { $_ }
            $healthyCount = ($healthList | Where-Object { $_ -like "*healthy*" }).Count
            Write-Host "  Healthy targets: $healthyCount / $($healthList.Count)" -ForegroundColor Green
            
            foreach ($h in $healthList) {
                $parts = $h -split "`t"
                $id = $parts[0]
                $state = $parts[1]
                $stateColor = if ($state -eq "healthy") { "Green" } else { "Yellow" }
                Write-Host "    $id - $state" -ForegroundColor $stateColor
            }
        }
    }
    
    # 3. Recent Scaling Activities
    Write-Host "`n[RECENT SCALING ACTIVITIES]" -ForegroundColor Yellow
    $activities = aws autoscaling describe-scaling-activities `
        --auto-scaling-group-name course-reg-asg `
        --max-records 3 `
        --region us-east-1 `
        --query "Activities[].[StartTime,StatusCode,Description]" `
        --output text 2>$null
    
    if ($activities) {
        $actList = $activities -split "`n" | Where-Object { $_ }
        foreach ($act in $actList) {
            $parts = $act -split "`t"
            $time = [DateTime]::Parse($parts[0]).ToString("HH:mm:ss")
            $status = $parts[1]
            $desc = $parts[2]
            
            $statusColor = switch ($status) {
                "Successful" { "Green" }
                "InProgress" { "Yellow" }
                default { "Red" }
            }
            
            Write-Host "  [$time] " -NoNewline -ForegroundColor Gray
            Write-Host "$status" -NoNewline -ForegroundColor $statusColor
            Write-Host " - $desc" -ForegroundColor White
        }
    } else {
        Write-Host "  No recent activities" -ForegroundColor Gray
    }
    
    # 4. CloudWatch Metrics (if available)
    Write-Host "`n[CLOUDWATCH METRICS - Last 2 minutes]" -ForegroundColor Yellow
    
    $endMetricTime = Get-Date
    $startMetricTime = $endMetricTime.AddMinutes(-2)
    
    # CPU Utilization
    $cpu = aws cloudwatch get-metric-statistics `
        --namespace AWS/EC2 `
        --metric-name CPUUtilization `
        --dimensions Name=AutoScalingGroupName,Value=course-reg-asg `
        --start-time $startMetricTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --end-time $endMetricTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --period 60 `
        --statistics Average `
        --region us-east-1 `
        --query "Datapoints[-1].Average" `
        --output text 2>$null
    
    if ($cpu -and $cpu -ne "None") {
        $cpuValue = [math]::Round([double]$cpu, 1)
        $cpuColor = if ($cpuValue -gt 70) { "Red" } elseif ($cpuValue -gt 50) { "Yellow" } else { "Green" }
        Write-Host "  CPU Utilization: " -NoNewline -ForegroundColor White
        Write-Host "$cpuValue%" -ForegroundColor $cpuColor
        
        if ($cpuValue -gt 70) {
            Write-Host "    WARNING: CPU above 70% threshold!" -ForegroundColor Red -BackgroundColor Black
        }
    }
    
    # Request Count
    $lbArn = aws elbv2 describe-load-balancers `
        --names course-reg-alb `
        --query "LoadBalancers[0].LoadBalancerArn" `
        --output text `
        --region us-east-1 2>$null
    
    if ($lbArn) {
        $lbId = $lbArn -split "/" | Select-Object -Last 3 | Join-Path -ChildPath ""
        $lbDimension = "app/course-reg-alb/$($lbArn.Split('/')[-3])/$($lbArn.Split('/')[-2])/$($lbArn.Split('/')[-1])"
        
        $requests = aws cloudwatch get-metric-statistics `
            --namespace AWS/ApplicationELB `
            --metric-name RequestCount `
            --dimensions Name=LoadBalancer,Value=$lbDimension `
            --start-time $startMetricTime.ToString("yyyy-MM-ddTHH:mm:ss") `
            --end-time $endMetricTime.ToString("yyyy-MM-ddTHH:mm:ss") `
            --period 60 `
            --statistics Sum `
            --region us-east-1 `
            --query "Datapoints[-1].Sum" `
            --output text 2>$null
        
        if ($requests -and $requests -ne "None") {
            $reqValue = [math]::Round([double]$requests, 0)
            Write-Host "  Request Count (last min): $reqValue" -ForegroundColor White
            
            # Calculate per-target
            if ($runningCount -gt 0) {
                $perTarget = [math]::Round($reqValue / $runningCount, 0)
                $perTargetColor = if ($perTarget -gt 1000) { "Red" } elseif ($perTarget -gt 700) { "Yellow" } else { "Green" }
                Write-Host "  Requests per target: " -NoNewline -ForegroundColor White
                Write-Host "$perTarget" -NoNewline -ForegroundColor $perTargetColor
                Write-Host " (threshold: 1000)" -ForegroundColor Gray
                
                if ($perTarget -gt 1000) {
                    Write-Host "    WARNING: Request count above threshold!" -ForegroundColor Red -BackgroundColor Black
                }
            }
        }
    }
    
    # 5. Summary Status
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Running: $runningCount instances" -ForegroundColor White
    Write-Host "  Next check in: ${RefreshSeconds}s" -ForegroundColor Gray
    Write-Host "  Monitoring until: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
    
    Start-Sleep -Seconds $RefreshSeconds
}

Write-Host "`n[MONITORING COMPLETE]" -ForegroundColor Green
Write-Host "Monitor stopped at $(Get-Date -Format 'HH:mm:ss')`n" -ForegroundColor White
