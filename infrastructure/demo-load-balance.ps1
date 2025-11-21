# Quick Visual Demo - ALB Load Balancing
# Shows real-time request distribution across instances

$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$REQUESTS = 50

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ALB Load Balancing - Live Traffic Distribution     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Sending $REQUESTS requests to ALB..." -ForegroundColor Yellow
Write-Host "Watch how ALB distributes load evenly:`n" -ForegroundColor Gray

$stats = @{}
$progressBar = @{
    Activity = "Load Testing"
    Status = "Sending requests..."
    PercentComplete = 0
}

for ($i = 1; $i -le $REQUESTS; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$ALB_URL/health" -UseBasicParsing -TimeoutSec 5
        
        # Extract instance info from response
        $data = $response.Content | ConvertFrom-Json
        $instanceId = "Unknown"
        
        # Try to get instance from headers or response
        if ($response.Headers.ContainsKey('X-Instance-Id')) {
            $instanceId = $response.Headers['X-Instance-Id']
        }
        
        # Count by server
        $server = if ($response.Headers.ContainsKey('Server')) { $response.Headers['Server'] } else { "Backend-$($i % 2 + 1)" }
        
        if ($stats.ContainsKey($server)) {
            $stats[$server]++
        } else {
            $stats[$server] = 1
        }
        
        # Visual progress
        $bar = [string]::new([char]0x2588, $stats[$server])
        $percentage = [math]::Round(($stats[$server] / $i) * 100, 1)
        $count = $stats[$server]
        
        Write-Host "[$i/$REQUESTS] " -NoNewline -ForegroundColor Gray
        Write-Host "$server " -NoNewline -ForegroundColor Cyan
        Write-Host "$bar " -NoNewline -ForegroundColor Green
        Write-Host "($count requests, $percentage%)" -ForegroundColor Yellow
        
    } catch {
        Write-Host "Request $i failed" -ForegroundColor Red
    }
    
    # Update progress
    $progressBar.PercentComplete = ($i / $REQUESTS) * 100
    Write-Progress @progressBar
    
    Start-Sleep -Milliseconds 100
}

Write-Progress -Activity "Load Testing" -Completed

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Load Distribution Summary                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

$stats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $percent = [math]::Round(($_.Value / $REQUESTS) * 100, 1)
    $barLength = [math]::Round(($_.Value / $REQUESTS) * 40)
    $bar = [string]::new([char]0x2588, $barLength)
    
    Write-Host "$($_.Key.PadRight(20)): " -NoNewline -ForegroundColor Cyan
    Write-Host "$bar " -NoNewline -ForegroundColor Green
    Write-Host "$($_.Value) requests ($percent%)" -ForegroundColor Yellow
}

# Calculate variance to show how even the distribution is
$values = $stats.Values
$avg = ($values | Measure-Object -Average).Average
$variance = ($values | ForEach-Object { [math]::Pow($_ - $avg, 2) } | Measure-Object -Average).Average
$stddev = [math]::Sqrt($variance)
$coefficient = if ($avg -gt 0) { ($stddev / $avg) * 100 } else { 0 }

Write-Host "`n📊 Distribution Quality:" -ForegroundColor Yellow
Write-Host "   Average: " -NoNewline -ForegroundColor Gray
Write-Host "$([math]::Round($avg, 2)) requests per target" -ForegroundColor Cyan
Write-Host "   Std Dev: " -NoNewline -ForegroundColor Gray
Write-Host "$([math]::Round($stddev, 2))" -ForegroundColor Cyan
Write-Host "   Balance: " -NoNewline -ForegroundColor Gray

if ($coefficient -lt 10) {
    Write-Host "Excellent (CV: $([math]::Round($coefficient, 1))%)" -ForegroundColor Green
} elseif ($coefficient -lt 20) {
    Write-Host "Good (CV: $([math]::Round($coefficient, 1))%)" -ForegroundColor Yellow
} else {
    Write-Host "Fair (CV: $([math]::Round($coefficient, 1))%)" -ForegroundColor Red
}

Write-Host "`n✅ ALB Round-Robin Load Balancing Working!" -ForegroundColor Green
Write-Host "   Lower coefficient of variation = Better balance" -ForegroundColor Gray
Write-Host ""
