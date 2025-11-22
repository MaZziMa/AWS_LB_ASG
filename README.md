# AWS Load Balancer + Auto Scaling Group Project

## 🚀 Performance Optimization Documentation

**Vấn đề hiện tại:** TargetResponseTime = 5.3 giây (CRITICAL)  
**Mục tiêu:** Giảm xuống < 200ms thông qua Caching + Database Indexing

### 📚 Tài liệu Optimization

**BẮT ĐẦU TẠI ĐÂY:** 👉 [`OPTIMIZATION_INDEX.md`](./OPTIMIZATION_INDEX.md) - Navigation hub cho tất cả tài liệu

#### Quick Links:
- 📖 **[Giải thích Caching & Indexing](./CACHING_INDEXING_EXPLAINED.md)** - Câu trả lời trực tiếp cho "giúp như thế nào?"
- 🚀 **[Quick Start Guide](./QUICK_OPTIMIZATION_GUIDE.md)** - Copy-paste code và deploy ngay
- 📊 **[Before/After Comparison](./OPTIMIZATION_COMPARISON.md)** - Metrics, load test results, cost analysis
- 🏗️ **[Architecture Diagrams](./ARCHITECTURE_DIAGRAMS.md)** - Visual system architecture
- 📚 **[Comprehensive Guide](./BACKEND_OPTIMIZATION.md)** - Chi tiết từng optimization technique

#### Implementation Files:
- `backend/app/cache.py` - Redis cache utilities
- `backend/app/db_optimization.py` - DynamoDB optimization helpers
- `backend/app/api/courses_optimized.py` - Example implementation
- `infrastructure/create-dynamodb-indexes.ps1` - GSI creation script
- `apply-optimizations.ps1` - One-click deployment

### 🎯 Expected Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Response Time | 5.3s | 25ms | **99.5% ↓** |
| Throughput | 20 req/s | 800 req/s | **40x ↑** |
| Error Rate | 12% | 0% | **100% ↓** |
| Monthly Cost | $118 | $68 | **42% ↓** |

---

## 📁 Existing Documentation

# AWS_LB_ASG