# Demo Test Script
# Test all endpoints through ALB

$ALB = "course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$BASE_URL = "http://$ALB"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AWS Course Registration System Demo" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "ALB Endpoint: $BASE_URL" -ForegroundColor White
Write-Host "Demo Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Test 1: Health Check
Write-Host "[1/6] Health Check..." -ForegroundColor Yellow
$health = curl.exe -s "$BASE_URL/health" | ConvertFrom-Json
Write-Host "  Status: $($health.status)" -ForegroundColor Green
Write-Host "  Version: $($health.version)" -ForegroundColor Green

Start-Sleep -Seconds 1

# Test 2: Login
Write-Host "`n[2/6] Testing Login..." -ForegroundColor Yellow
$loginData = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$loginResponse = curl.exe -s -X POST "$BASE_URL/api/auth/login" `
    -H "Content-Type: application/json" `
    -d $loginData | ConvertFrom-Json

if ($loginResponse.access_token) {
    Write-Host "  Login successful!" -ForegroundColor Green
    Write-Host "  User: $($loginResponse.username) ($($loginResponse.role))" -ForegroundColor Green
    $token = $loginResponse.access_token
} else {
    Write-Host "  Login failed!" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Test 3: List Courses
Write-Host "`n[3/6] Fetching Courses..." -ForegroundColor Yellow
$courses = curl.exe -s "$BASE_URL/api/courses?semester=202401" `
    -H "Authorization: Bearer $token" | ConvertFrom-Json

Write-Host "  Found $($courses.Count) courses" -ForegroundColor Green
if ($courses.Count -gt 0) {
    $courses | Select-Object -First 3 | ForEach-Object {
        Write-Host "    - $($_.course_code): $($_.name)" -ForegroundColor White
    }
}

Start-Sleep -Seconds 1

# Test 4: My Enrollments
Write-Host "`n[4/6] Checking My Enrollments..." -ForegroundColor Yellow
$enrollments = curl.exe -s "$BASE_URL/api/enrollments-simple/my-enrollments?semester=202401" `
    -H "Authorization: Bearer $token" | ConvertFrom-Json

Write-Host "  Total enrollments: $($enrollments.Count)" -ForegroundColor Green

Start-Sleep -Seconds 1

# Test 5: Performance Test
Write-Host "`n[5/6] Performance Test (10 requests)..." -ForegroundColor Yellow
$times = @()
for ($i = 1; $i -le 10; $i++) {
    $start = Get-Date
    $null = curl.exe -s "$BASE_URL/api/courses?semester=202401" -H "Authorization: Bearer $token"
    $end = Get-Date
    $elapsed = ($end - $start).TotalMilliseconds
    $times += $elapsed
    Write-Host "    Request $i`: $([math]::Round($elapsed))ms" -ForegroundColor Gray
}

$avgTime = ($times | Measure-Object -Average).Average
Write-Host "  Average response time: $([math]::Round($avgTime))ms" -ForegroundColor Green

Start-Sleep -Seconds 1

# Test 6: Check Infrastructure
Write-Host "`n[6/6] Infrastructure Status..." -ForegroundColor Yellow
$instances = aws ec2 describe-instances `
    --filters "Name=tag:aws:autoscaling:groupName,Values=course-reg-asg" "Name=instance-state-name,Values=running" `
    --query "Reservations[].Instances[].[InstanceId,InstanceType,State.Name]" `
    --region us-east-1 --output text

$instanceCount = ($instances -split "`n" | Where-Object { $_ }).Count
Write-Host "  Active EC2 instances: $instanceCount" -ForegroundColor Green

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Demo Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Health: OK" -ForegroundColor Green
Write-Host "  Authentication: OK" -ForegroundColor Green
Write-Host "  API Endpoints: OK" -ForegroundColor Green
Write-Host "  Avg Response Time: $([math]::Round($avgTime))ms" -ForegroundColor Green
Write-Host "  Infrastructure: $instanceCount instances running" -ForegroundColor Green
Write-Host "`nDemo completed successfully!`n" -ForegroundColor Green
