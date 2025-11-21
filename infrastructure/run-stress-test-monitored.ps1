# Run Stress Test with Real-time AWS Monitoring
# Opens CloudWatch metrics in parallel while running load test

param(
    [int]$Users = 200,
    [int]$SpawnRate = 20,
    [string]$RunTime = "10m"
)

$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$REGION = "us-east-1"

Write-Host @"

╔════════════════════════════════════════════════════════════╗
║     Stress Test with Real-time AWS Monitoring              ║
╚════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Test Configuration:" -ForegroundColor Yellow
Write-Host "  Users:      $Users" -ForegroundColor Cyan
Write-Host "  Spawn Rate: $SpawnRate/sec" -ForegroundColor Cyan
Write-Host "  Duration:   $RunTime" -ForegroundColor Cyan
Write-Host "  Target:     $ALB_URL" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

$pythonCheck = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Python not found! Install Python 3.11+" -ForegroundColor Red
    exit 1
}
Write-Host "  Python: $pythonCheck" -ForegroundColor Green

# Setup virtual environment
$venvPath = ".venv_loadtest"
if (!(Test-Path $venvPath)) {
    Write-Host "`nCreating virtual environment..." -ForegroundColor Yellow
    python -m venv $venvPath
}

# Activate and install
Write-Host "Installing dependencies..." -ForegroundColor Yellow
& "$venvPath\Scripts\Activate.ps1"
pip install -q -U pip
pip install -q -r loadtest\requirements.txt

# Start monitoring in background
Write-Host "`nStarting AWS monitoring..." -ForegroundColor Yellow
$monitorScript = {
    param($Region)
    
    $TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"
    $ASG_NAME = "course-reg-asg"
    $ALB_NAME = "app/course-reg-alb/7d13a6bcf5e0d9f7"
    
    Write-Host "`n=== Real-time Monitoring Started ===" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Gray
    
    while ($true) {
        Clear-Host
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║     AWS Monitoring Dashboard - $timestamp              ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Target Health
        Write-Host "[1] Target Health:" -ForegroundColor Yellow
        $targets = aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output text
        $targets -split "`n" | ForEach-Object {
            $parts = $_ -split "`t"
            if ($parts.Count -ge 2) {
                $color = if ($parts[1] -eq "healthy") { "Green" } else { "Red" }
                Write-Host "  $($parts[0]): $($parts[1])" -ForegroundColor $color
            }
        }
        
        # ASG Status
        Write-Host "`n[2] Auto Scaling Group:" -ForegroundColor Yellow
        $asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Current:length(Instances)}' --output text
        Write-Host "  Desired/Current: $asg" -ForegroundColor Cyan
        
        # Recent metrics (last 1 minute)
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddMinutes(-1)
        $startStr = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endStr = $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        Write-Host "`n[3] ALB Metrics (Last 1 min):" -ForegroundColor Yellow
        
        # Request Count
        $reqCount = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
        Write-Host "  Requests: " -NoNewline -ForegroundColor Gray
        if ($reqCount -and $reqCount -ne "None") {
            Write-Host "$reqCount" -ForegroundColor Cyan
        } else {
            Write-Host "0" -ForegroundColor Gray
        }
        
        # Response Time
        $respTime = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Average --query 'Datapoints[0].Average' --output text 2>$null
        Write-Host "  Avg Response: " -NoNewline -ForegroundColor Gray
        if ($respTime -and $respTime -ne "None") {
            $ms = [math]::Round([double]$respTime * 1000, 2)
            Write-Host "${ms}ms" -ForegroundColor Cyan
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        # 4xx/5xx errors
        $errors4xx = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_4XX_Count --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
        $errors5xx = aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count --dimensions Name=LoadBalancer,Value=$ALB_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Sum --query 'Datapoints[0].Sum' --output text 2>$null
        
        $err4 = if ($errors4xx -and $errors4xx -ne "None") { $errors4xx } else { "0" }
        $err5 = if ($errors5xx -and $errors5xx -ne "None") { $errors5xx } else { "0" }
        Write-Host "  Errors: " -NoNewline -ForegroundColor Gray
        Write-Host "4xx=$err4, 5xx=$err5" -ForegroundColor $(if ($err5 -gt 0) { "Red" } elseif ($err4 -gt 0) { "Yellow" } else { "Green" })
        
        # CPU Usage
        Write-Host "`n[4] EC2 CPU (Last 1 min):" -ForegroundColor Yellow
        $cpu = aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME --start-time $startStr --end-time $endStr --period 60 --statistics Average --query 'Datapoints[0].Average' --output text 2>$null
        Write-Host "  CPU Average: " -NoNewline -ForegroundColor Gray
        if ($cpu -and $cpu -ne "None") {
            $cpuVal = [math]::Round([double]$cpu, 2)
            $color = if ($cpuVal -gt 80) { "Red" } elseif ($cpuVal -gt 60) { "Yellow" } else { "Green" }
            Write-Host "$cpuVal%" -ForegroundColor $color
        } else {
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        Write-Host "`nRefreshing in 10 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

$monitorJob = Start-Job -ScriptBlock $monitorScript -ArgumentList $REGION

Write-Host "Monitoring started in background (Job ID: $($monitorJob.Id))" -ForegroundColor Green
Write-Host "`nStarting stress test in 5 seconds..." -ForegroundColor Yellow
Write-Host "You can view monitoring in another terminal with:" -ForegroundColor Gray
Write-Host "  Receive-Job -Id $($monitorJob.Id) -Keep" -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Run Locust
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Starting Locust Load Test                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Push-Location loadtest
try {
    locust -f locustfile.py --headless --users $Users --spawn-rate $SpawnRate --run-time $RunTime --host $ALB_URL
} finally {
    Pop-Location
}

# Stop monitoring
Write-Host "`nStopping monitoring..." -ForegroundColor Yellow
Stop-Job -Id $monitorJob.Id
Remove-Job -Id $monitorJob.Id

# Show final summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                   Test Complete!                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "View detailed metrics in AWS Console:" -ForegroundColor Yellow
Write-Host "  CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=$REGION" -ForegroundColor Cyan
Write-Host "  ALB: https://console.aws.amazon.com/ec2/home?region=$REGION#LoadBalancers:" -ForegroundColor Cyan
Write-Host "  ASG: https://console.aws.amazon.com/ec2/home?region=$REGION#AutoScalingGroups:" -ForegroundColor Cyan
Write-Host ""
