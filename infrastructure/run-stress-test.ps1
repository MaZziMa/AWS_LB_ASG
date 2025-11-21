param(
  [int]$Users = 200,
  [int]$SpawnRate = 20,
  [string]$RunTime = "10m",
  [string]$ApiHost = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
)

Write-Host "`n=== Locust Stress Test (Headless) ===" -ForegroundColor Cyan
Write-Host "Users: $Users  SpawnRate: $SpawnRate  RunTime: $RunTime" -ForegroundColor Gray
Write-Host "Host: $ApiHost" -ForegroundColor Gray

$root = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $root ".venv_loadtest"
$loadtestPath = Join-Path $root "loadtest"

if (!(Test-Path $venvPath)) {
  Write-Host "Creating virtual environment..." -ForegroundColor Yellow
  python -m venv $venvPath
}

# Activate venv
$activate = Join-Path $venvPath "Scripts\Activate.ps1"
. $activate

# Install deps
pip install -U pip > $null
pip install -r (Join-Path $loadtestPath "requirements.txt")

# Run Locust headless
Push-Location $loadtestPath
try {
  locust -f locustfile.py --headless --users $Users --spawn-rate $SpawnRate --run-time $RunTime --host $ApiHost
}
finally {
  Pop-Location
}
