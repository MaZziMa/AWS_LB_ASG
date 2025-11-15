# Course Registration System - Backend

Python backend built with FastAPI, SQLAlchemy, Redis, and AWS services.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Setup Environment

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Run Database Migrations

```bash
# Initialize database
alembic init alembic
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head
```

### 4. Run Application

```bash
# Development
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## 📁 Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── config.py          # Configuration settings
│   ├── database.py        # Database connection
│   ├── cache.py           # Redis cache management
│   ├── models.py          # SQLAlchemy models
│   ├── schemas.py         # Pydantic schemas
│   ├── auth.py            # Authentication & JWT
│   ├── aws.py             # AWS services (SQS, CloudWatch, S3)
│   ├── api/
│   │   ├── auth.py        # Auth endpoints
│   │   ├── courses.py     # Course endpoints
│   │   └── enrollments.py # Enrollment endpoints
│   └── services/
│       └── enrollment_service.py  # Business logic
├── main.py                # FastAPI application
├── requirements.txt       # Python dependencies
└── .env.example           # Environment variables template
```

## 🔑 Key Features

### 1. Auto Scaling Support
- Health check endpoint `/health` for ALB
- Prometheus metrics at `/metrics`
- CloudWatch custom metrics integration

### 2. High Performance
- Redis caching for frequently accessed data
- Database connection pooling
- Async/await throughout

### 3. Enrollment Flow
- Transaction-based enrollment
- Distributed locking via Redis
- Prerequisite checking
- Schedule conflict detection
- Automatic waitlist management

### 4. AWS Integration
- SQS for async processing
- CloudWatch for monitoring
- S3 for file storage
- SES for email notifications

## 📊 API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `GET /api/auth/me` - Get current user
- `POST /api/auth/refresh` - Refresh token

### Courses
- `GET /api/courses` - List courses
- `GET /api/courses/{id}` - Get course detail
- `GET /api/courses/{id}/sections` - Get course sections

### Enrollments
- `POST /api/enrollments` - Register for course
- `DELETE /api/enrollments/{id}` - Drop course
- `GET /api/enrollments/my` - Get my enrollments
- `GET /api/enrollments/{id}/status` - Check status

### Health & Monitoring
- `GET /health` - Health check (for ALB)
- `GET /metrics` - Prometheus metrics

## 🔒 Security

- JWT authentication
- Password hashing (bcrypt)
- Rate limiting
- CORS protection
- SQL injection prevention (SQLAlchemy ORM)

## 🐳 Docker Support

```dockerfile
# Coming soon
```

## 📈 Monitoring

### CloudWatch Metrics
- EnrollmentSuccess
- EnrollmentError
- RequestCount
- ResponseTime

### Prometheus Metrics
- `http_requests_total`
- `http_request_duration_seconds`
- `enrollment_success_total`
- `enrollment_error_total`

## 🧪 Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=app tests/
```

## 📝 Environment Variables

See `.env.example` for all available configuration options.

Key variables:
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `SECRET_KEY` - JWT secret key
- `AWS_REGION` - AWS region
- `SQS_QUEUE_URL` - SQS queue URL

## 🚀 Deployment

### AWS EC2 with Auto Scaling

1. Create AMI with application installed
2. Configure Launch Template
3. Create Auto Scaling Group
4. Attach to Application Load Balancer

See `infrastructure/` directory for Terraform/CloudFormation templates.

## 📚 Documentation

- API Docs: `http://localhost:8000/api/docs`
- ReDoc: `http://localhost:8000/api/redoc`
- System Design: `../SYSTEM_DESIGN.md`

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run tests
4. Submit pull request

## 📄 License

MIT License
