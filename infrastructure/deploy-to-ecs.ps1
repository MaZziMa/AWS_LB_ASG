# Deploy to ECS Script
# Automatically build, push, and deploy Docker containers to AWS ECS

param(
    [string]$Environment = "production",
    [string]$Region = "us-east-1",
    [string]$AccountId = "171308902397",
    [string]$ClusterName = "course-reg-cluster",
    [string]$ServiceName = "course-reg-backend-service"
)

Write-Host "=== Deploying Course Registration to AWS ECS ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region`n" -ForegroundColor Yellow

$ErrorActionPreference = "Stop"
$ECR_URI = "$AccountId.dkr.ecr.$Region.amazonaws.com"

# Step 1: Build Docker images
Write-Host "[1/6] Building Docker images..." -ForegroundColor Green

Write-Host "  - Building backend..." -ForegroundColor Gray
Set-Location backend
docker build -t course-reg-backend:latest . --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Backend build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  - Building frontend..." -ForegroundColor Gray
Set-Location ../frontend
docker build -t course-reg-frontend:latest . --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Frontend build failed!" -ForegroundColor Red
    exit 1
}

Set-Location ..
Write-Host "  [OK] Images built successfully" -ForegroundColor Green

# Step 2: Login to ECR
Write-Host "`n[2/6] Logging in to Amazon ECR..." -ForegroundColor Green
$loginCommand = aws ecr get-login-password --region $Region
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get ECR login password!" -ForegroundColor Red
    exit 1
}

$loginCommand | docker login --username AWS --password-stdin $ECR_URI 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ECR login failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] ECR login successful" -ForegroundColor Green

# Step 3: Tag and push images
Write-Host "`n[3/6] Pushing images to ECR..." -ForegroundColor Green

Write-Host "  - Tagging backend..." -ForegroundColor Gray
docker tag course-reg-backend:latest $ECR_URI/course-reg-backend:latest
docker tag course-reg-backend:latest $ECR_URI/course-reg-backend:$Environment

Write-Host "  - Pushing backend..." -ForegroundColor Gray
docker push $ECR_URI/course-reg-backend:latest --quiet
docker push $ECR_URI/course-reg-backend:$Environment --quiet

Write-Host "  - Tagging frontend..." -ForegroundColor Gray
docker tag course-reg-frontend:latest $ECR_URI/course-reg-frontend:latest
docker tag course-reg-frontend:latest $ECR_URI/course-reg-frontend:$Environment

Write-Host "  - Pushing frontend..." -ForegroundColor Gray
docker push $ECR_URI/course-reg-frontend:latest --quiet
docker push $ECR_URI/course-reg-frontend:$Environment --quiet

Write-Host "  [OK] Images pushed to ECR" -ForegroundColor Green

# Step 4: Update task definition
Write-Host "`n[4/6] Registering new task definition..." -ForegroundColor Green

$taskDefPath = "infrastructure\ecs-task-definition.json"
if (Test-Path $taskDefPath) {
    $TASK_DEF_ARN = aws ecs register-task-definition --cli-input-json "file://$taskDefPath" --query 'taskDefinition.taskDefinitionArn' --output text
    
    if ($TASK_DEF_ARN) {
        Write-Host "  [OK] Task definition registered: $TASK_DEF_ARN" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Task definition registration failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ! Task definition file not found, skipping..." -ForegroundColor Yellow
}

# Step 5: Update ECS service
Write-Host "`n[5/6] Updating ECS service..." -ForegroundColor Green

try {
    $serviceExists = aws ecs describe-services --cluster $ClusterName --services $ServiceName --query 'services[0].serviceName' --output text 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $serviceExists -and $serviceExists -ne "None" -and $TASK_DEF_ARN) {
        $updateResult = aws ecs update-service --cluster $ClusterName --service $ServiceName --task-definition $TASK_DEF_ARN --force-new-deployment --query 'service.serviceName' --output text 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Service update initiated" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Service update failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ! Service '$ServiceName' not found, skipping update..." -ForegroundColor Yellow
        Write-Host "  Create the service first with: aws ecs create-service..." -ForegroundColor Gray
    }
} catch {
    Write-Host "  ! Service not found or cluster doesn't exist, skipping..." -ForegroundColor Yellow
}

# Step 6: Wait for deployment (optional)
Write-Host "`n[6/6] Waiting for deployment to stabilize..." -ForegroundColor Green
Write-Host "  (This may take 5-10 minutes)" -ForegroundColor Gray

try {
    $checkService = aws ecs describe-services --cluster $ClusterName --services $ServiceName --query 'services[0].serviceName' --output text 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $checkService -and $checkService -ne "None") {
        $timeout = 600
        $elapsed = 0
        $interval = 15
        
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            
            try {
                $deploymentJson = aws ecs describe-services --cluster $ClusterName --services $ServiceName --query 'services[0].deployments[0]' 2>&1
                $deployment = $deploymentJson | ConvertFrom-Json
                
                $running = $deployment.runningCount
                $desired = $deployment.desiredCount
                $status = $deployment.rolloutState
                
                Write-Host "  Status: $status | Running: $running/$desired | Elapsed: $elapsed`s" -ForegroundColor Cyan
                
                if ($status -eq "COMPLETED") {
                    Write-Host "  [OK] Deployment completed successfully!" -ForegroundColor Green
                    break
                }
                
                if ($status -eq "FAILED") {
                    Write-Host "  [FAILED] Deployment failed!" -ForegroundColor Red
                    exit 1
                }
            } catch {
                Write-Host "  ! Error checking deployment status" -ForegroundColor Yellow
                break
            }
        }
        
        if ($elapsed -ge $timeout) {
            Write-Host "  ! Deployment timeout reached" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Skipped (service not found)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Skipped (service not found)" -ForegroundColor Gray
}

# Summary
Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Backend Image: $ECR_URI/course-reg-backend:$Environment" -ForegroundColor White
Write-Host "Frontend Image: $ECR_URI/course-reg-frontend:$Environment" -ForegroundColor White
if ($TASK_DEF_ARN) {
    Write-Host "Task Definition: $TASK_DEF_ARN" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Check service status:" -ForegroundColor White
Write-Host "     aws ecs describe-services --cluster $ClusterName --services $ServiceName" -ForegroundColor Gray
Write-Host "`n  2. View logs:" -ForegroundColor White
Write-Host "     aws logs tail /ecs/course-registration --follow" -ForegroundColor Gray
Write-Host "`n  3. Test application:" -ForegroundColor White
Write-Host "     curl http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com/health" -ForegroundColor Gray

Write-Host "`n[SUCCESS] Deployment script completed!" -ForegroundColor Green
