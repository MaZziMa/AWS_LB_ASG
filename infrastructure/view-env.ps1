# View Current Environment Configuration on EC2 Instance
# Shows .env file and running service status

param(
    [string]$InstanceIp,
    [string]$KeyFile = "..\course-reg-key.pem"
)

if (-not $InstanceIp) {
    # Try to get current instance IP from ASG
    Write-Host "Getting instance IP from Auto Scaling Group..." -ForegroundColor Gray
    $instanceId = aws autoscaling describe-auto-scaling-groups `
        --auto-scaling-group-names course-reg-asg `
        --query 'AutoScalingGroups[0].Instances[0].InstanceId' `
        --output text
    
    if ($instanceId -and $instanceId -ne "None") {
        $InstanceIp = aws ec2 describe-instances `
            --instance-ids $instanceId `
            --query 'Reservations[0].Instances[0].PublicIpAddress' `
            --output text
        
        Write-Host "Found instance: $instanceId ($InstanceIp)" -ForegroundColor Green
    } else {
        Write-Host "Usage: .\view-env.ps1 -InstanceIp <IP>" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n=== Environment Configuration ===" -ForegroundColor Cyan
Write-Host "Instance: $InstanceIp`n" -ForegroundColor Yellow

# View environment
ssh -i $KeyFile -o StrictHostKeyChecking=no "ec2-user@${InstanceIp}" @"
echo '=== Service Status ==='
sudo systemctl status course-registration --no-pager | head -15

echo -e '\n=== Environment Variables (.env) ==='
cat /opt/course-registration/backend/.env

echo -e '\n=== Application Info ==='
curl -s http://localhost:8000/health | python3 -m json.tool 2>/dev/null || echo 'Health endpoint not responding'

echo -e '\n=== Recent Logs (last 10 lines) ==='
sudo journalctl -u course-registration -n 10 --no-pager
"@
