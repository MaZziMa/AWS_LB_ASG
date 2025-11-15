"""
Application Configuration
Loads from environment variables and .env file
"""
from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    """Application settings from environment variables"""
    
    # Application
    APP_NAME: str = "Course Registration System"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 4
    
    # DynamoDB
    DYNAMODB_REGION: str = "us-east-1"
    DYNAMODB_ENDPOINT_URL: str = ""  # Empty for AWS, set for local DynamoDB
    DYNAMODB_TABLE_PREFIX: str = "CourseReg"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_PASSWORD: str = ""
    REDIS_MAX_CONNECTIONS: int = 50
    
    # JWT
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # AWS
    AWS_REGION: str = "us-east-1"
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    
    # SQS
    SQS_QUEUE_URL: str = ""
    SQS_EMAIL_QUEUE_URL: str = ""
    
    # S3
    S3_BUCKET_NAME: str = ""
    
    # CloudWatch
    CLOUDWATCH_NAMESPACE: str = "CourseRegistration"
    CLOUDWATCH_LOG_GROUP: str = "/aws/course-registration"
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 100
    MAX_ENROLLMENT_PER_REQUEST: int = 5
    
    # CORS
    CORS_ORIGINS: List[str] = ["http://localhost:3000"]
    
    # Email
    SES_SENDER_EMAIL: str = "noreply@yourdomain.com"
    SES_REGION: str = "us-east-1"
    
    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    
    # Monitoring
    PROMETHEUS_PORT: int = 9090
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()
