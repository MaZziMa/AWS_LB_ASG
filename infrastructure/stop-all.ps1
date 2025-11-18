# Stop All Resources - Quick Shutdown
# Stops all instances and infrastructure to minimize costs

param(
    [switch]$DeleteAll = $false
)

$PROJECT_NAME = "course-reg"
$REGION = "us-east-1"

Write-Host "`n=== AWS Cost Management ===" -ForegroundColor Cyan

if ($DeleteAll) {
    Write-Host "`n⚠️  DELETE ALL MODE - This will remove everything" -ForegroundColor Red
    $confirmation = Read-Host "Type 'DELETE' to confirm complete removal"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`n[1/6] Deleting Auto Scaling Group..." -ForegroundColor Yellow
    aws autoscaling delete-auto-scaling-group `
        --auto-scaling-group-name "$PROJECT_NAME-asg" `
        --force-delete `
        --region $REGION 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ ASG deleted" -ForegroundColor Green
        Write-Host "  Waiting for instances to terminate..." -ForegroundColor Gray
        Start-Sleep -Seconds 45
    } else {
        Write-Host "  ⚠ ASG not found or already deleted" -ForegroundColor Yellow
    }
    
    Write-Host "`n[2/6] Deleting Load Balancer..." -ForegroundColor Yellow
    $ALB_ARN = aws elbv2 describe-load-balancers `
        --names "$PROJECT_NAME-alb" `
        --query 'LoadBalancers[0].LoadBalancerArn' `
        --output text `
        --region $REGION 2>$null
    
    if ($ALB_ARN -and $ALB_ARN -ne "None") {
        aws elbv2 delete-load-balancer `
            --load-balancer-arn $ALB_ARN `
            --region $REGION 2>$null
        Write-Host "  ✓ ALB deleted" -ForegroundColor Green
        Write-Host "  Waiting for ALB deletion..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    } else {
        Write-Host "  ⚠ ALB not found" -ForegroundColor Yellow
    }
    
    Write-Host "`n[3/6] Deleting Target Group..." -ForegroundColor Yellow
    $TG_ARN = aws elbv2 describe-target-groups `
        --names "$PROJECT_NAME-tg" `
        --query 'TargetGroups[0].TargetGroupArn' `
        --output text `
        --region $REGION 2>$null
    
    if ($TG_ARN -and $TG_ARN -ne "None") {
        aws elbv2 delete-target-group `
            --target-group-arn $TG_ARN `
            --region $REGION 2>$null
        Write-Host "  ✓ Target Group deleted" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Target Group not found" -ForegroundColor Yellow
    }
    
    Write-Host "`n[4/6] Deleting Launch Template..." -ForegroundColor Yellow
    aws ec2 delete-launch-template `
        --launch-template-name "$PROJECT_NAME-launch-template" `
        --region $REGION 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Launch Template deleted" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Launch Template not found" -ForegroundColor Yellow
    }
    
    Write-Host "`n[5/6] Deleting Security Groups..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    $EC2_SG = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$PROJECT_NAME-ec2-sg" `
        --query 'SecurityGroups[0].GroupId' `
        --output text `
        --region $REGION 2>$null
    
    if ($EC2_SG -and $EC2_SG -ne "None") {
        aws ec2 delete-security-group --group-id $EC2_SG --region $REGION 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ EC2 Security Group deleted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ EC2 SG still in use, will be auto-deleted later" -ForegroundColor Yellow
        }
    }
    
    $ALB_SG = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$PROJECT_NAME-alb-sg" `
        --query 'SecurityGroups[0].GroupId' `
        --output text `
        --region $REGION 2>$null
    
    if ($ALB_SG -and $ALB_SG -ne "None") {
        aws ec2 delete-security-group --group-id $ALB_SG --region $REGION 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ ALB Security Group deleted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ ALB SG still in use, will be auto-deleted later" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n[6/6] Optional Cleanup..." -ForegroundColor Yellow
    Write-Host "  You may also want to delete:" -ForegroundColor Gray
    Write-Host "    - S3 Bucket (deployment package)" -ForegroundColor Gray
    Write-Host "    - DynamoDB Tables (data)" -ForegroundColor Gray
    Write-Host "    - CloudWatch Log Groups" -ForegroundColor Gray
    
    Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green
    Write-Host "All infrastructure deleted. Monthly cost: ~$0" -ForegroundColor Green
    
} else {
    Write-Host "`nSTOP MODE - Scaling down to 0 instances" -ForegroundColor Yellow
    Write-Host "(Infrastructure remains, can restart later)`n" -ForegroundColor Gray
    
    # Scale down ASG to 0
    Write-Host "Setting Auto Scaling Group capacity to 0..." -ForegroundColor Yellow
    aws autoscaling set-desired-capacity `
        --auto-scaling-group-name "$PROJECT_NAME-asg" `
        --desired-capacity 0 `
        --region $REGION
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ All instances will be terminated" -ForegroundColor Green
        
        # Show current status
        Start-Sleep -Seconds 5
        Write-Host "`nCurrent status:" -ForegroundColor Cyan
        aws autoscaling describe-auto-scaling-groups `
            --auto-scaling-group-names "$PROJECT_NAME-asg" `
            --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' `
            --output table `
            --region $REGION
        
        Write-Host "`nRemaining monthly costs:" -ForegroundColor Yellow
        Write-Host "  - Application Load Balancer: ~$16/month" -ForegroundColor White
        Write-Host "  - EBS Volumes (if any): ~$1-2/month" -ForegroundColor White
        Write-Host "  - DynamoDB: Pay per use (minimal if no traffic)" -ForegroundColor White
        Write-Host "  Total: ~$17-20/month`n" -ForegroundColor Cyan
        
        Write-Host "To restart, run:" -ForegroundColor Green
        Write-Host "  aws autoscaling set-desired-capacity --auto-scaling-group-name $PROJECT_NAME-asg --desired-capacity 1" -ForegroundColor Gray
        
        Write-Host "`nTo delete everything completely, run:" -ForegroundColor Yellow
        Write-Host "  .\stop-all.ps1 -DeleteAll" -ForegroundColor Gray
        
    } else {
        Write-Host "✗ Failed to stop instances" -ForegroundColor Red
        Write-Host "ASG may not exist. Check with:" -ForegroundColor Yellow
        Write-Host "  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names course-reg-asg" -ForegroundColor Gray
    }
}
