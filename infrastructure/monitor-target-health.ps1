# Monitor target health until instances become healthy
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetGroupArn,
    [int]$MaxWaitMinutes = 15
)

$startTime = Get-Date
$timeout = $startTime.AddMinutes($MaxWaitMinutes)

Write-Host "`n=== Monitoring Target Health ===" -ForegroundColor Cyan
Write-Host "Target Group: $TargetGroupArn" -ForegroundColor Yellow
Write-Host "Max wait time: $MaxWaitMinutes minutes`n" -ForegroundColor Yellow

while ((Get-Date) -lt $timeout) {
    $health = aws elbv2 describe-target-health `
        --target-group-arn $TargetGroupArn | ConvertFrom-Json
    
    $targets = $health.TargetHealthDescriptions
    $totalTargets = $targets.Count
    $healthyTargets = ($targets | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
    $unhealthyTargets = ($targets | Where-Object { $_.TargetHealth.State -eq "unhealthy" }).Count
    $drainingTargets = ($targets | Where-Object { $_.TargetHealth.State -eq "draining" }).Count
    $initialTargets = ($targets | Where-Object { $_.TargetHealth.State -eq "initial" }).Count
    
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Elapsed: $elapsed min | " -NoNewline
    Write-Host "Healthy: $healthyTargets" -ForegroundColor Green -NoNewline
    Write-Host " | Unhealthy: $unhealthyTargets" -ForegroundColor $(if ($unhealthyTargets -gt 0) { "Red" } else { "Gray" }) -NoNewline
    Write-Host " | Initial: $initialTargets" -ForegroundColor Yellow -NoNewline
    Write-Host " | Draining: $drainingTargets" -ForegroundColor Gray
    
    # Show details for unhealthy targets
    foreach ($target in $targets | Where-Object { $_.TargetHealth.State -ne "healthy" }) {
        $instanceId = $target.Target.Id
        $state = $target.TargetHealth.State
        $reason = $target.TargetHealth.Reason
        $description = $target.TargetHealth.Description
        
        Write-Host "    $instanceId : $state - $reason" -ForegroundColor $(
            switch ($state) {
                "initial" { "Yellow" }
                "unhealthy" { "Red" }
                "draining" { "Gray" }
                default { "White" }
            }
        )
    }
    
    # Check if all targets are healthy
    if ($healthyTargets -eq $totalTargets -and $totalTargets -gt 0) {
        Write-Host "`nSUCCESS: All targets are healthy!" -ForegroundColor Green
        Write-Host "Total time: $elapsed minutes`n" -ForegroundColor Green
        exit 0
    }
    
    # Wait before next check
    Start-Sleep -Seconds 30
}

Write-Host "`nTIMEOUT: Not all targets became healthy within $MaxWaitMinutes minutes" -ForegroundColor Red
Write-Host "Final status: $healthyTargets/$totalTargets healthy`n" -ForegroundColor Yellow
exit 1
