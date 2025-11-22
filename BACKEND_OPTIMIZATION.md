# Backend Performance Optimization Guide

## 🎯 Performance Problem Analysis

### Current Baseline
- **TargetResponseTime Average**: 5.3s (CRITICAL)
- **Target**: < 200ms (p50), < 500ms (p99)
- **Gap**: **96% improvement needed**

### Root Causes
1. **No Caching Layer** → Every request hits DynamoDB (10-50ms latency)
2. **Missing Database Indexes** → Scan operations instead of Query (10-100x slower)
3. **No Connection Pooling** → TCP handshake overhead per request
4. **Synchronous I/O** → Blocking operations during network calls
5. **No Query Optimization** → N+1 queries, unnecessary data fetch

---

## 🚀 Optimization Strategies

### 1. Redis Caching Layer

#### Architecture
```
Request → FastAPI → Redis Cache (hit) → Return (2ms)
                  ↓ (miss)
                  DynamoDB → Store in Cache → Return (50ms)
```

#### Implementation Steps

**A. Install Redis (AWS ElastiCache or local for dev)**

```powershell
# Development: Redis via Docker
docker run -d --name redis-cache -p 6379:6379 redis:7-alpine

# Production: ElastiCache (via AWS Console or CLI)
aws elasticache create-cache-cluster \
    --cache-cluster-id course-reg-cache \
    --engine redis \
    --cache-node-type cache.t3.micro \
    --num-cache-nodes 1 \
    --engine-version 7.0
```

**B. Update backend configuration**

File: `backend/app/config.py`
```python
class Settings(BaseSettings):
    # ... existing settings ...
    
    # Redis Cache
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_PASSWORD: Optional[str] = None
    REDIS_MAX_CONNECTIONS: int = 50
    CACHE_ENABLED: bool = True
```

**C. Apply caching to API endpoints**

File: `backend/app/api/courses.py`
```python
from app.cache import cache, CacheKeys, CacheTTL, cached

@router.get("", response_model=List[CourseResponse])
async def list_courses(semester_id: int, department_id: Optional[int] = None):
    """List courses with Redis caching"""
    
    # Try cache first
    cache_key = CacheKeys.course_list(semester_id, department_id)
    cached_data = await cache.get(cache_key)
    
    if cached_data:
        return cached_data
    
    # Cache miss - query DynamoDB
    courses = await db_optimizer.query_with_gsi(
        'Courses',
        'CoursesBySemester',
        'semester_id = :sid',
        {':sid': {'N': str(semester_id)}},
        limit=100
    )
    
    # Store in cache
    await cache.set(cache_key, courses, CacheTTL.COURSE_LIST)
    
    return courses
```

**D. Cache invalidation strategy**

```python
# When course is updated/created
@router.post("/{course_id}")
async def update_course(course_id: str, data: CourseUpdate):
    # Update database
    await dynamodb.update_item(...)
    
    # Invalidate cache
    await cache.delete(CacheKeys.course_detail(course_id))
    await cache.delete_pattern("courses:semester:*")  # Clear all list caches
    
    return {"status": "updated"}
```

#### Performance Impact
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Response Time (avg)** | 5.3s | 50-150ms | **97% ↓** |
| **Response Time (p99)** | 8s+ | 300ms | **96% ↓** |
| **DynamoDB RCU** | 100/sec | 10/sec | **90% ↓** |
| **Request Throughput** | 20 req/s | 500+ req/s | **25x ↑** |

---

### 2. Database Indexing (DynamoDB GSI)

#### Why Indexes Matter

**Without Index (Scan):**
```python
# Scans ENTIRE table - O(n) complexity
response = table.scan(
    FilterExpression='semester_id = :sid',
    ExpressionAttributeValues={':sid': 1}
)
# Cost: 1000 items × 4 KB = 4000 RCUs, ~5-10 seconds
```

**With GSI (Query):**
```python
# Queries only matching partition - O(log n) complexity
response = table.query(
    IndexName='CoursesBySemester',
    KeyConditionExpression='semester_id = :sid',
    ExpressionAttributeValues={':sid': 1}
)
# Cost: 50 items × 4 KB = 50 RCUs, ~50-200ms
```

#### Implementation

**A. Create Global Secondary Indexes**

Run the provided script:
```powershell
cd infrastructure
.\create-dynamodb-indexes.ps1
```

This creates:
1. **CoursesBySemester** (semester_id + department_id) → Fast course filtering
2. **EnrollmentsByUser** (user_id + enrolled_at) → My enrollments page
3. **EnrollmentsByCourse** (course_id + enrolled_at) → Enrollment count
4. **CoursesByInstructor** (instructor_id + course_code) → Instructor dashboard

**B. Update query patterns in code**

```python
from app.db_optimization import db_optimizer

# OLD: Scan operation (slow)
async def get_user_enrollments_old(user_id: str):
    response = table.scan(
        FilterExpression='user_id = :uid',
        ExpressionAttributeValues={':uid': user_id}
    )
    return response['Items']

# NEW: Query with GSI (fast)
async def get_user_enrollments(user_id: str):
    return db_optimizer.query_with_gsi(
        table_name='Enrollments',
        index_name='EnrollmentsByUser',
        key_condition='user_id = :uid',
        expression_values={':uid': {'S': user_id}},
        limit=50
    )
```

#### Performance Impact
| Operation | Before (Scan) | After (GSI) | Improvement |
|-----------|---------------|-------------|-------------|
| **Get user enrollments** | 2-5s | 50-150ms | **95% ↓** |
| **List courses by semester** | 3-8s | 100-300ms | **94% ↓** |
| **RCU consumption** | 1000 | 10-50 | **95% ↓** |

---

### 3. Connection Pooling

#### Problem: Connection Overhead
Each request creates new TCP connection → 50-100ms handshake overhead.

#### Solution: Reuse Connections

File: `backend/app/db_optimization.py`
```python
from botocore.config import Config

config = Config(
    retries={'max_attempts': 3, 'mode': 'adaptive'},
    max_pool_connections=50,  # Reuse up to 50 connections
    connect_timeout=5,
    read_timeout=10,
)

dynamodb = boto3.resource('dynamodb', config=config)
```

#### Performance Impact
- **Connection time**: 50-100ms → 0ms (reused)
- **Concurrent requests**: Limited by connections → 50 parallel
- **Latency reduction**: 15-20%

---

### 4. Batch Operations

#### Problem: N+1 Query Pattern
```python
# BAD: 1 query for list + N queries for details
enrollments = get_user_enrollments(user_id)  # 1 query
for enroll in enrollments:
    course = get_course_detail(enroll.course_id)  # N queries!
```

#### Solution: Batch Fetch
```python
# GOOD: 1 query for list + 1 batch query for all details
enrollments = get_user_enrollments(user_id)  # 1 query
course_ids = [e.course_id for e in enrollments]
courses = db_optimizer.batch_get_items('Courses', course_ids)  # 1 batch query
```

#### Implementation
```python
# Fetch 100 courses in single batch request
course_keys = [{'course_id': {'S': cid}} for cid in course_ids]
courses = await db_optimizer.batch_get_items('Courses', course_keys)
```

#### Performance Impact
- **100 items**: 100 × 50ms = 5s → 1 × 100ms = 0.1s (50x faster)
- **Network round trips**: 100 → 1
- **DynamoDB cost**: Same RCUs, but less request charges

---

### 5. Async Processing & Background Tasks

#### Problem: Blocking Operations
```python
# BAD: Wait for email to send (500ms)
await send_enrollment_email(user_email)
return {"status": "enrolled"}  # User waits 500ms
```

#### Solution: Background Tasks
```python
from fastapi import BackgroundTasks

@router.post("/enrollments")
async def enroll(data: EnrollmentCreate, bg: BackgroundTasks):
    # Save enrollment (fast)
    enrollment = await save_enrollment(data)
    
    # Queue email sending (don't wait)
    bg.add_task(send_enrollment_email, user_email)
    
    return {"status": "enrolled"}  # Return immediately
```

#### Use Cases
- Email notifications
- CloudWatch metrics push
- Audit log writes
- Cache warming

---

## 📊 Combined Performance Impact

### Before Optimization
```
Request Flow:
1. API receives request (1ms)
2. DynamoDB Scan (5000ms) ← BOTTLENECK
3. Process data (200ms)
4. Send email (500ms) ← BLOCKING
5. Return response (100ms)
────────────────────────────
Total: 5801ms (5.8s)
```

### After All Optimizations
```
Request Flow:
1. API receives request (1ms)
2. Redis cache HIT (2ms) ← 99% of requests
   OR DynamoDB Query via GSI (50ms) ← 1% cache miss
3. Process data (50ms) ← reduced by batch ops
4. Queue email (1ms) ← background task
5. Return response (10ms)
────────────────────────────
Total: 64ms (0.064s) → 90x faster!
```

### Metrics Comparison

| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| **Avg Response Time** | 5.3s | 64ms | 200ms | ✅ **PASS** |
| **P99 Response Time** | 8s+ | 150ms | 500ms | ✅ **PASS** |
| **Requests/sec** | 20 | 500+ | 100 | ✅ **PASS** |
| **DynamoDB RCU** | 1000 | 50 | - | ✅ 95% reduction |
| **CPU Usage** | 80% | 30% | < 70% | ✅ **PASS** |

---

## 🔧 Implementation Checklist

### Phase 1: Quick Wins (1-2 hours)
- [ ] Install Redis (local or ElastiCache)
- [ ] Update `config.py` with Redis settings
- [ ] Apply caching to top 3 endpoints:
  - [ ] `GET /api/courses` (course list)
  - [ ] `GET /api/enrollments/me` (my enrollments)
  - [ ] `GET /api/auth/me` (profile)
- [ ] Test with locust: verify response time drop

### Phase 2: Database Optimization (2-3 hours)
- [ ] Run `create-dynamodb-indexes.ps1`
- [ ] Wait for indexes to become ACTIVE (~5-10 min)
- [ ] Update code to use GSI queries
- [ ] Replace all `table.scan()` with `query_with_gsi()`
- [ ] Monitor CloudWatch: check UserErrors (should be 0)

### Phase 3: Advanced (3-4 hours)
- [ ] Implement connection pooling in `db_optimization.py`
- [ ] Convert N+1 queries to batch operations
- [ ] Add background tasks for emails/notifications
- [ ] Implement cache invalidation logic
- [ ] Add cache metrics (hit rate, miss rate)

### Phase 4: Monitoring (1 hour)
- [ ] Add CloudWatch custom metrics for cache hit rate
- [ ] Set up alarms for cache failures
- [ ] Create dashboard widget for cache performance
- [ ] Load test with 200 users: verify < 200ms p50

---

## 💰 Cost Analysis

### Additional Costs
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| **ElastiCache Redis** | cache.t3.micro (0.5 GB) | $11 |
| **DynamoDB GSI** | 4 indexes × provisioned RCU/WCU | $8 |
| **Data Transfer** | Cache replication | $2 |
| **Total** | | **$21/month** |

### Cost Savings
| Item | Before | After | Savings |
|------|--------|-------|---------|
| **DynamoDB RCU** (provisioned) | 100 units = $13 | 20 units = $2.60 | **$10.40** |
| **EC2 instances** (fewer needed) | 3 × t3.micro = $22.50 | 2 × t3.micro = $15 | **$7.50** |
| **Data transfer** (less DB traffic) | $5 | $2 | **$3** |
| **Total Savings** | | | **$20.90/month** |

**Net Cost Impact**: ~$0/month (basically free!)

---

## 🧪 Testing & Validation

### 1. Cache Testing
```python
# Test cache hit/miss
import time

# First request (cache miss)
start = time.time()
courses = await list_courses(semester_id=1)
miss_time = time.time() - start
print(f"Cache MISS: {miss_time:.3f}s")

# Second request (cache hit)
start = time.time()
courses = await list_courses(semester_id=1)
hit_time = time.time() - start
print(f"Cache HIT: {hit_time:.3f}s")
print(f"Speedup: {miss_time/hit_time:.1f}x")
```

### 2. Load Testing
```powershell
# Run optimized load test
locust -f loadtest/locustfile.py --host=http://your-alb-url --users 200 --spawn-rate 10 --run-time 5m --html report.html
```

### 3. CloudWatch Validation
```powershell
# Check TargetResponseTime after optimization
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name TargetResponseTime \
    --dimensions Name=LoadBalancer,Value=<your-alb> \
    --start-time (Get-Date).AddMinutes(-10).ToUniversalTime() \
    --end-time (Get-Date).ToUniversalTime() \
    --period 60 \
    --statistics Average
```

Expected result: **Average < 0.2 (200ms)**

---

## 🚨 Common Pitfalls

### 1. Cache Stampede
**Problem**: Cache expires → 100 concurrent requests all miss → 100 DB queries.

**Solution**: Cache locking
```python
async def get_with_lock(key: str, fetch_func, ttl: int):
    cached = await cache.get(key)
    if cached:
        return cached
    
    # Acquire lock
    lock_key = f"lock:{key}"
    if await cache.set(lock_key, "1", ttl=10):  # 10s lock
        result = await fetch_func()
        await cache.set(key, result, ttl)
        await cache.delete(lock_key)
        return result
    else:
        # Wait for other request to populate cache
        await asyncio.sleep(0.1)
        return await get_with_lock(key, fetch_func, ttl)
```

### 2. Stale Cache
**Problem**: Database updated but cache still has old data.

**Solution**: Write-through cache
```python
async def update_course(course_id: str, data: dict):
    # 1. Update database
    await dynamodb.update_item(...)
    
    # 2. Update cache immediately
    updated_course = await fetch_course(course_id)
    await cache.set(CacheKeys.course_detail(course_id), updated_course)
    
    # 3. Invalidate related caches
    await cache.delete_pattern("courses:semester:*")
```

### 3. Memory Overflow
**Problem**: Caching too much data → Redis OOM.

**Solution**: Eviction policy + monitoring
```python
# Set maxmemory in redis.conf
maxmemory 512mb
maxmemory-policy allkeys-lru  # Evict least recently used
```

---

## 📚 Additional Resources

- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [ElastiCache Redis Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/BestPractices.html)
- [FastAPI Performance Tips](https://fastapi.tiangolo.com/advanced/performance/)
- [Redis Caching Patterns](https://redis.io/docs/manual/patterns/)

---

## ✅ Success Criteria

After implementing all optimizations:

1. ✅ **TargetResponseTime Average < 200ms** (currently 5.3s)
2. ✅ **P99 latency < 500ms** (currently 8s+)
3. ✅ **DynamoDB RCU reduced by 80%+**
4. ✅ **Support 500+ req/s** (currently 20 req/s)
5. ✅ **Cache hit rate > 90%**
6. ✅ **CPU utilization < 50%** during load test

**Target Achievement**: All optimizations can reduce TargetResponseTime from **5.3s to ~64ms** → **98.8% improvement** 🎉
