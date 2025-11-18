# Script to diagnose EC2 instance health issues
param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId
)

Write-Host "`n=== Instance Health Diagnostics ===" -ForegroundColor Cyan
Write-Host "Instance: $InstanceId`n" -ForegroundColor Yellow

# 1. Check instance state
Write-Host "1. Instance State:" -ForegroundColor Yellow
$instanceInfo = aws ec2 describe-instances `
    --instance-ids $InstanceId `
    --query 'Reservations[0].Instances[0].[State.Name,LaunchTime,PublicIpAddress]' `
    --output text

$state, $launchTime, $publicIp = $instanceInfo -split "`t"
Write-Host "  State: $state" -ForegroundColor Green
Write-Host "  Launch Time: $launchTime" -ForegroundColor Green
Write-Host "  Public IP: $publicIp" -ForegroundColor Green

# 2. Check status checks
Write-Host "`n2. Status Checks:" -ForegroundColor Yellow
$statusChecks = aws ec2 describe-instance-status `
    --instance-ids $InstanceId `
    --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' `
    --output text

if ($statusChecks) {
    $systemStatus, $instanceStatus = $statusChecks -split "`t"
    Write-Host "  System Status: $systemStatus" -ForegroundColor Green
    Write-Host "  Instance Status: $instanceStatus" -ForegroundColor Green
} else {
    Write-Host "  Status checks not yet available (instance too new)" -ForegroundColor Yellow
}

# 3. Check console output for errors
Write-Host "`n3. Recent Console Output (last 30 lines):" -ForegroundColor Yellow
$consoleOutput = aws ec2 get-console-output `
    --instance-id $InstanceId `
    --query 'Output' `
    --output text 2>$null

if ($consoleOutput) {
    $consoleOutput -split "`n" | Select-Object -Last 30 | ForEach-Object {
        if ($_ -match "error|failed|exception" -and $_ -notmatch "no error") {
            Write-Host "  $_" -ForegroundColor Red
        } elseif ($_ -match "success|complete|started|running") {
            Write-Host "  $_" -ForegroundColor Green
        } else {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Console output not yet available" -ForegroundColor Yellow
}

# 4. Check if user-data script is still running
Write-Host "`n4. User Data Script Status:" -ForegroundColor Yellow
if ($consoleOutput -match "User Data Script Complete") {
    Write-Host "  User data script COMPLETED" -ForegroundColor Green
} elseif ($consoleOutput -match "Starting EC2 User Data Script") {
    Write-Host "  User data script STARTED but may still be running" -ForegroundColor Yellow
} else {
    Write-Host "  User data script status UNKNOWN" -ForegroundColor Yellow
}

# 5. Check service status via SSH (if key is available)
Write-Host "`n5. To check application service manually:" -ForegroundColor Yellow
Write-Host "  ssh -i your-key.pem ec2-user@$publicIp" -ForegroundColor White
Write-Host "  sudo systemctl status course-registration" -ForegroundColor White
Write-Host "  sudo journalctl -u course-registration -n 50" -ForegroundColor White
Write-Host "  sudo tail -f /var/log/user-data.log" -ForegroundColor White

# 6. Check if port 8000 is responding
Write-Host "`n6. Testing HTTP endpoint:" -ForegroundColor Yellow
Write-Host "  Trying http://${publicIp}:8000/health ..." -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://${publicIp}:8000/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  SUCCESS: Application is responding!" -ForegroundColor Green
    Write-Host "  Response: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: Application not responding" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Diagnostics Complete ===" -ForegroundColor Cyan
