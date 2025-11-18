# Setup SNS Topic for CloudWatch Alarms
# PowerShell script - Chạy trước setup-alarms.ps1

Write-Host "=== Setting up SNS Topic for Alarms ===" -ForegroundColor Cyan

# Thay đổi email này thành email của bạn
$YOUR_EMAIL = "sang59498@gmail.com"

Write-Host "`n1. Creating SNS Topic..." -ForegroundColor Yellow
$TOPIC_ARN = aws sns create-topic --name course-reg-alerts --query 'TopicArn' --output text

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SNS Topic created: $TOPIC_ARN" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create SNS Topic" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Subscribing email to SNS Topic..." -ForegroundColor Yellow
aws sns subscribe `
  --topic-arn $TOPIC_ARN `
  --protocol email `
  --notification-endpoint $YOUR_EMAIL

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Email subscription created" -ForegroundColor Green
    Write-Host "`n⚠️  IMPORTANT: Check your email ($YOUR_EMAIL) and click the confirmation link!" -ForegroundColor Yellow
    Write-Host "Press Enter after confirming email..." -ForegroundColor Cyan
    Read-Host
} else {
    Write-Host "❌ Failed to subscribe email" -ForegroundColor Red
    exit 1
}

Write-Host "`n3. Verifying subscription..." -ForegroundColor Yellow
$SUBSCRIPTIONS = aws sns list-subscriptions-by-topic --topic-arn $TOPIC_ARN --output json | ConvertFrom-Json

$CONFIRMED = $false
foreach ($sub in $SUBSCRIPTIONS.Subscriptions) {
    if ($sub.Protocol -eq "email" -and $sub.SubscriptionArn -ne "PendingConfirmation") {
        Write-Host "✅ Email subscription confirmed!" -ForegroundColor Green
        $CONFIRMED = $true
    }
}

if (-not $CONFIRMED) {
    Write-Host "⚠️  Email not confirmed yet. Please check your inbox!" -ForegroundColor Yellow
}

Write-Host "`n=== SNS Topic Setup Complete ===" -ForegroundColor Cyan
Write-Host "`nSNS Topic ARN: $TOPIC_ARN" -ForegroundColor White
Write-Host "`nNext step: Update setup-alarms.ps1 with this ARN, then run:" -ForegroundColor Yellow
Write-Host ".\setup-alarms.ps1" -ForegroundColor White
