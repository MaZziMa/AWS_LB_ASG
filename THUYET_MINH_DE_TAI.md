# THUYẾT MINH ĐỀ TÀI

## PHẦN 1: THÔNG TIN CHUNG

### 1.1. Tên đề tài
**"Xây dựng hệ thống quản lý khóa học với giải pháp cân bằng tải và tự động mở rộng trên AWS"**

Tên tiếng Anh: *"Building a Course Management System with AWS Load Balancing and Auto Scaling Solution"*

### 1.2. Lý do chọn đề tài

#### Bối cảnh thực tế:
Trong thời đại chuyển đổi số, các hệ thống web phải đối mặt với nhiều thách thức:

1. **Lưu lượng truy cập không ổn định**: 
   - Giờ cao điểm: Hàng trăm người dùng truy cập đồng thời
   - Giờ thấp điểm: Chỉ vài chục người dùng
   - Sự kiện đột biến: Flash sale, đăng ký môn học hot

2. **Yêu cầu về hiệu năng và độ tin cậy**:
   - Thời gian phản hồi < 1 giây
   - Uptime ≥ 99.9% (chỉ chấp nhận downtime < 9 giờ/năm)
   - Xử lý được peak load mà không crash

3. **Tối ưu chi phí vận hành**:
   - Không muốn over-provision (mua server quá mạnh nhàn rỗi)
   - Không muốn under-provision (server yếu, người dùng phàn nàn)
   - Cần giải pháp "pay as you go" - chỉ trả tiền khi sử dụng

#### Giải pháp truyền thống và hạn chế:

**Phương án 1: Single Server (1 con server to)**
- ❌ Single Point of Failure: Server chết = hệ thống chết
- ❌ Không scale được: Traffic tăng = chậm hoặc crash
- ❌ Lãng phí tài nguyên: Mua server mạnh nhưng chỉ dùng 20%

**Phương án 2: Multiple Servers + Manual Scaling**
- ❌ Cần can thiệp thủ công 24/7
- ❌ Phản ứng chậm: Phải 30-60 phút mới setup server mới
- ❌ Phức tạp: Phải tự config load balancer, health check, deployment

#### Giải pháp đề xuất: AWS Cloud với ALB + Auto Scaling

✅ **Application Load Balancer (ALB)**: Tự động phân tải traffic
✅ **Auto Scaling Group (ASG)**: Tự động tăng/giảm số lượng server
✅ **High Availability**: Multi-AZ, tự động thay thế instance lỗi
✅ **Cost-Effective**: Chỉ trả tiền server đang chạy
✅ **Monitoring**: CloudWatch theo dõi real-time

---

## PHẦN 2: MỤC TIÊU NGHIÊN CỨU

### 2.1. Mục tiêu tổng quát
Xây dựng một hệ thống quản lý khóa học (Course Registration System) hoàn chỉnh trên nền tảng AWS, minh chứng hiệu quả của giải pháp Load Balancing và Auto Scaling trong việc:
- Tối ưu hiệu năng hệ thống
- Đảm bảo tính sẵn sàng cao (High Availability)
- Giảm thiểu chi phí vận hành

### 2.2. Mục tiêu cụ thể

#### 2.2.1. Về kỹ thuật:
1. **Triển khai Application Load Balancer**:
   - Cấu hình health check tự động
   - Phân tải traffic theo thuật toán Round Robin
   - Xử lý SSL/TLS termination

2. **Triển khai Auto Scaling Group**:
   - Thiết lập scaling policy dựa trên CPU utilization
   - Cấu hình min/max instances
   - Tự động thay thế instance không healthy

3. **Xây dựng ứng dụng Course Registration**:
   - Backend: FastAPI (Python) + DynamoDB
   - Frontend: React + Vite
   - Containerization: Docker + Amazon ECR

4. **Monitoring & Alerting**:
   - CloudWatch Dashboard với 8+ metrics
   - CloudWatch Alarms cho critical events
   - Real-time monitoring scripts

#### 2.2.2. Về nghiên cứu:
1. **So sánh hiệu năng**:
   - Single instance vs Multi-instance với ALB
   - Manual scaling vs Auto Scaling
   - Response time under different loads

2. **Phân tích chi phí**:
   - Fixed cost (single large instance) vs Variable cost (auto scaling)
   - Cost optimization strategies
   - ROI analysis

3. **Đánh giá khả năng chịu tải**:
   - Baseline: 50 concurrent users
   - Peak load: 200-500 concurrent users
   - Breaking point testing

---

## PHẦN 3: ĐỐI TƯỢNG VÀ PHẠM VI NGHIÊN CỨU

### 3.1. Đối tượng nghiên cứu
- **Hệ thống**: Course Registration System (Hệ thống đăng ký khóa học)
- **Công nghệ**: AWS Cloud Services (ALB, ASG, EC2, DynamoDB)
- **Use case**: Quản lý sinh viên, giáo viên, khóa học, đăng ký môn học

### 3.2. Phạm vi nghiên cứu

#### Trong phạm vi:
✅ Application Load Balancer (Layer 7)
✅ Auto Scaling Group với CPU-based policy
✅ EC2 instances (t3.micro - Free tier eligible)
✅ DynamoDB (NoSQL database)
✅ CloudWatch monitoring
✅ Docker containerization
✅ Single region deployment (us-east-1)

#### Ngoài phạm vi:
❌ Network Load Balancer (Layer 4)
❌ Multi-region deployment
❌ Advanced scaling policies (ML-based, scheduled)
❌ RDS database clustering
❌ Kubernetes/ECS orchestration
❌ CI/CD pipeline automation

---

## PHẦN 4: PHƯƠNG PHÁP NGHIÊN CỨU

### 4.1. Phương pháp thiết kế hệ thống
- **Architecture Design**: 3-tier architecture (Frontend - Backend - Database)
- **Infrastructure as Code**: AWS CLI scripts, PowerShell automation
- **Containerization**: Docker multi-stage builds
- **Security**: JWT authentication, IAM roles, Security Groups

### 4.2. Phương pháp thử nghiệm

#### 4.2.1. Load Testing
**Tool**: Python requests library (custom stress test script)
- Concurrent users: 5, 50, 100, 200, 500
- Duration: 1, 5, 10 minutes
- Request types: GET (70%), POST (30%)
- Metrics thu thập:
  - Requests per second (RPS)
  - Response time (avg, min, max, p95, p99)
  - Success rate (%)
  - Error rate & types

#### 4.2.2. High Availability Testing
- **Instance failure simulation**: Stop random EC2 instance
- **Health check validation**: Measure detection time
- **Failover time**: Time to route traffic to healthy instances
- **Auto-recovery**: Time to launch replacement instance

#### 4.2.3. Auto Scaling Testing
- **Scale-out**: Time from trigger to new instance healthy
- **Scale-in**: Time from idle to instance termination
- **Performance impact**: Response time before/during/after scaling

### 4.3. Phương pháp đánh giá

#### 4.3.1. Tiêu chí hiệu năng:
- Response time < 500ms (baseline)
- Response time < 1000ms (under load)
- Success rate ≥ 99%
- Uptime ≥ 99.9%

#### 4.3.2. Tiêu chí chi phí:
- Chi phí giờ thấp điểm (1-2 instances)
- Chi phí giờ cao điểm (4-6 instances)
- Chi phí trung bình/tháng
- So sánh với giải pháp fixed capacity

---

## PHẦN 5: KẾ HOẠCH THỰC HIỆN

### 5.1. Giai đoạn 1: Nghiên cứu & Thiết kế (2 tuần)
**Tuần 1-2:**
- Nghiên cứu AWS services: ALB, ASG, EC2, DynamoDB
- Thiết kế kiến trúc hệ thống
- Thiết kế database schema
- Lập kế hoạch chi tiết

**Deliverables:**
- Architecture diagram
- Database schema
- Technical specification document

### 5.2. Giai đoạn 2: Phát triển ứng dụng (3 tuần)
**Tuần 3-4: Backend**
- Setup FastAPI project structure
- Implement authentication (JWT)
- Implement CRUD APIs (Courses, Enrollments)
- DynamoDB integration
- Unit testing

**Tuần 5: Frontend**
- Setup React + Vite project
- Implement UI components
- API integration
- Authentication flow

**Deliverables:**
- Working application (local)
- Source code repository
- API documentation

### 5.3. Giai đoạn 3: Containerization & AWS Setup (2 tuần)
**Tuần 6:**
- Docker containerization
- Test docker-compose locally
- Push images to Amazon ECR

**Tuần 7:**
- Setup VPC, Security Groups
- Create Launch Template
- Configure ALB + Target Group
- Setup Auto Scaling Group
- Deploy to AWS

**Deliverables:**
- Docker images
- Infrastructure scripts
- Deployed application on AWS

### 5.4. Giai đoạn 4: Testing & Monitoring (2 tuần)
**Tuần 8:**
- Setup CloudWatch dashboard
- Configure alarms
- Develop load testing scripts
- Baseline performance testing

**Tuần 9:**
- Load testing (50, 100, 200, 500 users)
- High availability testing
- Auto scaling testing
- Performance analysis

**Deliverables:**
- Test results & metrics
- CloudWatch dashboards
- Performance report

### 5.5. Giai đoạn 5: Tối ưu & Hoàn thiện (2 tuần)
**Tuần 10:**
- Performance optimization
- Cost optimization
- Security hardening
- Documentation

**Tuần 11:**
- Final testing
- Demo preparation
- Report writing

**Deliverables:**
- Final report
- Demo video
- Presentation slides

---

## PHẦN 6: DỰ KIẾN KẾT QUẢ

### 6.1. Sản phẩm
1. **Hệ thống Course Registration hoàn chỉnh**:
   - Web application (Frontend + Backend)
   - Deployed on AWS with ALB + ASG
   - High availability & auto scaling
   - Monitoring & alerting

2. **Source code & Documentation**:
   - GitHub repository with clean code
   - API documentation (Swagger/OpenAPI)
   - Deployment guide
   - User manual

3. **Infrastructure Automation Scripts**:
   - Setup scripts (PowerShell, Bash)
   - Monitoring scripts
   - Load testing scripts
   - Cleanup scripts

### 6.2. Nghiên cứu
1. **Performance Analysis Report**:
   - Baseline performance metrics
   - Load testing results (multiple scenarios)
   - Comparison: Single vs Multi-instance
   - Response time distribution charts

2. **Cost Analysis Report**:
   - Monthly cost breakdown
   - Cost comparison: Fixed vs Auto Scaling
   - ROI calculation
   - Cost optimization recommendations

3. **High Availability Analysis**:
   - Uptime statistics
   - Failover time measurements
   - Auto-recovery test results
   - Incident response analysis

### 6.3. Bài báo/Báo cáo khoa học
- Đề xuất xuất bản bài báo tại hội nghị/tạp chí về Cloud Computing
- Chia sẻ kinh nghiệm triển khai AWS cho cộng đồng

---

## PHẦN 7: TÍNH KHẢ THI

### 7.1. Về kỹ thuật
✅ **Công nghệ sử dụng**: Đều là open-source hoặc AWS Free Tier
✅ **Kiến thức**: Python, JavaScript, Docker, AWS basics
✅ **Tài liệu**: AWS documentation đầy đủ, cộng đồng hỗ trợ lớn

### 7.2. Về kinh phí
**Chi phí dự kiến**: ~$50-100 cho toàn bộ dự án (3 tháng)

| Hạng mục | Chi phí/tháng | Ghi chú |
|----------|---------------|---------|
| EC2 instances (t3.micro) | $15-30 | Phụ thuộc số giờ chạy |
| Application Load Balancer | $16.20 | Fixed cost |
| DynamoDB | $0-5 | Free tier 25GB |
| Data Transfer | $0-5 | Ít traffic |
| CloudWatch | $0-3 | Basic monitoring |
| **TỔNG** | **~$31-60** | |

**Tối ưu chi phí**:
- Dừng instances khi không test: Chỉ còn $16/tháng (ALB)
- Sử dụng AWS Free Tier: 750 giờ EC2 miễn phí/tháng
- Testing vào cuối tháng để tận dụng free tier

### 7.3. Về thời gian
✅ **Tổng thời gian**: 11 tuần (2.5 tháng)
✅ **Thời gian mỗi tuần**: 15-20 giờ
✅ **Tổng effort**: 165-220 giờ

---

## PHẦN 8: Ý NGHĨA KHOA HỌC VÀ THỰC TIỄN

### 8.1. Ý nghĩa khoa học
1. **Đóng góp kiến thức**:
   - Nghiên cứu thực nghiệm về hiệu quả của ALB + ASG
   - Phân tích chi tiết về cost-performance trade-off
   - So sánh các chiến lược scaling

2. **Tài liệu tham khảo**:
   - Hướng dẫn triển khai chi tiết cho sinh viên/developer
   - Best practices cho AWS deployment
   - Real-world use cases

### 8.2. Ý nghĩa thực tiễn
1. **Cho sinh viên**:
   - Học được kỹ năng Cloud Computing thực tế
   - Hiểu về DevOps, Infrastructure as Code
   - Portfolio project để apply việc

2. **Cho doanh nghiệp nhỏ/startup**:
   - Giải pháp cost-effective để scale business
   - Giảm downtime, tăng customer satisfaction
   - Template để triển khai nhanh

3. **Cho giảng viên/nhà trường**:
   - Case study thực tế để giảng dạy
   - Lab exercises cho môn Cloud Computing
   - Demonstrative project

---

## PHẦN 9: TÀI LIỆU THAM KHẢO

### 9.1. Sách và tài liệu chính thức
1. Amazon Web Services (2023). *AWS Well-Architected Framework*. 
2. Amazon Web Services (2023). *Elastic Load Balancing Documentation*.
3. Amazon Web Services (2023). *Amazon EC2 Auto Scaling Documentation*.

### 9.2. Bài báo khoa học
1. Khazaei, H., et al. (2017). "Performance Analysis of Cloud Applications". *IEEE Transactions on Cloud Computing*.
2. Lorido-Botran, T., et al. (2014). "A Review of Auto-scaling Techniques for Cloud Computing". *Journal of Grid Computing*.

### 9.3. Tài nguyên trực tuyến
1. AWS Training and Certification: https://aws.amazon.com/training/
2. AWS Architecture Center: https://aws.amazon.com/architecture/
3. AWS Cloud Practitioner Essentials

---

## PHẦN 10: CAM KẾT

Tôi xin cam kết:
- Hoàn thành đề tài đúng thời gian, đúng nội dung đã đăng ký
- Sản phẩm và nghiên cứu là công trình độc lập, không sao chép
- Tuân thủ quy định về đạo đức nghiên cứu
- Báo cáo kết quả trung thực, khách quan

---

**Ngày đăng ký**: [Ngày/Tháng/Năm]

**Sinh viên thực hiện**: [Họ và tên]  
**Chữ ký**: __________________

**Giảng viên hướng dẫn**: [Họ và tên]  
**Chữ ký**: __________________
