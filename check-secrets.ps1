# Quick Security Scan - Check for sensitive files

Write-Host "`n=== Git Security Check ===" -ForegroundColor Cyan

$problems = @()

# Get tracked files
$tracked = git ls-files 2>$null

if (-not $tracked) {
    Write-Host "Not a git repository or no tracked files" -ForegroundColor Yellow
    exit 0
}

Write-Host "Checking $($tracked.Count) files...`n" -ForegroundColor Gray

# Check for dangerous files
$dangerousPatterns = @(
    '\.env$',
    'backend/\.env',
    'frontend/\.env',
    'credentials$',
    '\.pem$',
    '\.key$', 
    '\.p12$',
    '\.pfx$',
    '\.ppk$'
)

foreach ($pattern in $dangerousPatterns) {
    $matches = $tracked | Where-Object { $_ -match $pattern -and $_ -notmatch '\.example' }
    if ($matches) {
        foreach ($file in $matches) {
            $problems += $file
        }
    }
}

# Check staged files
$staged = git diff --cached --name-only 2>$null
if ($staged) {
    foreach ($file in $staged) {
        foreach ($pattern in $dangerousPatterns) {
            if ($file -match $pattern) {
                $problems += "STAGED: $file"
            }
        }
    }
}

# Results
if ($problems.Count -gt 0) {
    Write-Host "🚨 SENSITIVE FILES DETECTED:" -ForegroundColor Red
    foreach ($file in $problems) {
        Write-Host "  ❌ $file" -ForegroundColor Red
    }
    
    Write-Host "`nTo remove from git:" -ForegroundColor Yellow
    Write-Host "  git rm --cached <filename>" -ForegroundColor Gray
    Write-Host "  git commit -m 'Remove sensitive file'" -ForegroundColor Gray
    
    exit 1
} else {
    Write-Host "✅ No sensitive files found" -ForegroundColor Green
    Write-Host "Safe to proceed`n" -ForegroundColor Green
    exit 0
}
