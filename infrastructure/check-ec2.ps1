# Quick EC2 SSH and Status Check

$instanceIp = "34.230.83.2"
$keyFile = "course-reg-key.pem"

Write-Host "=== EC2 Instance Status Check ===" -ForegroundColor Cyan
Write-Host "Instance IP: $instanceIp`n" -ForegroundColor Yellow

Write-Host "To SSH into instance:" -ForegroundColor Green
Write-Host "ssh -i $keyFile ec2-user@$instanceIp`n" -ForegroundColor White

Write-Host "Once connected, run these commands to check status:" -ForegroundColor Green
Write-Host @"

# Check user-data execution logs
sudo cat /var/log/cloud-init-output.log | tail -50

# Check if Docker is installed
docker --version

# Check running containers
sudo docker ps

# Check Docker logs
sudo docker logs course-reg-backend

# Test app locally
curl http://localhost:8000/health

# Check if port 8000 is listening
sudo netstat -tlnp | grep 8000

"@ -ForegroundColor Gray

Write-Host "`nCommon fixes if app is not running:" -ForegroundColor Yellow
Write-Host @"

1. If Docker not installed, install manually:
   sudo yum install -y docker
   sudo systemctl start docker

2. If image not pulled, login and pull:
   aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 171308902397.dkr.ecr.us-east-1.amazonaws.com
   sudo docker pull 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest

3. Run container manually:
   sudo docker run -d -p 8000:8000 \
     -e DYNAMODB_REGION=us-east-1 \
     -e DYNAMODB_TABLE_PREFIX=CourseReg \
     -e AWS_REGION=us-east-1 \
     171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest

"@ -ForegroundColor White
