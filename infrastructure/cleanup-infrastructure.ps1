# Cleanup AWS Infrastructure
# PowerShell script - Chạy: .\cleanup-infrastructure.ps1
# ⚠️  WARNING: This will DELETE all resources created by setup-infrastructure.ps1

Write-Host "=== AWS Infrastructure Cleanup ===" -ForegroundColor Red
Write-Host "⚠️  This will delete all EC2, ALB, and ASG resources`n" -ForegroundColor Yellow

$confirmation = Read-Host "Type 'DELETE' to confirm"
if ($confirmation -ne "DELETE") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

$PROJECT_NAME = "course-reg"
$REGION = "us-east-1"

Write-Host "`n1. Deleting Auto Scaling Group..." -ForegroundColor Yellow
try {
    aws autoscaling delete-auto-scaling-group `
        --auto-scaling-group-name "$PROJECT_NAME-asg" `
        --force-delete `
        --region $REGION
    Write-Host "  ✓ Deleted ASG" -ForegroundColor Green
    
    # Wait for instances to terminate
    Write-Host "  Waiting for instances to terminate..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
} catch {
    Write-Host "  ⚠️  ASG not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n2. Deleting Load Balancer..." -ForegroundColor Yellow
try {
    # Get ALB ARN
    $ALB_ARN = aws elbv2 describe-load-balancers `
        --names "$PROJECT_NAME-alb" `
        --query 'LoadBalancers[0].LoadBalancerArn' `
        --output text `
        --region $REGION
    
    if ($ALB_ARN -and $ALB_ARN -ne "None") {
        aws elbv2 delete-load-balancer `
            --load-balancer-arn $ALB_ARN `
            --region $REGION
        Write-Host "  ✓ Deleted ALB" -ForegroundColor Green
        
        # Wait for ALB to be deleted
        Write-Host "  Waiting for ALB to be deleted..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    }
} catch {
    Write-Host "  ⚠️  ALB not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n3. Deleting Target Group..." -ForegroundColor Yellow
try {
    $TG_ARN = aws elbv2 describe-target-groups `
        --names "$PROJECT_NAME-tg" `
        --query 'TargetGroups[0].TargetGroupArn' `
        --output text `
        --region $REGION
    
    if ($TG_ARN -and $TG_ARN -ne "None") {
        aws elbv2 delete-target-group `
            --target-group-arn $TG_ARN `
            --region $REGION
        Write-Host "  ✓ Deleted Target Group" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Target Group not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n4. Deleting Launch Template..." -ForegroundColor Yellow
try {
    aws ec2 delete-launch-template `
        --launch-template-name "$PROJECT_NAME-launch-template" `
        --region $REGION
    Write-Host "  ✓ Deleted Launch Template" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Launch Template not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n5. Deleting Security Groups..." -ForegroundColor Yellow
try {
    # Get SG IDs
    $ALB_SG = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$PROJECT_NAME-alb-sg" `
        --query 'SecurityGroups[0].GroupId' `
        --output text `
        --region $REGION
    
    $EC2_SG = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$PROJECT_NAME-ec2-sg" `
        --query 'SecurityGroups[0].GroupId' `
        --output text `
        --region $REGION
    
    # Wait a bit to ensure resources are detached
    Start-Sleep -Seconds 10
    
    if ($EC2_SG -and $EC2_SG -ne "None") {
        aws ec2 delete-security-group --group-id $EC2_SG --region $REGION
        Write-Host "  ✓ Deleted EC2 Security Group" -ForegroundColor Green
    }
    
    if ($ALB_SG -and $ALB_SG -ne "None") {
        aws ec2 delete-security-group --group-id $ALB_SG --region $REGION
        Write-Host "  ✓ Deleted ALB Security Group" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Security Groups may still have dependencies. Wait a few minutes and try:" -ForegroundColor Yellow
    Write-Host "     aws ec2 delete-security-group --group-id $EC2_SG --region $REGION" -ForegroundColor White
    Write-Host "     aws ec2 delete-security-group --group-id $ALB_SG --region $REGION" -ForegroundColor White
}

Write-Host "`n6. Removing IAM Role..." -ForegroundColor Yellow
try {
    # Detach policies
    aws iam detach-role-policy `
        --role-name "$PROJECT_NAME-ec2-role" `
        --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
    
    aws iam detach-role-policy `
        --role-name "$PROJECT_NAME-ec2-role" `
        --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
    
    aws iam detach-role-policy `
        --role-name "$PROJECT_NAME-ec2-role" `
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
    
    # Remove role from instance profile
    aws iam remove-role-from-instance-profile `
        --instance-profile-name "$PROJECT_NAME-ec2-instance-profile" `
        --role-name "$PROJECT_NAME-ec2-role"
    
    # Delete instance profile
    aws iam delete-instance-profile `
        --instance-profile-name "$PROJECT_NAME-ec2-instance-profile"
    
    # Delete role
    aws iam delete-role --role-name "$PROJECT_NAME-ec2-role"
    
    Write-Host "  ✓ Deleted IAM Role and Instance Profile" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  IAM resources not found or already deleted" -ForegroundColor Yellow
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host "`nRemaining manual steps (if needed):" -ForegroundColor Yellow
Write-Host "  1. Delete DynamoDB tables if no longer needed" -ForegroundColor White
Write-Host "  2. Delete CloudWatch log groups: /aws/ec2/course-registration/*" -ForegroundColor White
Write-Host "  3. Delete SNS topics and subscriptions" -ForegroundColor White
Write-Host "  4. Delete CloudWatch alarms and dashboards" -ForegroundColor White
Write-Host "  5. Review CloudWatch costs" -ForegroundColor White
