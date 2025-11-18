# Git Security Guide - Prevent Committing Sensitive Data

## 🔐 Why This Matters

Committing sensitive data (credentials, keys, .env files) to git is a **critical security risk**:
- ❌ Anyone with repo access can see secrets
- ❌ Deleting the file doesn't remove from git history
- ❌ Public repos expose secrets to the world
- ❌ GitHub/GitLab scan for exposed keys and alert attackers

## ✅ What's Protected

### 1. Environment Files
```
.env
backend/.env
frontend/.env
*.env.local
```
**Safe:** `.env.example`, `.env.template`

### 2. AWS Credentials
```
~/.aws/credentials
~/.aws/config
```

### 3. Private Keys
```
*.pem        # SSH keys
*.key        # Private keys
*.p12, *.pfx # Certificates
*.ppk        # PuTTY keys
```

### 4. AWS Access Keys
```
AKIA[0-9A-Z]{16}  # AWS Access Key pattern
```

## 🛠️ Tools Available

### Quick Check (Manual)
```powershell
.\check-secrets.ps1
```
Scans tracked files for sensitive data.

### Setup Automated Protection
```powershell
.\setup-git-hooks.ps1
```
Installs git hooks that automatically check before every commit.

## 🚨 If You've Already Committed Secrets

### Step 1: Remove from Latest Commit
```bash
# If just committed (not pushed yet)
git reset HEAD~1
git rm --cached <sensitive-file>
echo "<sensitive-file>" >> .gitignore
git add .gitignore
git commit -m "Remove sensitive file"
```

### Step 2: Remove from Git History
```bash
# If already pushed - DANGER: Rewrites history!
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch backend/.env" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (coordinate with team!)
git push origin --force --all
```

### Step 3: Rotate All Exposed Credentials
**CRITICAL:** Anyone who pulled the repo has access to the old secrets!

#### AWS Keys
```bash
# Delete compromised keys
aws iam delete-access-key --access-key-id AKIA...

# Create new keys
aws iam create-access-key --user-name your-username
```

#### Database Passwords
```sql
-- Change database password
ALTER USER db_user WITH PASSWORD 'new_secure_password';
```

#### JWT Secret Keys
```bash
# Generate new secret
openssl rand -hex 32

# Update in AWS Parameter Store
aws ssm put-parameter --name /prod/secret-key --value "new-key" --overwrite
```

## ✅ Current .gitignore Protection

Your `.gitignore` already includes:
```gitignore
# Environment Variables
.env
.env.local
.env.*.local
*.env
backend/.env
frontend/.env

# AWS Credentials
.aws/
credentials
config

# Private Keys
*.pem
*.key
*.p12
*.pfx

# Logs and temp files
*.log
*.tmp
```

## 🔍 Checking What's Already Tracked

### List all tracked files
```bash
git ls-files
```

### Find specific patterns
```bash
# Check for .env files
git ls-files | findstr .env

# Check for keys
git ls-files | findstr ".pem .key"
```

### Remove accidentally tracked file
```bash
git rm --cached backend/.env
git commit -m "Remove .env from tracking"
```

## 🤖 Automated Scanning

### GitHub Actions (CI/CD)
Create `.github/workflows/security.yml`:
```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Check for secrets
        run: |
          if git ls-files | grep -E '\.env$|\.pem$|credentials$' | grep -v '\.example'; then
            echo "ERROR: Sensitive files detected"
            exit 1
          fi
      
      - name: Scan for AWS keys
        run: |
          if git grep -E 'AKIA[0-9A-Z]{16}'; then
            echo "ERROR: AWS key detected"
            exit 1
          fi
```

### Pre-commit Hook (Local)
Already set up with `setup-git-hooks.ps1`:
```bash
# Runs automatically before every commit
# Blocks commits containing:
#   - .env files
#   - .pem files  
#   - AWS access keys
#   - Database credentials
```

## 📝 Best Practices

### ✅ DO:
1. **Use .env.example** for templates
2. **Use AWS Parameter Store** for production secrets
3. **Use IAM roles** on EC2 (no hardcoded keys)
4. **Scan before every push**
5. **Review diffs** before committing

### ❌ DON'T:
1. **Never commit .env files**
2. **Never hardcode credentials** in code
3. **Never use --no-verify** to bypass hooks
4. **Never share credentials** in chat/docs
5. **Never commit private keys**

## 🔧 Quick Commands

### Before Committing
```powershell
# Check for secrets
.\check-secrets.ps1

# Review what you're committing
git diff --staged

# Check git status
git status
```

### If Hook Blocks You
```bash
# See what triggered the block
git diff --cached

# Unstage the sensitive file
git reset HEAD <file>

# Remove from git entirely
git rm --cached <file>

# Add to .gitignore
echo "<file>" >> .gitignore
```

## 📚 Additional Tools

### gitleaks (Advanced scanning)
```bash
# Install
brew install gitleaks  # macOS
choco install gitleaks # Windows

# Scan repo
gitleaks detect --source . --verbose
```

### git-secrets (AWS official)
```bash
# Install
git clone https://github.com/awslabs/git-secrets

# Setup
git secrets --install
git secrets --register-aws
```

## 🆘 Emergency Response

If you discover exposed secrets in a public repo:

1. **Immediately rotate all credentials**
2. **Check CloudTrail for unauthorized access**
3. **Review billing for unusual charges**
4. **Remove from git history (see above)**
5. **Enable MFA on affected accounts**
6. **Scan for malware on affected systems**

## ✅ Verification

To verify your repo is clean:

```powershell
# Run full scan
.\check-secrets.ps1

# Check git history
git log --all --full-history --source -- backend/.env

# Search for patterns
git log -p | findstr "AKIA"
```

## 📞 Resources

- [GitHub: Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [AWS: What to do if credentials are exposed](https://aws.amazon.com/premiumsupport/knowledge-center/potential-account-compromise/)
- [OWASP: Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Remember:** Once a secret is committed to git, assume it's compromised. Always rotate!
