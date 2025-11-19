#!/bin/bash
# EC2 User Data Script - Auto install Docker and run containers

set -e

# Install Docker
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /opt/course-reg
cd /opt/course-reg

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.9'

services:
  redis:
    image: redis:7
    container_name: course-reg-redis
    restart: always

  backend:
    image: 171308902397.dkr.ecr.us-east-1.amazonaws.com/course-reg-backend:latest
    container_name: course-reg-backend
    restart: always
    depends_on:
      - redis
    environment:
      APP_NAME: "Course Registration System"
      APP_VERSION: "1.0.0"
      DEBUG: "false"
      ENVIRONMENT: production
      HOST: 0.0.0.0
      PORT: "8000"
      WORKERS: "2"
      DYNAMODB_REGION: us-east-1
      DYNAMODB_ENDPOINT_URL: ""
      DYNAMODB_TABLE_PREFIX: CourseReg
      REDIS_URL: redis://redis:6379/0
      CORS_ORIGINS: '["http://localhost:3000","http://course-reg-frontend-8157.s3-website-us-east-1.amazonaws.com","https://d29n7tymvy4jvo.cloudfront.net"]'
      AWS_REGION: us-east-1
    ports:
      - "8000:8000"
EOF

# Login to ECR and pull image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 171308902397.dkr.ecr.us-east-1.amazonaws.com

# Pull and start services
docker-compose pull
docker-compose up -d

echo "Deployment completed successfully!"
