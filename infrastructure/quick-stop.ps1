# Quick Stop Script - Turn off all resources
# Usage: .\quick-stop.ps1           -> Stop instances only
#        .\quick-stop.ps1 -DeleteAll -> Delete everything

param([switch]$DeleteAll)

$asgName = "course-reg-asg"

if ($DeleteAll) {
    Write-Host "`n=== DELETE ALL RESOURCES ===" -ForegroundColor Red
    $confirm = Read-Host "Type DELETE to confirm"
    if ($confirm -ne "DELETE") { exit }
    
    Write-Host "`n[1/5] Deleting Auto Scaling Group..." -ForegroundColor Yellow
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asgName --force-delete
    Start-Sleep -Seconds 45
    
    Write-Host "[2/5] Deleting Load Balancer..." -ForegroundColor Yellow
    $albArn = aws elbv2 describe-load-balancers --names course-reg-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>$null
    if ($albArn) {
        aws elbv2 delete-load-balancer --load-balancer-arn $albArn
        Start-Sleep -Seconds 30
    }
    
    Write-Host "[3/5] Deleting Target Group..." -ForegroundColor Yellow
    $tgArn = aws elbv2 describe-target-groups --names course-reg-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>$null
    if ($tgArn) {
        aws elbv2 delete-target-group --target-group-arn $tgArn
    }
    
    Write-Host "[4/5] Deleting Launch Template..." -ForegroundColor Yellow
    aws ec2 delete-launch-template --launch-template-name course-reg-launch-template 2>$null
    
    Write-Host "[5/5] Deleting Security Groups..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $ec2Sg = aws ec2 describe-security-groups --filters Name=group-name,Values=course-reg-ec2-sg --query 'SecurityGroups[0].GroupId' --output text 2>$null
    $albSg = aws ec2 describe-security-groups --filters Name=group-name,Values=course-reg-alb-sg --query 'SecurityGroups[0].GroupId' --output text 2>$null
    if ($ec2Sg) { aws ec2 delete-security-group --group-id $ec2Sg 2>$null }
    if ($albSg) { aws ec2 delete-security-group --group-id $albSg 2>$null }
    
    Write-Host "`n✓ All resources deleted. Cost: $0/month" -ForegroundColor Green
    
} else {
    Write-Host "`n=== STOP INSTANCES ===" -ForegroundColor Cyan
    aws autoscaling set-desired-capacity --auto-scaling-group-name $asgName --desired-capacity 0
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ Instances will be terminated" -ForegroundColor Green
        Write-Host "Remaining cost: ~$17/month (ALB + EBS)" -ForegroundColor Yellow
        Write-Host "`nTo restart:" -ForegroundColor Cyan
        Write-Host "  aws autoscaling set-desired-capacity --auto-scaling-group-name $asgName --desired-capacity 1" -ForegroundColor Gray
    } else {
        Write-Host "`n✗ Failed. ASG may not exist." -ForegroundColor Red
    }
}
