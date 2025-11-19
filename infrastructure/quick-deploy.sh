#!/bin/bash
# Simple EC2 deployment - Run directly on instance

# Install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Install AWS CLI if needed
sudo yum install -y aws-cli

# Login to ECR
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 171308902397.dkr.ecr.us-east-1.amazonaws.com

# Pull image
sudo docker pull 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest

# Stop old container if exists
sudo docker stop course-reg-backend 2>/dev/null || true
sudo docker rm course-reg-backend 2>/dev/null || true

# Run backend container
sudo docker run -d \
  --name course-reg-backend \
  --restart always \
  -p 8000:8000 \
  -e APP_NAME="Course Registration System" \
  -e APP_VERSION="1.0.0" \
  -e DEBUG="false" \
  -e ENVIRONMENT="production" \
  -e HOST="0.0.0.0" \
  -e PORT="8000" \
  -e WORKERS="2" \
  -e DYNAMODB_REGION="us-east-1" \
  -e DYNAMODB_ENDPOINT_URL="" \
  -e DYNAMODB_TABLE_PREFIX="CourseReg" \
  -e AWS_REGION="us-east-1" \
  -e CORS_ORIGINS='["*"]' \
  171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest

echo "Waiting for app to start..."
sleep 10

# Test
curl http://localhost:8000/health

echo "Deployment complete!"
sudo docker ps
