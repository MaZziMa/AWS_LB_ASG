# Auto-Scaling Trigger Test
# This script generates high load to trigger auto-scaling policies

param(
    [int]$DurationMinutes = 5,
    [int]$ConcurrentUsers = 200,
    [string]$TargetUrl = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
)

$ErrorActionPreference = "Continue"

Write-Host @"

========================================
  AUTO-SCALING TRIGGER TEST
========================================
Target: $TargetUrl
Duration: $DurationMinutes minutes
Concurrent Users: $ConcurrentUsers
========================================

"@ -ForegroundColor Cyan

# Function to monitor ASG instances
function Get-ASGStatus {
    Write-Host "`n[MONITOR] Checking ASG status..." -ForegroundColor Yellow
    
    $instances = aws ec2 describe-instances `
        --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running,pending" `
        --query "Reservations[].Instances[].[InstanceId,State.Name,LaunchTime]" `
        --region us-east-1 --output json | ConvertFrom-Json
    
    $runningCount = ($instances | Where-Object { $_[1] -eq "running" }).Count
    $pendingCount = ($instances | Where-Object { $_[1] -eq "pending" }).Count
    
    Write-Host "  Running instances: $runningCount" -ForegroundColor Green
    if ($pendingCount -gt 0) {
        Write-Host "  Pending instances: $pendingCount (SCALING UP!)" -ForegroundColor Yellow
    }
    
    return $runningCount + $pendingCount
}

# Function to get ALB metrics
function Get-ALBMetrics {
    Write-Host "`n[METRICS] Fetching CloudWatch metrics..." -ForegroundColor Yellow
    
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-2)
    
    # Get request count
    $requestCount = aws cloudwatch get-metric-statistics `
        --namespace AWS/ApplicationELB `
        --metric-name RequestCount `
        --dimensions Name=LoadBalancer,Value=app/course-reg-alb/$(aws elbv2 describe-load-balancers --names course-reg-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region us-east-1 | Split-Path -Leaf) `
        --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --period 60 `
        --statistics Sum `
        --region us-east-1 `
        --query "Datapoints[-1].Sum" --output text 2>$null
    
    if ($requestCount -and $requestCount -ne "None") {
        Write-Host "  Request count (last min): $requestCount" -ForegroundColor White
    }
    
    # Get target response time
    $responseTime = aws cloudwatch get-metric-statistics `
        --namespace AWS/ApplicationELB `
        --metric-name TargetResponseTime `
        --dimensions Name=LoadBalancer,Value=app/course-reg-alb/$(aws elbv2 describe-load-balancers --names course-reg-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region us-east-1 | Split-Path -Leaf) `
        --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ss") `
        --period 60 `
        --statistics Average `
        --region us-east-1 `
        --query "Datapoints[-1].Average" --output text 2>$null
    
    if ($responseTime -and $responseTime -ne "None") {
        Write-Host "  Avg response time: $([math]::Round([double]$responseTime * 1000))ms" -ForegroundColor White
    }
}

# Function to generate load using PowerShell jobs
function Start-LoadTest {
    param([int]$Workers, [int]$DurationSec)
    
    Write-Host "`n[LOAD TEST] Starting $Workers concurrent workers for $DurationSec seconds..." -ForegroundColor Green
    
    $scriptBlock = {
        param($url, $duration)
        $endTime = (Get-Date).AddSeconds($duration)
        $requests = 0
        $errors = 0
        
        while ((Get-Date) -lt $endTime) {
            try {
                # Mix of endpoints to simulate real traffic
                $endpoints = @(
                    "/health",
                    "/api/courses?semester=202401",
                    "/api/courses?semester=202402",
                    "/health"
                )
                
                $endpoint = $endpoints | Get-Random
                $response = Invoke-WebRequest -Uri "$url$endpoint" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                $requests++
            } catch {
                $errors++
            }
            
            # Small delay to avoid overwhelming
            Start-Sleep -Milliseconds 50
        }
        
        return @{
            Requests = $requests
            Errors = $errors
        }
    }
    
    # Start all worker jobs
    $jobs = @()
    for ($i = 1; $i -le $Workers; $i++) {
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $TargetUrl, $DurationSec
        $jobs += $job
    }
    
    Write-Host "  Started $($jobs.Count) worker jobs" -ForegroundColor Gray
    
    return $jobs
}

# Main Test Execution
Write-Host "`n[START] Initiating load test at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan

# Get initial state
$initialInstances = Get-ASGStatus
Write-Host "`nInitial state: $initialInstances instance(s)" -ForegroundColor White

# Start load test
$durationSec = $DurationMinutes * 60
$jobs = Start-LoadTest -Workers $ConcurrentUsers -DurationSec $durationSec

# Monitor progress
$monitorInterval = 15 # seconds
$iterations = [math]::Ceiling($durationSec / $monitorInterval)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  MONITORING (checking every ${monitorInterval}s)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$maxInstances = $initialInstances

for ($i = 1; $i -le $iterations; $i++) {
    Start-Sleep -Seconds $monitorInterval
    
    $elapsed = $i * $monitorInterval
    $remaining = $durationSec - $elapsed
    
    Write-Host "`n--- Progress: $elapsed/$durationSec seconds (${remaining}s remaining) ---" -ForegroundColor Cyan
    
    # Check ASG status
    $currentInstances = Get-ASGStatus
    if ($currentInstances -gt $maxInstances) {
        $maxInstances = $currentInstances
        Write-Host "`n  AUTO-SCALING TRIGGERED! New instance detected!" -ForegroundColor Green -BackgroundColor Black
    }
    
    # Get metrics
    Get-ALBMetrics
    
    # Check job status
    $runningJobs = ($jobs | Where-Object { $_.State -eq "Running" }).Count
    Write-Host "  Active workers: $runningJobs/$ConcurrentUsers" -ForegroundColor Gray
}

# Wait for all jobs to complete
Write-Host "`n[FINISH] Waiting for all workers to complete..." -ForegroundColor Yellow
$results = $jobs | Wait-Job | Receive-Job

# Calculate totals
$totalRequests = ($results | Measure-Object -Property Requests -Sum).Sum
$totalErrors = ($results | Measure-Object -Property Errors -Sum).Sum
$successRate = [math]::Round((($totalRequests - $totalErrors) / $totalRequests) * 100, 2)

# Clean up jobs
$jobs | Remove-Job

# Final status check
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FINAL RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Get-ASGStatus
Get-ALBMetrics

Write-Host "`n[LOAD TEST STATS]" -ForegroundColor Yellow
Write-Host "  Total requests: $totalRequests" -ForegroundColor White
Write-Host "  Failed requests: $totalErrors" -ForegroundColor White
Write-Host "  Success rate: $successRate%" -ForegroundColor White
Write-Host "  Avg RPS: $([math]::Round($totalRequests / $durationSec, 1))" -ForegroundColor White

Write-Host "`n[AUTO-SCALING RESULTS]" -ForegroundColor Yellow
Write-Host "  Initial instances: $initialInstances" -ForegroundColor White
Write-Host "  Max instances reached: $maxInstances" -ForegroundColor White

if ($maxInstances -gt $initialInstances) {
    Write-Host "`n  AUTO-SCALING SUCCESSFUL!" -ForegroundColor Green -BackgroundColor Black
    Write-Host "  Scaled from $initialInstances to $maxInstances instances" -ForegroundColor Green
} else {
    Write-Host "`n  AUTO-SCALING NOT TRIGGERED" -ForegroundColor Yellow
    Write-Host "  Consider increasing load or duration" -ForegroundColor Yellow
}

Write-Host "`n[NOTE] It may take 3-5 minutes for new instances to appear" -ForegroundColor Gray
Write-Host "       Check ASG Activity History for details:" -ForegroundColor Gray
Write-Host "       aws autoscaling describe-scaling-activities --auto-scaling-group-name course-reg-asg --max-records 5 --region us-east-1" -ForegroundColor Gray

Write-Host "`nTest completed at $(Get-Date -Format 'HH:mm:ss')`n" -ForegroundColor Cyan
