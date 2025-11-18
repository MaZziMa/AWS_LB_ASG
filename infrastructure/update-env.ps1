# Update Environment Variables on Running EC2 Instance
# Updates .env file and restarts the application service

param(
    [string]$InstanceIp,
    [string]$KeyFile = "..\course-reg-key.pem",
    [hashtable]$EnvVars = @{}
)

if (-not $InstanceIp) {
    Write-Host "Usage: .\update-env.ps1 -InstanceIp <IP> -EnvVars @{VAR1='value1'; VAR2='value2'}" -ForegroundColor Yellow
    Write-Host "`nExample:" -ForegroundColor Cyan
    Write-Host "  .\update-env.ps1 -InstanceIp 34.207.173.116 -EnvVars @{" -ForegroundColor White
    Write-Host "      SQS_QUEUE_URL='https://sqs.us-east-1.amazonaws.com/123/queue'" -ForegroundColor White
    Write-Host "      DEBUG='True'" -ForegroundColor White
    Write-Host "  }" -ForegroundColor White
    exit 1
}

Write-Host "=== Updating Environment Variables ===" -ForegroundColor Cyan
Write-Host "Instance: $InstanceIp" -ForegroundColor Yellow
Write-Host "Variables to update: $($EnvVars.Count)" -ForegroundColor Yellow

# Build sed commands for each variable
$sedCommands = @()
foreach ($key in $EnvVars.Keys) {
    $value = $EnvVars[$key]
    Write-Host "  - $key = $value" -ForegroundColor Gray
    
    # Escape special characters for sed
    $escapedValue = $value -replace '/', '\/'
    $escapedValue = $escapedValue -replace '&', '\&'
    
    # sed command to update or append variable
    $sedCommands += "grep -q '^$key=' .env && sed -i 's|^$key=.*|$key=$escapedValue|' .env || echo '$key=$escapedValue' >> .env"
}

# Create temporary script
$updateScript = @"
#!/bin/bash
cd /opt/course-registration/backend

echo "Backing up current .env..."
sudo cp .env .env.backup

echo "Updating variables..."
$($sedCommands -join "`n")

echo "Restarting service..."
sudo systemctl restart course-registration

sleep 3

if systemctl is-active --quiet course-registration; then
    echo "✓ Service restarted successfully"
    echo "Current configuration:"
    cat .env
else
    echo "✗ Service failed to restart"
    echo "Restoring backup..."
    sudo cp .env.backup .env
    sudo systemctl restart course-registration
    echo "Logs:"
    sudo journalctl -u course-registration -n 20
    exit 1
fi
"@

$scriptPath = ".\temp-update-env.sh"
$updateScript | Out-File -FilePath $scriptPath -Encoding utf8 -NoNewline

# Upload and execute script
Write-Host "`n[1/3] Uploading update script..." -ForegroundColor Green
scp -i $KeyFile -o StrictHostKeyChecking=no $scriptPath "ec2-user@${InstanceIp}:/tmp/update-env.sh" 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to upload script" -ForegroundColor Red
    Remove-Item $scriptPath
    exit 1
}

Write-Host "[2/3] Executing update..." -ForegroundColor Green
ssh -i $KeyFile -o StrictHostKeyChecking=no "ec2-user@${InstanceIp}" "chmod +x /tmp/update-env.sh && sudo /tmp/update-env.sh && rm /tmp/update-env.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[3/3] ✓ Environment updated successfully" -ForegroundColor Green
} else {
    Write-Host "[3/3] ✗ Update failed" -ForegroundColor Red
}

# Cleanup
Remove-Item $scriptPath

Write-Host "`nTo verify, check application logs:" -ForegroundColor Yellow
Write-Host "  ssh -i $KeyFile ec2-user@$InstanceIp" -ForegroundColor White
Write-Host "  sudo journalctl -u course-registration -n 50" -ForegroundColor Gray
