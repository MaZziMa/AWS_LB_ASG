# Finish Cleanup - Delete remaining resources after ASG is deleted

Write-Host "=== Finishing Cleanup ===" -ForegroundColor Cyan
Write-Host "Deleting remaining resources...`n" -ForegroundColor Yellow

Write-Host "[1/4] Deleting Load Balancer..." -ForegroundColor Yellow
$albArn = aws elbv2 describe-load-balancers --names course-reg-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>$null
if ($albArn -and $albArn -ne 'None') {
    aws elbv2 delete-load-balancer --load-balancer-arn $albArn
    Write-Host "  ✓ ALB deletion initiated" -ForegroundColor Green
    Start-Sleep -Seconds 15
} else {
    Write-Host "  ⚠ ALB not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n[2/4] Deleting Target Group..." -ForegroundColor Yellow
$tgArn = aws elbv2 describe-target-groups --names course-reg-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>$null
if ($tgArn -and $tgArn -ne 'None') {
    aws elbv2 delete-target-group --target-group-arn $tgArn 2>$null
    Write-Host "  ✓ Target Group deleted" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Target Group not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n[3/4] Deleting Launch Template..." -ForegroundColor Yellow
aws ec2 delete-launch-template --launch-template-name course-reg-launch-template 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Launch Template deleted" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Launch Template not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n[4/4] Deleting Security Groups..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$ec2Sg = aws ec2 describe-security-groups --filters Name=group-name,Values=course-reg-ec2-sg --query 'SecurityGroups[0].GroupId' --output text 2>$null
if ($ec2Sg -and $ec2Sg -ne 'None') {
    aws ec2 delete-security-group --group-id $ec2Sg 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ EC2 Security Group deleted" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ EC2 SG still attached, retry in 30 seconds" -ForegroundColor Yellow
    }
}

$albSg = aws ec2 describe-security-groups --filters Name=group-name,Values=course-reg-alb-sg --query 'SecurityGroups[0].GroupId' --output text 2>$null
if ($albSg -and $albSg -ne 'None') {
    aws ec2 delete-security-group --group-id $albSg 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ ALB Security Group deleted" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ ALB SG still attached, will auto-delete later" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Cyan
Write-Host "✓ Main resources deleted" -ForegroundColor Green
Write-Host "`nOptional cleanup (manual):" -ForegroundColor Yellow
Write-Host "  1. S3 Bucket (deployment files)" -ForegroundColor White
Write-Host "     aws s3 rb s3://course-reg-deployment-* --force" -ForegroundColor Gray
Write-Host "  2. DynamoDB Tables (your data)" -ForegroundColor White
Write-Host "     aws dynamodb list-tables | grep CourseReg" -ForegroundColor Gray
Write-Host "  3. CloudWatch Log Groups" -ForegroundColor White
Write-Host "     /aws/course-registration" -ForegroundColor Gray
Write-Host "  4. SSH Key Pair" -ForegroundColor White
Write-Host "     aws ec2 delete-key-pair --key-name course-reg-key" -ForegroundColor Gray

Write-Host "`n💰 Monthly cost after cleanup: ~$0" -ForegroundColor Green
Write-Host "(DynamoDB charges only if you query data)" -ForegroundColor Gray
