# 🚀 How to Run - Course Registration System

## Hướng Dẫn Chạy Ứng Dụng

---

## 📋 Yêu Cầu Hệ Thống

### Phần Mềm Cần Thiết:
- ✅ **Python 3.11+** 
- ✅ **Git**
- ✅ **AWS Account** (hoặc DynamoDB Local cho dev)
- ⚠️ **Redis** (optional - ứng dụng vẫn chạy được không có Redis)

### Tùy Chọn:
- **DynamoDB Local** - Cho môi trường development
- **Docker** - Để chạy Redis và DynamoDB Local

---

## 🔧 Bước 1: Clone Repository

```bash
git clone https://github.com/MaZziMa/AWS_LB_ASG.git
cd AWS_LB_ASG
```

---

## 🐍 Bước 2: Setup Python Environment

### Windows:

```powershell
# Tạo virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Hoặc nếu dùng CMD
.\.venv\Scripts\activate.bat

# Cài đặt dependencies
cd backend
pip install -r requirements.txt

# Note: requirements.txt đã được tối ưu để tránh lỗi Rust compilation
# Sử dụng pre-built wheels cho tất cả packages
```

### Linux/Mac:

```bash
# Tạo virtual environment
python3 -m venv .venv

# Activate
source .venv/bin/activate

# Install dependencies
cd backend
pip install -r requirements.txt
```

### ⚠️ Troubleshooting Installation:

**Nếu gặp lỗi "Rust compiler required":**
```bash
# requirements.txt đã fix - chỉ cần install lại:
pip install --upgrade pip
pip install -r requirements.txt --no-cache-dir
```

---

## ⚙️ Bước 3: Cấu Hình Environment

### File `.env` đã có sẵn trong `backend/.env`:

```env
# Application
APP_NAME="Course Registration System"
APP_VERSION="1.0.0"
DEBUG=True
ENVIRONMENT=development

# Server
HOST=0.0.0.0
PORT=8000
WORKERS=1

# DynamoDB Configuration
DYNAMODB_REGION=us-east-1
DYNAMODB_ENDPOINT_URL=http://localhost:8000
DYNAMODB_TABLE_PREFIX=CourseReg

# Redis (Optional)
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=
REDIS_MAX_CONNECTIONS=50

# JWT Authentication
SECRET_KEY=your-secret-key-change-this-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

### Chỉnh Sửa Theo Environment:

#### **Option 1: Development với DynamoDB Local**
```env
DYNAMODB_ENDPOINT_URL=http://localhost:8000
AWS_ACCESS_KEY_ID=fakeMyKeyId
AWS_SECRET_ACCESS_KEY=fakeSecretAccessKey
```

#### **Option 2: Production với AWS DynamoDB**
```env
DYNAMODB_ENDPOINT_URL=
AWS_ACCESS_KEY_ID=your-real-access-key
AWS_SECRET_ACCESS_KEY=your-real-secret-key
```

---

## 🗄️ Bước 4: Setup Database (DynamoDB)

### Option A: DynamoDB Local (Development)

#### Sử dụng Docker:
```bash
docker run -p 8000:8000 amazon/dynamodb-local
```

#### Hoặc download JAR:
```bash
# Download
wget https://s3.us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.zip
unzip dynamodb_local_latest.zip

# Run
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb
```

### Option B: AWS DynamoDB (Production)

1. **Tạo AWS Account** và configure credentials:
```bash
aws configure
# AWS Access Key ID: [your-key]
# AWS Secret Access Key: [your-secret]
# Default region: us-east-1
```

2. **Tạo Tables** (chạy script này 1 lần):
```bash
cd backend
python -c "from app.dynamodb import db, init_tables; db.connect(); init_tables()"
```

---

## 📦 Bước 5: Setup Redis (Optional)

### Sử dụng Docker:
```bash
docker run -d -p 6379:6379 redis:7
```

### Hoặc cài đặt local:

**Windows:**
```bash
# Download Redis for Windows
# https://github.com/microsoftarchive/redis/releases
# Chạy redis-server.exe
```

**Linux:**
```bash
sudo apt-get install redis-server
sudo systemctl start redis
```

**Mac:**
```bash
brew install redis
brew services start redis
```

**⚠️ Note:** Ứng dụng sẽ chạy được ngay cả khi không có Redis (hiện warning nhưng không crash)

---

## 🚀 Bước 6: Chạy Application

### Method 1: Trực tiếp với Python

```bash
# Từ thư mục gốc AWS_LB_ASG
D:/AWS_LB_ASG/.venv/Scripts/python.exe backend/main.py

# Hoặc từ thư mục backend
cd backend
python main.py
```

### Method 2: Với uvicorn (recommended)

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Method 3: Với gunicorn (Production)

```bash
cd backend
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

---

## ✅ Bước 7: Verify Application

### 1. **Health Check**
```bash
curl http://localhost:8000/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

### 2. **API Documentation**

Mở browser và truy cập:
- **Swagger UI**: http://localhost:8000/api/docs
- **ReDoc**: http://localhost:8000/api/redoc

### 3. **Test API Endpoints**

```bash
# Root endpoint
curl http://localhost:8000/

# Metrics endpoint
curl http://localhost:8000/metrics

# Login (cần có user data trong DynamoDB)
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
```

---

## 📊 Console Output Mong Đợi

```
INFO:     Started server process [6696]
INFO:     Waiting for application startup.
2025-11-15 00:33:54,172 - main - INFO - Starting Course Registration System...
2025-11-15 00:33:54,173 - main - INFO - Environment: production
2025-11-15 00:33:54,173 - main - INFO - Version: 1.0.0
2025-11-15 00:33:54,442 - app.dynamodb - INFO - DynamoDB connected successfully
2025-11-15 00:33:54,442 - main - INFO - DynamoDB connected
2025-11-15 00:33:58,520 - app.cache - WARNING - Redis connection unavailable, continuing without cache
2025-11-15 00:33:58,520 - main - INFO - Redis connected
2025-11-15 00:33:58,521 - main - INFO - Application started successfully
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

---

## 🔍 Troubleshooting

### Problem 1: ModuleNotFoundError

**Error:**
```
ModuleNotFoundError: No module named 'fastapi'
```

**Solution:**
```bash
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

---

### Problem 2: DynamoDB Connection Error

**Error:**
```
ERROR - DynamoDB connection error
```

**Solution:**
1. Check DynamoDB Local is running:
```bash
curl http://localhost:8000
```

2. Or verify AWS credentials:
```bash
aws dynamodb list-tables --region us-east-1
```

3. Update `.env`:
```env
# For local
DYNAMODB_ENDPOINT_URL=http://localhost:8000

# For AWS
DYNAMODB_ENDPOINT_URL=
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

---

### Problem 3: Port Already in Use

**Error:**
```
OSError: [Errno 48] Address already in use
```

**Solution:**

**Windows:**
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill process
taskkill /PID <process_id> /F
```

**Linux/Mac:**
```bash
# Find and kill
lsof -ti:8000 | xargs kill -9

# Or change port in .env
PORT=8001
```

---

### Problem 4: Prometheus Duplicate Metrics

**Error:**
```
ValueError: Duplicated timeseries in CollectorRegistry
```

**Solution:** Đã được fix - Prometheus metrics đã disable, dùng CloudWatch thay thế.

---

### Problem 5: Redis Connection Warning

**Warning:**
```
WARNING - Redis connection unavailable, continuing without cache
```

**Solution:** 
- Đây chỉ là warning, app vẫn chạy bình thường
- Để tắt warning: Start Redis server
- Hoặc ignore nếu không cần cache

---

## 📚 Next Steps

### 1. **Seed Database với Test Data**

```bash
cd backend
python scripts/seed_database.py
```

### 2. **Create DynamoDB Tables**

```python
from app.dynamodb import db, init_tables

db.connect()
init_tables()
```

### 3. **Tạo User Admin đầu tiên**

```python
from app.dynamodb import put_item, Tables
from app.auth import hash_password
import uuid

admin_user = {
    'user_id': str(uuid.uuid4()),
    'username': 'admin',
    'email': 'admin@example.com',
    'password_hash': hash_password('admin123'),
    'full_name': 'System Administrator',
    'user_type': 'admin',
    'is_active': True
}

await put_item(Tables.USERS, admin_user)
```

### 4. **Monitor Application**

```bash
# CloudWatch Logs
aws logs tail /aws/course-registration --follow

# Check DynamoDB tables
aws dynamodb list-tables

# Monitor metrics
aws cloudwatch get-metric-statistics \
  --namespace CourseRegistration \
  --metric-name Requests \
  --start-time 2025-11-15T00:00:00Z \
  --end-time 2025-11-15T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

---

## 🌐 Deploy to Production

### AWS EC2 + ALB + ASG

Xem chi tiết trong `SYSTEM_DESIGN.md` và `IMPLEMENTATION_GUIDE.md`

**Quick Deploy:**
```bash
# 1. Create EC2 AMI with application
# 2. Setup Application Load Balancer
# 3. Create Auto Scaling Group (min:2, max:20)
# 4. Configure health check: /health
# 5. Setup CloudWatch alarms
```

---

## 🔐 Security Checklist

Trước khi deploy production:

- [ ] Đổi `SECRET_KEY` trong `.env`
- [ ] Enable HTTPS/SSL
- [ ] Configure CORS properly
- [ ] Set up AWS IAM roles
- [ ] Enable CloudWatch logging
- [ ] Configure Security Groups
- [ ] Enable DynamoDB encryption
- [ ] Set up backup policies
- [ ] Configure rate limiting
- [ ] Review API authentication

---

## 📞 Support

- **Documentation**: `/docs` trong repository
- **Issues**: GitHub Issues
- **API Docs**: http://localhost:8000/api/docs

---

## 🎯 Quick Start Checklist

```bash
✅ Clone repository
✅ Create virtual environment
✅ Install dependencies (pip install -r requirements.txt)
✅ Configure .env file
✅ Start DynamoDB Local (or configure AWS)
✅ (Optional) Start Redis
✅ Run application (python main.py)
✅ Access http://localhost:8000/api/docs
✅ Test /health endpoint
✅ Done! 🎉
```

---

**Thời gian setup ước tính:** 10-15 phút

**Status:** ✅ Ready to Run!
