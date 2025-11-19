# Setup ECS Infrastructure
# Creates ECS cluster, IAM roles, and service

param(
    [string]$Region = "us-east-1",
    [string]$ClusterName = "course-reg-cluster",
    [string]$ServiceName = "course-reg-backend-service",
    [string]$AccountId = "171308902397"
)

Write-Host "=== Setting Up ECS Infrastructure ===" -ForegroundColor Cyan
$ErrorActionPreference = "Continue"

# Read infrastructure config
$configPath = "infrastructure\infrastructure-config.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $vpcId = $config.VPC_ID
    $targetGroupArn = $config.TARGET_GROUP_ARN
    $securityGroupId = $config.EC2_SG_ID
    
    # Get subnets from VPC
    Write-Host "Getting subnets from VPC $vpcId..." -ForegroundColor Gray
    $subnetsJson = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query 'Subnets[*].SubnetId' --output json
    $subnetIds = $subnetsJson | ConvertFrom-Json
    
    if ($subnetIds.Count -lt 2) {
        Write-Host "[ERROR] Need at least 2 subnets for ECS service!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found $($subnetIds.Count) subnets" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Infrastructure config not found!" -ForegroundColor Red
    exit 1
}

# Step 1: Create ECS Task Execution Role
Write-Host "`n[1/5] Creating IAM roles..." -ForegroundColor Green

$taskExecRoleName = "ecsTaskExecutionRole"
$taskRoleName = "ecsTaskRole"

# Check if execution role exists
$execRoleExists = aws iam get-role --role-name $taskExecRoleName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating $taskExecRoleName..." -ForegroundColor Gray
    
    $trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@
    
    Set-Content -Path "infrastructure\ecs-trust-policy.json" -Value $trustPolicy
    
    aws iam create-role --role-name $taskExecRoleName --assume-role-policy-document file://infrastructure/ecs-trust-policy.json | Out-Null
    aws iam attach-role-policy --role-name $taskExecRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" | Out-Null
    
    Write-Host "  [OK] Created $taskExecRoleName" -ForegroundColor Green
} else {
    Write-Host "  [OK] $taskExecRoleName already exists" -ForegroundColor Green
}

# Check if task role exists
$taskRoleExists = aws iam get-role --role-name $taskRoleName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating $taskRoleName..." -ForegroundColor Gray
    
    aws iam create-role --role-name $taskRoleName --assume-role-policy-document file://infrastructure/ecs-trust-policy.json | Out-Null
    
    # Attach DynamoDB access policy
    $dynamoPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:${Region}:${AccountId}:table/CourseReg_*"
    }
  ]
}
"@
    
    Set-Content -Path "infrastructure\ecs-dynamodb-policy.json" -Value $dynamoPolicy
    aws iam put-role-policy --role-name $taskRoleName --policy-name DynamoDBAccess --policy-document file://infrastructure/ecs-dynamodb-policy.json | Out-Null
    
    Write-Host "  [OK] Created $taskRoleName" -ForegroundColor Green
} else {
    Write-Host "  [OK] $taskRoleName already exists" -ForegroundColor Green
}

# Wait for IAM roles to propagate
Write-Host "  Waiting for IAM roles to propagate..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Step 2: Check cluster
Write-Host "`n[2/5] Checking ECS cluster..." -ForegroundColor Green
$clusterExists = aws ecs describe-clusters --clusters $ClusterName --query 'clusters[0].status' --output text 2>&1

if ($clusterExists -eq "ACTIVE") {
    Write-Host "  [OK] Cluster $ClusterName is active" -ForegroundColor Green
} else {
    Write-Host "  Creating cluster..." -ForegroundColor Gray
    aws ecs create-cluster --cluster-name $ClusterName --region $Region | Out-Null
    Write-Host "  [OK] Created cluster $ClusterName" -ForegroundColor Green
}

# Step 3: Register task definition
Write-Host "`n[3/5] Registering task definition..." -ForegroundColor Green

$taskDefPath = "infrastructure\ecs-task-definition.json"
if (Test-Path $taskDefPath) {
    # Read and modify task definition for EC2 launch type
    $taskDef = Get-Content $taskDefPath | ConvertFrom-Json
    $taskDef.requiresCompatibilities = @("EC2")
    $taskDef.networkMode = "bridge"
    $taskDef | ConvertTo-Json -Depth 10 | Set-Content "infrastructure\ecs-task-definition-ec2.json"
    
    $TASK_DEF_ARN = aws ecs register-task-definition --cli-input-json "file://infrastructure/ecs-task-definition-ec2.json" --query 'taskDefinition.taskDefinitionArn' --output text
    
    if ($TASK_DEF_ARN) {
        Write-Host "  [OK] Task definition: $TASK_DEF_ARN" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to register task definition!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [ERROR] Task definition file not found!" -ForegroundColor Red
    exit 1
}

# Step 4: Create ECS target group
Write-Host "`n[4/6] Creating ECS target group..." -ForegroundColor Green

$ecsTargetGroupName = "course-reg-ecs-tg"
$ecsTargetGroupArn = aws elbv2 describe-target-groups --names $ecsTargetGroupName --query 'TargetGroups[0].TargetGroupArn' --output text 2>&1

if ($LASTEXITCODE -ne 0 -or $ecsTargetGroupArn -eq "None") {
    Write-Host "  Creating target group for ECS..." -ForegroundColor Gray
    
    $ecsTargetGroupArn = aws elbv2 create-target-group `
        --name $ecsTargetGroupName `
        --protocol HTTP `
        --port 8000 `
        --vpc-id $vpcId `
        --target-type ip `
        --health-check-path /health `
        --health-check-interval-seconds 30 `
        --health-check-timeout-seconds 5 `
        --healthy-threshold-count 2 `
        --unhealthy-threshold-count 3 `
        --query 'TargetGroups[0].TargetGroupArn' `
        --output text
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Target group created: $ecsTargetGroupArn" -ForegroundColor Green
        
        # Get ALB ARN
        $albArn = $config.ALB_ARN
        
        # Create listener rule for ECS target group
        Write-Host "  Adding listener rule..." -ForegroundColor Gray
        
        # Get existing listener
        $listenerArn = aws elbv2 describe-listeners --load-balancer-arn $albArn --query 'Listeners[0].ListenerArn' --output text
        
        # Modify default action to forward to ECS target group
        aws elbv2 modify-listener `
            --listener-arn $listenerArn `
            --default-actions "Type=forward,TargetGroupArn=$ecsTargetGroupArn" | Out-Null
        
        Write-Host "  [OK] Listener updated to use ECS target group" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to create target group!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [OK] Target group already exists: $ecsTargetGroupArn" -ForegroundColor Green
}

# Step 5: Create ECS service
Write-Host "`n[5/6] Creating ECS service..." -ForegroundColor Green

$serviceExists = aws ecs describe-services --cluster $ClusterName --services $ServiceName --query 'services[0].status' --output text 2>&1

if ($serviceExists -eq "ACTIVE" -or $serviceExists -eq "DRAINING") {
    Write-Host "  [OK] Service $ServiceName already exists" -ForegroundColor Green
} else {
    Write-Host "  Creating service..." -ForegroundColor Gray
    
    # Build subnet list (use first 2 subnets)
    $subnetList = $subnetIds[0..1] -join ","
    
    Write-Host "  Using subnets: $subnetList" -ForegroundColor Gray
    Write-Host "  Using security group: $securityGroupId" -ForegroundColor Gray
    Write-Host "  Using target group: $ecsTargetGroupArn" -ForegroundColor Gray
    
    aws ecs create-service `
        --cluster $ClusterName `
        --service-name $ServiceName `
        --task-definition $TASK_DEF_ARN `
        --desired-count 2 `
        --launch-type EC2 `
        --load-balancers "targetGroupArn=$ecsTargetGroupArn,containerName=backend,containerPort=8000" `
        --health-check-grace-period-seconds 60 `
        --region $Region | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Service created successfully" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to create service!" -ForegroundColor Red
        exit 1
    }
}

# Step 6: Wait for service to stabilize
Write-Host "`n[6/6] Waiting for service to stabilize..." -ForegroundColor Green
Write-Host "  (This may take 3-5 minutes)" -ForegroundColor Gray

$timeout = 300
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
        
        if ($running -eq $desired -and $running -gt 0) {
            Write-Host "  [OK] Service is stable!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  Waiting for service to start..." -ForegroundColor Gray
    }
}

# Summary
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Cluster: $ClusterName" -ForegroundColor White
Write-Host "Service: $ServiceName" -ForegroundColor White
Write-Host "Task Definition: $TASK_DEF_ARN" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Push Docker images: .\infrastructure\deploy-to-ecs.ps1" -ForegroundColor White
Write-Host "  2. Check service: aws ecs describe-services --cluster $ClusterName --services $ServiceName" -ForegroundColor White
Write-Host "  3. View logs: aws logs tail /ecs/course-registration --follow" -ForegroundColor White

Write-Host "`n[SUCCESS] ECS infrastructure setup completed!" -ForegroundColor Green
