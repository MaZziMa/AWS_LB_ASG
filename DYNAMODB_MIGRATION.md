# ✅ DynamoDB Migration Complete!

## 🎉 Hoàn Thành

Hệ thống đã được cấu hình để sử dụng **AWS DynamoDB** thay thế cho PostgreSQL/SQLite!

---

## 📊 Các Thay Đổi Chính

### 1. **Configuration (.env)**
```env
# DynamoDB Configuration
DYNAMODB_REGION=us-east-1
DYNAMODB_ENDPOINT_URL=http://localhost:8000  # Để trống cho AWS, điền URL cho local DynamoDB
DYNAMODB_TABLE_PREFIX=CourseReg
```

### 2. **DynamoDB Client (`app/dynamodb.py`)**
- ✅ Kết nối DynamoDB với boto3
- ✅ Helper functions: `get_item()`, `put_item()`, `query_items()`, `scan_items()`, `update_item()`, `delete_item()`
- ✅ Table definitions với GSI (Global Secondary Indexes)
- ✅ Auto-init tables function

### 3. **API Routes**
- ✅ `POST /api/auth/login` - Login với DynamoDB query (username-index)
- ✅ `GET /api/auth/me` - Get user info từ DynamoDB
- ✅ `POST /api/auth/refresh` - Refresh token
- ✅ `GET /api/courses` - Placeholder cho courses API
- ✅ `GET /api/enrollments/my` - Placeholder cho enrollments API

### 4. **Tables Design**
```
CourseReg_Users          # PK: user_id, GSI: username, email
CourseReg_Courses        # PK: course_id, GSI: semester_id, department_id
CourseReg_Enrollments    # PK: enrollment_id, GSI: student_id+semester_id, section_id
CourseReg_Students
CourseReg_Teachers
CourseReg_Departments
CourseReg_Semesters
CourseReg_CourseSections
CourseReg_Classrooms
```

---

## 🚀 Cách Chạy

### 1. **Với AWS DynamoDB (Production)**
```env
# .env
DYNAMODB_REGION=us-east-1
DYNAMODB_ENDPOINT_URL=
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

### 2. **Với DynamoDB Local (Development)**
```bash
# Download và chạy DynamoDB Local
docker run -p 8000:8000 amazon/dynamodb-local

# Hoặc download JAR
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb
```

```env
# .env
DYNAMODB_ENDPOINT_URL=http://localhost:8000
AWS_ACCESS_KEY_ID=fakeMyKeyId
AWS_SECRET_ACCESS_KEY=fakeSecretAccessKey
```

### 3. **Start Application**
```bash
cd backend
D:/AWS_LB_ASG/.venv/Scripts/python.exe main.py
```

Server sẽ chạy tại: **http://localhost:8000**

---

## 📡 API Endpoints

### Health Check
```bash
curl http://localhost:8000/health
# {"status": "healthy", "version": "1.0.0"}
```

### API Documentation
- **Swagger UI**: http://localhost:8000/api/docs
- **ReDoc**: http://localhost:8000/api/redoc

### Authentication
```bash
# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'

# Get current user
curl http://localhost:8000/api/auth/me \
  -H "Authorization: Bearer <access_token>"
```

---

## 🗄️ Khởi Tạo Tables

### Tạo Tables Lần Đầu
```python
from app.dynamodb import db, init_tables

# Connect
db.connect()

# Create tables
init_tables()
```

### Hoặc dùng script
```bash
python -c "from app.dynamodb import db, init_tables; db.connect(); init_tables()"
```

---

## 📝 So Sánh: PostgreSQL vs DynamoDB

| Feature | PostgreSQL | DynamoDB |
|---------|-----------|----------|
| **Type** | SQL (Relational) | NoSQL (Key-Value/Document) |
| **Query** | Complex joins, aggregations | Get/Query by keys, no joins |
| **Schema** | Fixed schema | Flexible schema |
| **Transactions** | ACID transactions | Limited transactions |
| **Scaling** | Vertical (add more CPU/RAM) | Horizontal (auto-scaling) |
| **Cost** | EC2 + RDS instances | Pay per request |
| **Best for** | Complex relationships | High throughput, simple queries |

### Khi nào dùng DynamoDB?
✅ High read/write throughput  
✅ Simple key-based queries  
✅ Auto-scaling requirements  
✅ Serverless architecture  
✅ Global replication needs

### Khi nào dùng PostgreSQL?
✅ Complex joins and relationships  
✅ Complex analytics queries  
✅ ACID transaction requirements  
✅ Existing SQL knowledge  
✅ Standard ORM support

---

## 🔧 Troubleshooting

### 1. **DynamoDB Connection Error**
```
ERROR - DynamoDB connection error
```
**Solution:**
- Check AWS credentials
- Verify `DYNAMODB_REGION`
- If local: ensure DynamoDB Local is running

### 2. **Table Not Found**
```
ResourceNotFoundException: Table not found
```
**Solution:**
```python
from app.dynamodb import init_tables
init_tables()
```

### 3. **GSI Not Found**
```
ValidationException: Index not found
```
**Solution:** Recreate table với đúng GSI definition

---

## 📚 Next Steps

### 1. **Implement Full CRUD Operations**
- [ ] Complete Courses API với DynamoDB
- [ ] Complete Enrollments API
- [ ] Add prerequisites checking
- [ ] Add schedule conflict detection

### 2. **Data Migration** (nếu có data từ PostgreSQL)
```python
# Export PostgreSQL
pg_dump course_registration > backup.sql

# Transform và import vào DynamoDB
# Viết script migration
```

### 3. **Performance Optimization**
- [ ] Add DynamoDB Streams for real-time updates
- [ ] Implement DAX (DynamoDB Accelerator) for caching
- [ ] Use batch operations for bulk writes
- [ ] Optimize GSI design

### 4. **Monitoring**
- [ ] CloudWatch metrics for DynamoDB
- [ ] Set alarms for throttled requests
- [ ] Monitor consumed capacity units (RCU/WCU)

---

## 🎯 Current Status

✅ **DynamoDB client configured**  
✅ **Authentication API working**  
✅ **FastAPI server running on port 8000**  
✅ **Health check endpoint active**  
✅ **API documentation available**  
⚠️ **Redis cache optional (continues without it)**  
⚠️ **Prometheus metrics disabled (use CloudWatch)**

---

## 📞 Support

For issues or questions:
1. Check AWS DynamoDB documentation: https://docs.aws.amazon.com/dynamodb/
2. Review boto3 DynamoDB guide: https://boto3.amazonaws.com/v1/documentation/api/latest/guide/dynamodb.html
3. See `SYSTEM_DESIGN.md` for architecture overview

---

**Status**: ✅ **Migration Complete - Ready for Development!**
