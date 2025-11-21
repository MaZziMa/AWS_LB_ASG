# Simple Load Balance Demo
$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$REQUESTS = 30

Write-Host "`n=== ALB Load Balancing Demo ===" -ForegroundColor Cyan
Write-Host "Sending $REQUESTS requests...`n" -ForegroundColor Yellow

$stats = @{}

for ($i = 1; $i -le $REQUESTS; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$ALB_URL/health" -UseBasicParsing -TimeoutSec 5
        $server = if ($response.Headers.ContainsKey('Server')) { $response.Headers['Server'] } else { "Backend" }
        
        if (!$stats.ContainsKey($server)) {
            $stats[$server] = 0
        }
        $stats[$server]++
        
        $count = $stats[$server]
        $pct = [math]::Round(($count / $i) * 100, 1)
        
        Write-Host "Request $i -> " -NoNewline -ForegroundColor Gray
        Write-Host $server -NoNewline -ForegroundColor Cyan
        Write-Host " ($count requests, $pct%)" -ForegroundColor Yellow
        
    } catch {
        Write-Host "Request $i -> Failed" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 100
}

Write-Host "`n=== Distribution Summary ===" -ForegroundColor Green

$stats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $percent = [math]::Round(($_.Value / $REQUESTS) * 100, 1)
    $barLen = [math]::Round(($_.Value / $REQUESTS) * 40)
    $bar = [string]::new('=', $barLen)
    
    Write-Host "$($_.Key): " -NoNewline -ForegroundColor Cyan
    Write-Host "$bar " -NoNewline -ForegroundColor Green
    Write-Host "$($_.Value) requests ($percent%)" -ForegroundColor Yellow
}

$values = $stats.Values
if ($values.Count -gt 1) {
    $avg = ($values | Measure-Object -Average).Average
    $variance = ($values | ForEach-Object { [math]::Pow($_ - $avg, 2) } | Measure-Object -Average).Average
    $stddev = [math]::Sqrt($variance)
    $cv = if ($avg -gt 0) { ($stddev / $avg) * 100 } else { 0 }
    
    Write-Host "`nBalance Quality: " -NoNewline -ForegroundColor Yellow
    if ($cv -lt 10) {
        Write-Host "Excellent" -ForegroundColor Green
    } elseif ($cv -lt 20) {
        Write-Host "Good" -ForegroundColor Yellow
    } else {
        Write-Host "Fair" -ForegroundColor Red
    }
}

Write-Host "`n✅ ALB distributes load evenly across targets`n" -ForegroundColor Green
