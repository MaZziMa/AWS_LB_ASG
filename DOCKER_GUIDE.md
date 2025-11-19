# 🐳 Docker Architecture - Course Registration System

## Tổng quan kiến trúc

Dự án sử dụng Docker Compose để chạy 5 services trong một mạng riêng:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Network: course-reg-net              │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │   DynamoDB   │    │    Redis     │    │   Backend    │    │
│  │   Local      │◄───┤   Cache      │◄───┤   FastAPI    │    │
│  │   Port 8000  │    │   Port 6379  │    │   Port 8000  │    │
│  └──────────────┘    └──────────────┘    └──────┬───────┘    │
│         ▲                                        │             │
│         │                                        │             │
│  ┌──────┴───────┐                         ┌─────▼────────┐    │
│  │  DynamoDB    │                         │   Frontend   │    │
│  │   Init       │                         │   Vite+React │    │
│  │  (one-shot)  │                         │   Port 3000  │    │
│  └──────────────┘                         └──────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
           │                                        │
           │                                        │
    ┌──────▼────────┐                      ┌───────▼────────┐
    │ localhost:8000│                      │ localhost:3000 │
    │ (DynamoDB API)│                      │ (Browser UI)   │
    └───────────────┘                      └────────────────┘
```

---

## 📦 Chi tiết từng Service

### 1. **DynamoDB Local** (`dynamodb`)
**Image**: `amazon/dynamodb-local:latest`

**Vai trò**: 
- Mô phỏng AWS DynamoDB trên máy local
- Lưu trữ tất cả dữ liệu: Users, Courses, Enrollments

**Cấu hình**:
```yaml
ports:
  - "8000:8000"  # Expose DynamoDB API
command: -jar DynamoDBLocal.jar -sharedDb -optimizeDbBeforeStartup
```

**Truy cập**:
- API: `http://localhost:8000`
- Từ backend container: `http://dynamodb:8000`
- Dữ liệu được lưu trong container (mất khi xóa container)

**Cách kiểm tra**:
```powershell
# List tables
aws dynamodb list-tables --endpoint-url http://localhost:8000 --region us-east-1
```

---

### 2. **Redis Cache** (`redis`)
**Image**: `redis:7`

**Vai trò**:
- Cache dữ liệu courses, users để giảm tải DynamoDB
- Session storage
- Rate limiting

**Cấu hình**:
```yaml
ports:
  - "6379:6379"  # Redis default port
```

**Truy cập**:
- Từ host: `localhost:6379`
- Từ backend: `redis://redis:6379/0`

**Cách kiểm tra**:
```powershell
# Connect via redis-cli
docker exec -it course-reg-redis redis-cli
> KEYS *
> GET course:*
```

---

### 3. **DynamoDB Init** (`dynamodb-init`)
**Image**: `python:3.11-slim`

**Vai trò**:
- **One-shot service** - chỉ chạy 1 lần khi khởi động
- Tự động tạo các bảng DynamoDB: `CourseReg_Users`, `CourseReg_Courses`, `CourseReg_Enrollments`
- Thoát sau khi hoàn thành

**Cấu hình**:
```yaml
depends_on:
  - dynamodb
restart: "no"  # Không restart khi thoát
volumes:
  - ./backend:/app:ro  # Mount backend code read-only
```

**Quy trình hoạt động**:
1. Đợi `dynamodb` service khởi động
2. Cài đặt Python dependencies
3. Import `app.dynamodb` module
4. Gọi `init_tables()` để tạo bảng
5. Thoát với exit code 0

**Log kiểm tra**:
```powershell
docker compose logs dynamodb-init
```

---

### 4. **Backend API** (`backend`)
**Build từ**: `./backend/Dockerfile`

**Vai trò**:
- FastAPI REST API server
- Xử lý authentication (JWT)
- CRUD operations cho courses/enrollments
- Kết nối DynamoDB và Redis

**Dockerfile**:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Environment Variables**:
- `DYNAMODB_ENDPOINT_URL=http://dynamodb:8000` - Trỏ đến DynamoDB container
- `REDIS_URL=redis://redis:6379/0` - Trỏ đến Redis container
- `CORS_ORIGINS=["http://localhost:3000"]` - Allow frontend origin

**Dependencies**:
```yaml
depends_on:
  - dynamodb
  - redis
  - dynamodb-init  # Đảm bảo tables đã được tạo
```

**Truy cập**:
- API: `http://localhost:8000/api/docs`
- Health: `http://localhost:8000/health`

**Hot reload**: Không có trong Docker (production mode). Để dev, chạy local với `uvicorn --reload`

---

### 5. **Frontend UI** (`frontend`)
**Build từ**: `./frontend/Dockerfile`

**Vai trò**:
- React + Vite development server
- UI cho students/teachers/admins
- Gọi API backend qua `http://localhost:8000`

**Dockerfile**:
```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "run", "dev", "--", "--host"]
```

**Cấu hình API**:
File `src/api/axios.js`:
```javascript
const api = axios.create({
  baseURL: 'http://localhost:8000/api',  // Calls từ browser, không phải container
})
```

**Truy cập**:
- UI: `http://localhost:3000`
- Vite dev server với hot reload

---

## 🔄 Luồng hoạt động

### Khi chạy `docker compose up --build`:

```
1. Docker tạo network: course-reg-net
   │
2. Build images cho backend và frontend
   │
3. Start services theo thứ tự depends_on:
   │
   ├─► Start DynamoDB Local (port 8000)
   │   └─► Đợi khởi động xong
   │
   ├─► Start Redis (port 6379)
   │   └─► Sẵn sàng ngay
   │
   ├─► Start dynamodb-init
   │   ├─► Cài pip packages
   │   ├─► Chạy init_tables()
   │   └─► Tạo 3 bảng: Users, Courses, Enrollments
   │
   ├─► Start Backend
   │   ├─► Connect to dynamodb:8000
   │   ├─► Connect to redis:6379
   │   └─► Expose port 8000 ra host
   │
   └─► Start Frontend
       ├─► npm run dev
       └─► Expose port 3000 ra host
```

### Khi user truy cập `http://localhost:3000`:

```
Browser (localhost:3000)
   │
   ├─► Load React app từ Frontend container
   │
   └─► User login
       │
       └─► POST http://localhost:8000/api/auth/login
           │
           └─► Backend container xử lý:
               │
               ├─► Query DynamoDB (container dynamodb:8000)
               │   └─► Tìm user trong bảng CourseReg_Users
               │
               ├─► Cache vào Redis (redis:6379)
               │
               └─► Return JWT token
                   │
                   └─► Browser lưu token
```

### Khi user xem danh sách courses:

```
Browser
   │
   └─► GET http://localhost:8000/api/courses
       │
       └─► Backend:
           │
           ├─► Check Redis cache (redis:6379)
           │   ├─► Hit: Return từ cache
           │   └─► Miss: Query DynamoDB
           │
           └─► Return JSON courses
               │
               └─► React render UI
```

---

## 🛠️ Các lệnh thao tác

### Khởi động dự án:
```powershell
# Build và start tất cả services
docker compose up --build

# Chạy detached mode (chạy nền)
docker compose up -d

# Chỉ start một service
docker compose up backend
```

### Kiểm tra logs:
```powershell
# Xem logs tất cả services
docker compose logs -f

# Xem log một service
docker compose logs -f backend
docker compose logs dynamodb-init
```

### Seed dữ liệu mẫu:
```powershell
# Chạy script seed trong backend container
docker compose run --rm backend python scripts/seed_dynamodb.py
```

### Debug container:
```powershell
# Shell vào backend
docker compose exec backend bash

# Shell vào DynamoDB
docker compose exec dynamodb sh

# Xem DynamoDB tables
docker compose exec backend python -c "from app.dynamodb import db; db.connect(); print(db.client.list_tables())"
```

### Quản lý:
```powershell
# Stop tất cả
docker compose down

# Stop và xóa volumes (mất data)
docker compose down -v

# Restart một service
docker compose restart backend

# Rebuild image
docker compose build backend
docker compose up -d backend
```

---

## 🔍 Troubleshooting

### Problem 1: Port 8000 bị chiếm
```
Error: bind: address already in use
```

**Giải pháp**:
- Backend và DynamoDB đều dùng port 8000
- Tắt backend local trước: `Ctrl+C` trong terminal đang chạy uvicorn
- Hoặc sửa port trong `docker-compose.yml`:
  ```yaml
  dynamodb:
    ports:
      - "8001:8000"  # Map sang 8001
  ```

### Problem 2: Frontend không connect được backend
```
Network Error: Failed to fetch
```

**Nguyên nhân**:
- Frontend gọi API từ browser, không phải từ container
- Phải dùng `http://localhost:8000`, không dùng `http://backend:8000`

**Kiểm tra**:
- Mở browser console
- Xem baseURL trong `src/api/axios.js`

### Problem 3: DynamoDB tables không tồn tại
```
ResourceNotFoundException: Cannot do operations on a non-existent table
```

**Giải pháp**:
```powershell
# Kiểm tra dynamodb-init đã chạy thành công chưa
docker compose logs dynamodb-init

# Nếu failed, chạy lại
docker compose up dynamodb-init

# Hoặc tạo tables thủ công
docker compose run --rm backend python -c "from app.dynamodb import db, init_tables; db.connect(); init_tables()"
```

### Problem 4: Redis connection refused
```
ConnectionRefusedError: [Errno 111] Connection refused
```

**Kiểm tra**:
```powershell
# Redis có đang chạy?
docker compose ps redis

# Test connection
docker compose exec backend python -c "import redis; r=redis.from_url('redis://redis:6379/0'); print(r.ping())"
```

---

## 📊 So sánh: Docker vs Local Development

| Tiêu chí | Docker | Local |
|----------|--------|-------|
| **Setup** | `docker compose up` | Cài Python, Node, DynamoDB Local, Redis riêng lẻ |
| **Isolation** | ✅ Độc lập hoàn toàn | ❌ Conflict versions |
| **Portability** | ✅ Chạy mọi nơi | ❌ Phụ thuộc OS |
| **Performance** | ⚠️ Overhead nhẹ | ✅ Native speed |
| **Hot reload** | ❌ Phải rebuild | ✅ Instant |
| **Debugging** | ⚠️ Khó hơn | ✅ Dễ dàng |
| **CI/CD** | ✅ Ideal | ❌ Khó replicate |

**Khuyến nghị**:
- **Development**: Chạy local với hot reload
- **Testing**: Docker để đảm bảo consistency
- **Production**: Deploy lên AWS EC2/ECS

---

## 🚀 Production Deployment

Khi deploy lên AWS, không dùng Docker mà dùng:

1. **EC2 instances** - Chạy backend trực tiếp với systemd
2. **DynamoDB AWS** - Thay DynamoDB Local
3. **ElastiCache Redis** - Thay Redis container
4. **S3 + CloudFront** - Host frontend static files
5. **ALB** - Load balancing

Docker chỉ dùng cho **local development** và **CI/CD testing**.

---

## 📝 Best Practices

### 1. Không commit `.env` files
- Thêm vào `.dockerignore`:
  ```
  .env
  .env.local
  .env.production
  ```

### 2. Use multi-stage builds cho production:
```dockerfile
# backend/Dockerfile.prod
FROM python:3.11-slim as builder
RUN pip wheel --no-cache-dir ...

FROM python:3.11-slim
COPY --from=builder /wheels /wheels
RUN pip install --no-index /wheels/*
```

### 3. Health checks:
```yaml
backend:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 30s
    timeout: 3s
    retries: 3
```

### 4. Resource limits:
```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '1'
        memory: 512M
```

---

## 📚 Tài liệu thêm

- [Docker Compose Reference](https://docs.docker.com/compose/)
- [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)
- [FastAPI + Docker](https://fastapi.tiangolo.com/deployment/docker/)
- [Vite Docker](https://vitejs.dev/guide/)
