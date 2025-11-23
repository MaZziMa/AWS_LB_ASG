# Quick Demo Launcher
# One command to start the full auto-scaling demo

Write-Host @"

========================================
  AUTO-SCALING DEMO LAUNCHER
========================================

"@ -ForegroundColor Cyan

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# 1. Check if Locust is installed
try {
    $locustVersion = locust --version 2>$null
    Write-Host "  Locust: Installed" -ForegroundColor Green
    $hasLocust = $true
} catch {
    Write-Host "  Locust: Not installed" -ForegroundColor Red
    $hasLocust = $false
}

# 2. Check AWS CLI
try {
    $awsVersion = aws --version 2>$null
    Write-Host "  AWS CLI: Installed" -ForegroundColor Green
} catch {
    Write-Host "  AWS CLI: Not installed (Required!)" -ForegroundColor Red
    exit 1
}

# 3. Check infrastructure
$instances = aws ec2 describe-instances `
    --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running" `
    --region us-east-1 `
    --query "Reservations[].Instances[].InstanceId" `
    --output text 2>$null

if ($instances) {
    Write-Host "  Infrastructure: Ready ($($instances.Split("`t").Count) instance(s))" -ForegroundColor Green
} else {
    Write-Host "  Infrastructure: No instances running!" -ForegroundColor Red
    exit 1
}

# Show options
Write-Host @"

========================================
  DEMO OPTIONS
========================================

"@ -ForegroundColor Cyan

Write-Host "[1] PowerShell Load Test (Simple, Fast)" -ForegroundColor White
Write-Host "    - 200 concurrent workers" -ForegroundColor Gray
Write-Host "    - 5 minute duration" -ForegroundColor Gray
Write-Host "    - Built-in monitoring" -ForegroundColor Gray

if ($hasLocust) {
    Write-Host "`n[2] Locust Load Test (Advanced, Web UI)" -ForegroundColor White
    Write-Host "    - Configurable users/spawn rate" -ForegroundColor Gray
    Write-Host "    - Real-time web dashboard" -ForegroundColor Gray
    Write-Host "    - More realistic traffic patterns" -ForegroundColor Gray
}

Write-Host "`n[3] Monitor Only (Watch existing load)" -ForegroundColor White
Write-Host "    - Real-time ASG monitoring" -ForegroundColor Gray
Write-Host "    - No load generation" -ForegroundColor Gray

Write-Host "`n[4] View Demo Guide" -ForegroundColor White
Write-Host "    - Full documentation" -ForegroundColor Gray

Write-Host "`n[Q] Quit" -ForegroundColor White

Write-Host "`n========================================`n" -ForegroundColor Cyan

$choice = Read-Host "Select option"

switch ($choice) {
    "1" {
        Write-Host "`nStarting PowerShell Load Test Demo..." -ForegroundColor Green
        Write-Host "This will:" -ForegroundColor Yellow
        Write-Host "  1. Open monitor in new window" -ForegroundColor Gray
        Write-Host "  2. Run load test for 5 minutes" -ForegroundColor Gray
        Write-Host "  3. Trigger auto-scaling" -ForegroundColor Gray
        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Start monitor in new window
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\monitor-autoscaling.ps1 -RefreshSeconds 10 -DurationMinutes 10"
        
        Start-Sleep -Seconds 2
        
        # Run load test in current window
        .\trigger-autoscaling.ps1 -DurationMinutes 5 -ConcurrentUsers 200
    }
    
    "2" {
        if (-not $hasLocust) {
            Write-Host "`nLocust is not installed!" -ForegroundColor Red
            Write-Host "Install with: pip install locust" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "`nStarting Locust Load Test Demo..." -ForegroundColor Green
        Write-Host "`nThis will:" -ForegroundColor Yellow
        Write-Host "  1. Open monitor in new window" -ForegroundColor Gray
        Write-Host "  2. Start Locust web UI" -ForegroundColor Gray
        Write-Host "  3. Open browser to http://localhost:8089" -ForegroundColor Gray
        Write-Host "`nRecommended Locust settings:" -ForegroundColor Yellow
        Write-Host "  - Users: 300" -ForegroundColor White
        Write-Host "  - Spawn rate: 20" -ForegroundColor White
        Write-Host "  - Duration: 10 minutes" -ForegroundColor White
        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Start monitor
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\monitor-autoscaling.ps1"
        
        Start-Sleep -Seconds 2
        
        # Start Locust
        Write-Host "`nStarting Locust..." -ForegroundColor Green
        Start-Process "http://localhost:8089"
        
        cd ..
        locust -f infrastructure/locustfile-autoscaling.py --host=http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
    }
    
    "3" {
        Write-Host "`nStarting Monitor Only..." -ForegroundColor Green
        .\monitor-autoscaling.ps1 -RefreshSeconds 10 -DurationMinutes 15
    }
    
    "4" {
        Write-Host "`nOpening Demo Guide..." -ForegroundColor Green
        Start-Process "DEMO_AUTOSCALING_GUIDE.md"
    }
    
    "Q" {
        Write-Host "`nGoodbye!" -ForegroundColor Green
        exit 0
    }
    
    default {
        Write-Host "`nInvalid option!" -ForegroundColor Red
        exit 1
    }
}
