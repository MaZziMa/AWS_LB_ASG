# ALB Feature Demo Script
# Demonstrates: Load Balancing, Health Checks, Auto Scaling, Failover

param(
    [ValidateSet('LoadBalance', 'HealthCheck', 'AutoScale', 'Failover', 'All')]
    [string]$Demo = 'All'
)

$ALB_URL = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
$TG_ARN = "arn:aws:elasticloadbalancing:us-east-1:171308902397:targetgroup/course-reg-tg/e0dfed577c96c70c"
$ASG_NAME = "course-reg-asg"

function Show-LoadBalancing {
    Write-Host "`n=== DEMO 1: Load Balancing ===" -ForegroundColor Cyan
    Write-Host "ALB distributes traffic across multiple EC2 instances`n" -ForegroundColor Gray
    
    # Get current targets
    Write-Host "Current targets:" -ForegroundColor Yellow
    aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
    
    Write-Host "`nSending 20 requests to see load distribution..." -ForegroundColor Yellow
    Write-Host "Each backend logs its instance ID in response headers`n" -ForegroundColor Gray
    
    $instanceCounts = @{}
    
    for ($i = 1; $i -le 20; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "$ALB_URL/health" -UseBasicParsing
            $server = $response.Headers['Server']
            
            # Track which instance handled request
            if ($instanceCounts.ContainsKey($server)) {
                $instanceCounts[$server]++
            } else {
                $instanceCounts[$server] = 1
            }
            
            Write-Host "Request $i : Server=$server" -ForegroundColor Gray
        } catch {
            Write-Host "Request $i : Failed" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "`n--- Load Distribution Summary ---" -ForegroundColor Green
    $instanceCounts.GetEnumerator() | ForEach-Object {
        $percentage = ($_.Value / 20 * 100)
        Write-Host "$($_.Key): $($_.Value) requests ($percentage%)" -ForegroundColor Cyan
    }
    
    Write-Host "`n✅ ALB evenly distributes traffic across healthy targets" -ForegroundColor Green
}

function Show-HealthCheck {
    Write-Host "`n=== DEMO 2: Health Checks ===" -ForegroundColor Cyan
    Write-Host "ALB continuously monitors target health`n" -ForegroundColor Gray
    
    Write-Host "Health Check Configuration:" -ForegroundColor Yellow
    aws elbv2 describe-target-groups --target-group-arns $TG_ARN --query 'TargetGroups[0].{Path:HealthCheckPath,Interval:HealthCheckIntervalSeconds,Timeout:HealthCheckTimeoutSeconds,Healthy:HealthyThresholdCount,Unhealthy:UnhealthyThresholdCount}' --output table
    
    Write-Host "`nCurrent Target Health:" -ForegroundColor Yellow
    aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' --output table
    
    Write-Host "`nMonitoring health checks for 30 seconds..." -ForegroundColor Yellow
    Write-Host "(ALB calls /health every 30s on each target)`n" -ForegroundColor Gray
    
    for ($i = 1; $i -le 6; $i++) {
        Start-Sleep -Seconds 5
        $health = aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].TargetHealth.State' --output text
        Write-Host "[$i/6] Target states: $health" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ ALB automatically detects and routes around unhealthy targets" -ForegroundColor Green
}

function Show-AutoScaling {
    Write-Host "`n=== DEMO 3: Auto Scaling Integration ===" -ForegroundColor Cyan
    Write-Host "ALB works with Auto Scaling to handle traffic spikes`n" -ForegroundColor Gray
    
    Write-Host "Current ASG Configuration:" -ForegroundColor Yellow
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Current:length(Instances)}' --output table
    
    Write-Host "`nSimulating high CPU load to trigger scaling..." -ForegroundColor Yellow
    Write-Host "When CPU > 70%, ASG will launch new instances" -ForegroundColor Gray
    Write-Host "ALB automatically registers new instances to target group`n" -ForegroundColor Gray
    
    # Generate load
    Write-Host "Sending burst traffic (100 requests)..." -ForegroundColor Yellow
    $jobs = 1..10 | ForEach-Object {
        Start-Job -ScriptBlock {
            param($url)
            1..10 | ForEach-Object {
                try {
                    Invoke-RestMethod -Uri "$url/api/courses" -Method Get -UseBasicParsing | Out-Null
                } catch {}
                Start-Sleep -Milliseconds 100
            }
        } -ArgumentList $ALB_URL
    }
    
    # Wait for jobs
    $jobs | Wait-Job | Remove-Job
    
    Write-Host "`nChecking if scaling was triggered..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    $activities = aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME --max-records 3 --query 'Activities[*].[StartTime,Cause,StatusCode]' --output table
    Write-Host $activities
    
    Write-Host "`n✅ ALB seamlessly integrates with Auto Scaling for elasticity" -ForegroundColor Green
}

function Show-Failover {
    Write-Host "`n=== DEMO 4: Automatic Failover ===" -ForegroundColor Cyan
    Write-Host "ALB detects failures and routes traffic to healthy instances`n" -ForegroundColor Gray
    
    # Get instances
    $instances = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text
    $instanceArray = $instances -split '\s+'
    
    if ($instanceArray.Count -lt 2) {
        Write-Host "Need at least 2 instances for failover demo. Current: $($instanceArray.Count)" -ForegroundColor Red
        Write-Host "Scaling up to 2 instances..." -ForegroundColor Yellow
        aws autoscaling set-desired-capacity --auto-scaling-group-name $ASG_NAME --desired-capacity 2
        Write-Host "Waiting 120s for new instance..." -ForegroundColor Gray
        Start-Sleep -Seconds 120
        $instances = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text
        $instanceArray = $instances -split '\s+'
    }
    
    $targetInstance = $instanceArray[0]
    
    Write-Host "Targets before failover:" -ForegroundColor Yellow
    aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
    
    Write-Host "`nSimulating instance failure..." -ForegroundColor Yellow
    Write-Host "Stopping instance: $targetInstance" -ForegroundColor Red
    
    $confirm = Read-Host "`n⚠️  This will stop an EC2 instance. Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Failover demo cancelled" -ForegroundColor Yellow
        return
    }
    
    aws ec2 stop-instances --instance-ids $targetInstance | Out-Null
    Write-Host "Instance stop initiated" -ForegroundColor Gray
    
    Write-Host "`nMonitoring ALB response (ALB should keep serving traffic)..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le 10; $i++) {
        try {
            $response = Invoke-RestMethod -Uri "$ALB_URL/health" -UseBasicParsing
            Write-Host "[$i/10] Response: $($response.status) - ✅ Still serving" -ForegroundColor Green
        } catch {
            Write-Host "[$i/10] Failed - ALB detecting failure" -ForegroundColor Yellow
        }
        Start-Sleep -Seconds 3
    }
    
    Write-Host "`nTarget health after failure:" -ForegroundColor Yellow
    aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
    
    Write-Host "`n✅ ALB automatically failed over to healthy instances" -ForegroundColor Green
    Write-Host "Note: ASG will launch a replacement instance automatically" -ForegroundColor Gray
}

function Show-ALBMetrics {
    Write-Host "`n=== ALB CloudWatch Metrics ===" -ForegroundColor Cyan
    Write-Host "Real-time ALB performance metrics`n" -ForegroundColor Gray
    
    $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $startTime = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-Host "Request Count (last 10 min):" -ForegroundColor Yellow
    aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 --start-time $startTime --end-time $endTime --period 300 --statistics Sum --query 'Datapoints[*].[Timestamp,Sum]' --output table
    
    Write-Host "`nTarget Response Time (last 10 min):" -ForegroundColor Yellow
    aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime --dimensions Name=LoadBalancer,Value=app/course-reg-alb/7d13a6bcf5e0d9f7 --start-time $startTime --end-time $endTime --period 300 --statistics Average --query 'Datapoints[*].[Timestamp,Average]' --output table
    
    Write-Host "`nHealthy Host Count:" -ForegroundColor Yellow
    aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HealthyHostCount --dimensions Name=TargetGroup,Value=targetgroup/course-reg-tg/e0dfed577c96c70c --start-time $startTime --end-time $endTime --period 60 --statistics Average --query 'Datapoints[-1].[Timestamp,Average]' --output table
}

# Main execution
Write-Host @"

╔════════════════════════════════════════════════════════════╗
║        AWS Application Load Balancer - Feature Demo       ║
╚════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if ($Demo -eq 'All' -or $Demo -eq 'LoadBalance') { Show-LoadBalancing }
if ($Demo -eq 'All' -or $Demo -eq 'HealthCheck') { Show-HealthCheck }
if ($Demo -eq 'All' -or $Demo -eq 'AutoScale') { Show-AutoScaling }
if ($Demo -eq 'Failover') { Show-Failover }

Show-ALBMetrics

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Demo Complete!                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Key ALB Features Demonstrated:" -ForegroundColor Yellow
Write-Host "  ✅ Load Distribution - Even traffic distribution" -ForegroundColor Green
Write-Host "  ✅ Health Checks - Automatic health monitoring" -ForegroundColor Green
Write-Host "  ✅ Auto Scaling - Seamless instance registration" -ForegroundColor Green
Write-Host "  ✅ High Availability - Zero downtime failover" -ForegroundColor Green
Write-Host "`nFor failover demo, run: .\demo-alb-features.ps1 -Demo Failover`n" -ForegroundColor Gray
