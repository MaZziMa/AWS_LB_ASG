# Simple Stress Test Runner (No Locust/C++ compiler required)
param(
    [int]$Users = 50,
    [int]$Minutes = 5
)

$API_HOST = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"

Write-Host "`n=== Simple Stress Test Runner ===" -ForegroundColor Cyan
Write-Host "Users: $Users" -ForegroundColor Yellow
Write-Host "Duration: $Minutes minutes" -ForegroundColor Yellow
Write-Host "API Host: $API_HOST" -ForegroundColor Yellow
Write-Host ""

# Set Python path
$env:Path = "D:\Python314;D:\Python314\Scripts;" + $env:Path

# Check if requests library is installed
Write-Host "Checking dependencies..." -ForegroundColor Gray
python -c "import requests" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing requests library..." -ForegroundColor Yellow
    python -m pip install requests -q
}

Write-Host "[OK] Dependencies ready" -ForegroundColor Green
Write-Host ""

# Run the stress test
Write-Host "Starting stress test..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop early" -ForegroundColor Gray
Write-Host ""

python .\loadtest\simple_stress_test.py $Users $Minutes

Write-Host ""
Write-Host "Stress test completed!" -ForegroundColor Green
