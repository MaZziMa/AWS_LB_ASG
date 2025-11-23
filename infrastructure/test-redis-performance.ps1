#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test Redis cache performance vs no-cache
.DESCRIPTION
    Compare response times with and without Redis caching
#>

$alb = "course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"

Write-Host "`n=== Redis Performance Test ===" -ForegroundColor Cyan
Write-Host "ALB: $alb`n" -ForegroundColor Gray

# Function to measure average response time
function Test-Endpoint {
    param(
        [string]$Url,
        [int]$Iterations = 10
    )
    
    $times = @()
    
    for($i = 1; $i -le $Iterations; $i++) {
        $time = (Measure-Command {
            try {
                Invoke-RestMethod -Uri $Url -ErrorAction Stop | Out-Null
            } catch {
                Write-Host "  Request $i failed" -ForegroundColor Red
            }
        }).TotalMilliseconds
        
        $times += $time
        Write-Host "  [$i/$Iterations] $([math]::Round($time, 2)) ms" -ForegroundColor Gray
    }
    
    $avg = ($times | Measure-Object -Average).Average
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    
    return @{
        Average = $avg
        Min = $min
        Max = $max
        Times = $times
    }
}

# Test 1: Login (no cache expected)
Write-Host "`n--- Test 1: Login ---" -ForegroundColor Yellow
$loginData = @{ username = "admin"; password = "admin123" } | ConvertTo-Json
$loginResult = Test-Endpoint -Url "http://$alb/api/auth/login" -Iterations 5

Write-Host "`nLogin Results:" -ForegroundColor Green
Write-Host "  Avg: $([math]::Round($loginResult.Average, 2)) ms"
Write-Host "  Min: $([math]::Round($loginResult.Min, 2)) ms"
Write-Host "  Max: $([math]::Round($loginResult.Max, 2)) ms"

# Get token for authenticated requests
$response = Invoke-RestMethod -Uri "http://$alb/api/auth/login" -Method POST -Body $loginData -ContentType "application/json"
$token = $response.access_token
$headers = @{ Authorization = "Bearer $token" }

# Test 2: Get courses - First request (cache MISS)
Write-Host "`n--- Test 2: Get Courses (First - Cache MISS) ---" -ForegroundColor Yellow
$coursesUrl = "http://$alb/api/courses"

Write-Host "First request (should be slower - Cache MISS):"
$firstTime = (Measure-Command {
    $courses = Invoke-RestMethod -Uri $coursesUrl -Headers $headers
}).TotalMilliseconds

Write-Host "  Time: $([math]::Round($firstTime, 2)) ms" -ForegroundColor Cyan
Write-Host "  Courses returned: $($courses.Count)"

Start-Sleep -Seconds 2

# Test 3: Get courses - Subsequent requests (cache HIT)
Write-Host "`n--- Test 3: Get Courses (Subsequent - Cache HIT) ---" -ForegroundColor Yellow
$coursesResult = Test-Endpoint -Url $coursesUrl -Iterations 10

Write-Host "`nCached Results:" -ForegroundColor Green
Write-Host "  Avg: $([math]::Round($coursesResult.Average, 2)) ms"
Write-Host "  Min: $([math]::Round($coursesResult.Min, 2)) ms"
Write-Host "  Max: $([math]::Round($coursesResult.Max, 2)) ms"

# Calculate speedup
$speedup = $firstTime / $coursesResult.Average
Write-Host "`n🚀 Speedup: $([math]::Round($speedup, 2))x faster with cache" -ForegroundColor Green

# Test 4: Enrollments
Write-Host "`n--- Test 4: My Enrollments ---" -ForegroundColor Yellow
$enrollmentsUrl = "http://$alb/api/enrollments/my-enrollments"

Write-Host "First request (Cache MISS):"
$enrollFirstTime = (Measure-Command {
    Invoke-RestMethod -Uri $enrollmentsUrl -Headers $headers | Out-Null
}).TotalMilliseconds
Write-Host "  Time: $([math]::Round($enrollFirstTime, 2)) ms" -ForegroundColor Cyan

Start-Sleep -Seconds 1

Write-Host "`nSubsequent requests (Cache HIT):"
$enrollResult = Test-Endpoint -Url $enrollmentsUrl -Iterations 10

Write-Host "`nEnrollments Results:" -ForegroundColor Green
Write-Host "  First (MISS): $([math]::Round($enrollFirstTime, 2)) ms"
Write-Host "  Avg (HIT): $([math]::Round($enrollResult.Average, 2)) ms"
Write-Host "  Speedup: $([math]::Round($enrollFirstTime / $enrollResult.Average, 2))x"

# Summary
Write-Host "`n=== Performance Summary ===" -ForegroundColor Cyan
Write-Host "┌─────────────────────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "│ Endpoint          │ No Cache │ Cached │ Speedup    │" -ForegroundColor Gray
Write-Host "├─────────────────────────────────────────────────────┤" -ForegroundColor Gray
Write-Host "│ Courses           │ $([math]::Round($firstTime, 0).ToString().PadLeft(8)) │ $([math]::Round($coursesResult.Average, 0).ToString().PadLeft(6)) │ $([math]::Round($speedup, 2).ToString().PadLeft(10))x │" -ForegroundColor White
Write-Host "│ Enrollments       │ $([math]::Round($enrollFirstTime, 0).ToString().PadLeft(8)) │ $([math]::Round($enrollResult.Average, 0).ToString().PadLeft(6)) │ $([math]::Round($enrollFirstTime / $enrollResult.Average, 2).ToString().PadLeft(10))x │" -ForegroundColor White
Write-Host "└─────────────────────────────────────────────────────┘" -ForegroundColor Gray

Write-Host "`n💡 Redis cache giảm response time trung bình:" -ForegroundColor Yellow
$overallSpeedup = (($firstTime + $enrollFirstTime) / 2) / (($coursesResult.Average + $enrollResult.Average) / 2)
Write-Host "   $([math]::Round($overallSpeedup, 2))x nhanh hơn" -ForegroundColor Green
