#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick deployment script to update backend code on running instances
.DESCRIPTION
    Uses AWS Systems Manager to deploy code changes without SSH
#>

Write-Host "`n=== Quick Backend Deployment ===" -ForegroundColor Cyan
Write-Host "This will update the backend code on all running instances`n" -ForegroundColor Yellow

# Get running instances
Write-Host "Finding running instances..." -ForegroundColor Cyan
$instances = aws ec2 describe-instances `
    --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=*course*" `
    --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress]" `
    --output json --region us-east-1 | ConvertFrom-Json

if ($instances.Count -eq 0) {
    Write-Host "No running instances found!" -ForegroundColor Red
    exit 1
}

$instanceIds = @()
foreach ($reservation in $instances) {
    foreach ($instance in $reservation) {
        $instanceId = $instance[0]
        $publicIp = $instance[1]
        Write-Host "  Found: $instanceId ($publicIp)" -ForegroundColor Green
        $instanceIds += $instanceId
    }
}

# Create deployment commands
$commands = @'
#!/bin/bash
set -e

echo "=== Starting Backend Update ==="

# Navigate to backend directory
cd /opt/course-registration || exit 1

# Pull latest code
echo "Pulling latest code from GitHub..."
git pull origin main

# Restart service
echo "Restarting backend service..."
sudo systemctl restart course-registration

# Check status
echo "Checking service status..."
sudo systemctl status course-registration --no-pager

echo "=== Deployment Complete ==="
'@

# Save commands to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$commands | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

Write-Host "`nDeploying to $($instanceIds.Count) instance(s)..." -ForegroundColor Cyan

foreach ($instanceId in $instanceIds) {
    Write-Host "`n--- Deploying to $instanceId ---" -ForegroundColor Yellow
    
    # Send command via SSM
    $commandId = aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=$(Get-Content $tempFile -Raw)" `
        --region us-east-1 `
        --query "Command.CommandId" `
        --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed to send command to $instanceId" -ForegroundColor Red
        continue
    }
    
    Write-Host "  Command sent (ID: $commandId)" -ForegroundColor Green
    Write-Host "  Waiting for completion..." -ForegroundColor Gray
    
    # Wait for command to complete (max 60 seconds)
    $maxWait = 60
    $waited = 0
    $status = "Pending"
    
    while ($waited -lt $maxWait -and $status -in @("Pending", "InProgress")) {
        Start-Sleep -Seconds 2
        $waited += 2
        
        $status = aws ssm get-command-invocation `
            --command-id $commandId `
            --instance-id $instanceId `
            --region us-east-1 `
            --query "Status" `
            --output text 2>$null
        
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    
    Write-Host ""
    
    if ($status -eq "Success") {
        Write-Host "  ✓ Deployment successful" -ForegroundColor Green
        
        # Get output
        $output = aws ssm get-command-invocation `
            --command-id $commandId `
            --instance-id $instanceId `
            --region us-east-1 `
            --query "StandardOutputContent" `
            --output text
        
        Write-Host "  Output:" -ForegroundColor Gray
        Write-Host $output -ForegroundColor Gray
    } else {
        Write-Host "  ✗ Deployment failed (Status: $status)" -ForegroundColor Red
        
        # Get error output
        $errorOutput = aws ssm get-command-invocation `
            --command-id $commandId `
            --instance-id $instanceId `
            --region us-east-1 `
            --query "StandardErrorContent" `
            --output text
        
        Write-Host "  Error:" -ForegroundColor Red
        Write-Host $errorOutput -ForegroundColor Red
    }
}

# Cleanup
Remove-Item $tempFile -Force

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Backend code updated and services restarted" -ForegroundColor Green
Write-Host "`nNext: Run load test to verify performance improvement" -ForegroundColor Yellow
Write-Host "Expected: P50 under 500ms, P95 under 1s - 10-20x faster than before" -ForegroundColor Yellow
