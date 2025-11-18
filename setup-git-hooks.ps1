# Setup Git Hooks for Security
# Automatically checks for sensitive files before commit

Write-Host "`n=== Setting up Git Security Hooks ===" -ForegroundColor Cyan

# Check if git repo
if (-not (Test-Path ".git")) {
    Write-Host "Not a git repository!" -ForegroundColor Red
    exit 1
}

# Create hooks directory if needed
$hooksDir = ".git\hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir | Out-Null
}

# Create pre-commit hook
$preCommitHook = @'
#!/bin/sh
# Git pre-commit hook - Check for sensitive files

echo "Running security scan..."

# Check for sensitive files
sensitive_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.env$|\.pem$|\.key$|credentials$' | grep -v '\.example')

if [ -n "$sensitive_files" ]; then
    echo "ERROR: Attempting to commit sensitive files:"
    echo "$sensitive_files"
    echo ""
    echo "To fix:"
    echo "  git reset HEAD <file>   # Unstage the file"
    echo "  git rm --cached <file>  # Remove from git"
    exit 1
fi

# Check for AWS keys in staged files
if git diff --cached | grep -E 'AKIA[0-9A-Z]{16}' > /dev/null; then
    echo "ERROR: AWS Access Key detected in staged changes!"
    echo "Remove the key and rotate it immediately"
    exit 1
fi

echo "✓ Security scan passed"
exit 0
'@

$hookPath = "$hooksDir\pre-commit"
$preCommitHook | Out-File -FilePath $hookPath -Encoding ASCII

Write-Host "✓ Created pre-commit hook" -ForegroundColor Green

# Create pre-push hook  
$prePushHook = @'
#!/bin/sh
# Git pre-push hook - Final security check

echo "Running pre-push security check..."

# Check for sensitive files in entire repo
if git ls-files | grep -E '\.env$|\.pem$|credentials$' | grep -v '\.example' > /dev/null; then
    echo "WARNING: Sensitive files detected in repository"
    echo "Review before pushing to remote"
fi

exit 0
'@

$pushHookPath = "$hooksDir\pre-push"
$prePushHook | Out-File -FilePath $pushHookPath -Encoding ASCII

Write-Host "✓ Created pre-push hook" -ForegroundColor Green

# Create PowerShell wrapper (Windows compatibility)
$psWrapper = @'
# PowerShell wrapper for git hooks
$ErrorActionPreference = "Stop"

# Check for sensitive files
$staged = git diff --cached --name-only --diff-filter=ACM

$sensitive = $staged | Where-Object { 
    ($_ -match '\.env$' -or $_ -match '\.pem$' -or $_ -match '\.key$' -or $_ -match 'credentials$') -and 
    ($_ -notmatch '\.example')
}

if ($sensitive) {
    Write-Host "`nERROR: Attempting to commit sensitive files:" -ForegroundColor Red
    foreach ($file in $sensitive) {
        Write-Host "  ❌ $file" -ForegroundColor Red
    }
    Write-Host "`nTo fix:" -ForegroundColor Yellow
    Write-Host "  git reset HEAD <file>   # Unstage" -ForegroundColor Gray
    Write-Host "  git rm --cached <file>  # Remove from git`n" -ForegroundColor Gray
    exit 1
}

# Check staged content for AWS keys
$diff = git diff --cached
if ($diff -match 'AKIA[0-9A-Z]{16}') {
    Write-Host "`nERROR: AWS Access Key detected!" -ForegroundColor Red
    Write-Host "Remove and rotate the key immediately`n" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Security scan passed" -ForegroundColor Green
exit 0
'@

$psHookPath = "$hooksDir\pre-commit.ps1"
$psWrapper | Out-File -FilePath $psHookPath -Encoding UTF8

Write-Host "✓ Created PowerShell pre-commit hook" -ForegroundColor Green

Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host "`nHooks installed:" -ForegroundColor Cyan
Write-Host "  1. pre-commit    - Blocks commits with sensitive files" -ForegroundColor White
Write-Host "  2. pre-commit.ps1 - PowerShell version (Windows)" -ForegroundColor White
Write-Host "  3. pre-push      - Warning before push" -ForegroundColor White

Write-Host "`nTo manually run security check:" -ForegroundColor Yellow
Write-Host "  .\check-secrets.ps1" -ForegroundColor Gray

Write-Host "`nTo bypass hooks (NOT recommended):" -ForegroundColor Red
Write-Host "  git commit --no-verify" -ForegroundColor Gray

Write-Host "`n"
