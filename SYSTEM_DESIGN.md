# Thiết Kế Hệ Thống Đăng Ký Môn Học - AWS Auto Scaling & Load Balancing

## Tổng Quan
Hệ thống đăng ký môn học được thiết kế để xử lý lượng truy cập cao trong thời gian đăng ký, sử dụng AWS Auto Scaling Group và Load Balancer để đảm bảo tính khả dụng và hiệu năng.

---

## 1. Sơ Đồ Kiến Trúc Hệ Thống (System Architecture)

```mermaid
flowchart TB
    subgraph Users["Người Dùng"]
        SV[Sinh Viên]
        GV[Giảng Viên]
        AD[Quản Trị Viên]
    end

    subgraph CloudFront["AWS CloudFront CDN"]
        CF[Content Delivery Network]
    end

    subgraph Route53["AWS Route 53"]
        DNS[DNS Management]
    end

    subgraph VPC["AWS VPC"]
        subgraph PublicSubnet["Public Subnet - Multi AZ"]
            subgraph ALB["Application Load Balancer"]
                LB[ALB - Health Check Enabled]
            end
            
            subgraph NAT["NAT Gateway"]
                NATGW[NAT Gateway]
            end
        end

        subgraph PrivateSubnet["Private Subnet - Multi AZ"]
            subgraph ASG["Auto Scaling Group"]
                WS1[Web Server 1<br/>EC2 Instance]
                WS2[Web Server 2<br/>EC2 Instance]
                WS3[Web Server 3<br/>EC2 Instance]
                WSN[Web Server N<br/>Auto Scale]
            end
            
            subgraph AppServers["Application Servers"]
                AS1[App Server 1<br/>Backend API]
                AS2[App Server 2<br/>Backend API]
            end
        end

        subgraph DataLayer["Data Layer - Multi AZ"]
            subgraph RDS["Amazon RDS"]
                DB1[(Primary DB<br/>MySQL/PostgreSQL)]
                DB2[(Standby DB<br/>Read Replica)]
            end
            
            subgraph Cache["ElastiCache"]
                REDIS[Redis Cluster<br/>Session & Cache]
            end
            
            subgraph Queue["SQS Queue"]
                SQS[Message Queue<br/>Async Processing]
            end
        end
    end

    subgraph Storage["Storage Services"]
        S3[S3 Bucket<br/>Static Assets]
        S3Backup[S3 Backup<br/>Database Backups]
    end

    subgraph Monitoring["Monitoring & Logging"]
        CW[CloudWatch<br/>Metrics & Alarms]
        CWL[CloudWatch Logs<br/>Application Logs]
        SNS[SNS<br/>Notifications]
    end

    Users --> DNS
    DNS --> CF
    CF --> LB
    LB --> WS1 & WS2 & WS3 & WSN
    WS1 & WS2 & WS3 & WSN --> AS1 & AS2
    AS1 & AS2 --> DB1
    AS1 & AS2 --> REDIS
    AS1 & AS2 --> SQS
    DB1 --> DB2
    WS1 & WS2 --> S3
    DB1 -.Backup.-> S3Backup
    
    ASG --> CW
    CW --> SNS
    LB --> CWL
    AS1 & AS2 --> CWL

    style ALB fill:#FF9900
    style ASG fill:#FF9900
    style RDS fill:#527FFF
    style Cache fill:#C925D1
    style Users fill:#232F3E
    style Monitoring fill:#FF9900
```

### Giải Thích Kiến Trúc:

#### **Lớp Client (Users)**
- **Sinh viên**: Đăng ký, xem lịch học, hủy môn
- **Giảng viên**: Quản lý môn học, xem danh sách sinh viên
- **Quản trị viên**: Quản lý hệ thống, cấu hình môn học

#### **Lớp CDN & DNS**
- **CloudFront**: Cache nội dung tĩnh, giảm latency
- **Route 53**: Quản lý DNS, health check, failover

#### **Lớp Load Balancing**
- **Application Load Balancer**: 
  - Phân phối traffic đều giữa các web servers
  - Health check tự động
  - SSL/TLS termination
  - Sticky sessions cho session management

#### **Lớp Application (Auto Scaling)**
- **Auto Scaling Group**:
  - Min: 2 instances (High Availability)
  - Max: 10-20 instances (tùy theo nhu cầu)
  - Scaling Policy: CPU > 70% hoặc Request Count
  - Multi-AZ deployment
- **Web Servers**: Nginx/Apache + React/Vue.js
- **App Servers**: Node.js/Python/Java backend API

#### **Lớp Data**
- **RDS**: 
  - Primary DB cho write operations
  - Read Replica cho read operations (phân tải)
  - Multi-AZ cho high availability
  - Automated backups
- **ElastiCache Redis**: 
  - Session storage
  - Cache dữ liệu môn học
  - Cache số lượng chỗ còn lại
- **SQS**: Xử lý async tasks (email notifications, logging)

#### **Lớp Storage**
- **S3**: Lưu trữ static assets (CSS, JS, images)
- **S3 Backup**: Backup database định kỳ

#### **Monitoring**
- **CloudWatch**: Metrics, alarms, auto-scaling triggers
- **CloudWatch Logs**: Centralized logging
- **SNS**: Alert notifications

---

## 2. Sơ Đồ Cơ Sở Dữ Liệu (Database Schema)

```mermaid
erDiagram
    USERS ||--o{ STUDENTS : "is"
    USERS ||--o{ TEACHERS : "is"
    USERS ||--o{ ADMINS : "is"
    
    STUDENTS ||--o{ ENROLLMENTS : "registers"
    COURSES ||--o{ ENROLLMENTS : "has"
    COURSES ||--o{ COURSE_SCHEDULES : "has"
    COURSES }o--|| TEACHERS : "taught by"
    COURSES }o--|| DEPARTMENTS : "belongs to"
    COURSES }o--|| SEMESTERS : "offered in"
    
    ENROLLMENTS ||--o{ ENROLLMENT_HISTORY : "tracks"
    ENROLLMENTS }o--|| ENROLLMENT_STATUS : "has"
    
    STUDENTS }o--|| MAJORS : "studies"
    MAJORS }o--|| DEPARTMENTS : "belongs to"
    
    COURSES ||--o{ PREREQUISITES : "requires"
    COURSES ||--o{ COURSE_SECTIONS : "divided into"
    COURSE_SECTIONS ||--o{ ENROLLMENTS : "contains"
    
    CLASSROOMS ||--o{ COURSE_SCHEDULES : "hosts"

    USERS {
        int user_id PK
        string username UK
        string email UK
        string password_hash
        string full_name
        string phone
        enum user_type "student, teacher, admin"
        boolean is_active
        timestamp created_at
        timestamp last_login
    }

    STUDENTS {
        int student_id PK
        int user_id FK
        string student_code UK
        int major_id FK
        int admission_year
        float gpa
        int total_credits
        enum status "active, suspended, graduated"
    }

    TEACHERS {
        int teacher_id PK
        int user_id FK
        string teacher_code UK
        int department_id FK
        string title "Professor, Associate Professor"
        string specialization
    }

    ADMINS {
        int admin_id PK
        int user_id FK
        string admin_code UK
        enum role "super_admin, registrar, dean"
    }

    DEPARTMENTS {
        int department_id PK
        string department_code UK
        string department_name
        string description
        int head_teacher_id FK
    }

    MAJORS {
        int major_id PK
        string major_code UK
        string major_name
        int department_id FK
        int total_credits_required
    }

    SEMESTERS {
        int semester_id PK
        string semester_code UK "2024-1, 2024-2"
        int year
        int term "1, 2, summer"
        date start_date
        date end_date
        date registration_start
        date registration_end
        boolean is_active
    }

    COURSES {
        int course_id PK
        string course_code UK
        string course_name
        int credits
        int department_id FK
        string description
        int max_students
        boolean is_active
    }

    COURSE_SECTIONS {
        int section_id PK
        int course_id FK
        int semester_id FK
        int teacher_id FK
        string section_code "A1, A2, B1"
        int max_students
        int enrolled_students
        int available_slots
        enum status "open, full, closed"
    }

    COURSE_SCHEDULES {
        int schedule_id PK
        int section_id FK
        int classroom_id FK
        enum day_of_week "Monday-Sunday"
        time start_time
        time end_time
        date start_date
        date end_date
    }

    CLASSROOMS {
        int classroom_id PK
        string building
        string room_number
        int capacity
        string equipment "projector, computer, etc"
    }

    PREREQUISITES {
        int prerequisite_id PK
        int course_id FK "Course that has prerequisite"
        int required_course_id FK "Required course"
        float min_grade "Minimum grade required"
    }

    ENROLLMENTS {
        int enrollment_id PK
        int student_id FK
        int section_id FK
        int semester_id FK
        timestamp enrolled_at
        enum status_id FK "registered, waitlist, approved, dropped, completed"
        float final_grade
        string grade_letter "A, B+, B, C+, C, D, F"
        int attempt_number "1st, 2nd attempt"
    }

    ENROLLMENT_STATUS {
        int status_id PK
        string status_code UK
        string status_name
        string description
    }

    ENROLLMENT_HISTORY {
        int history_id PK
        int enrollment_id FK
        enum action "registered, approved, dropped, waitlisted"
        timestamp action_time
        string ip_address
        string user_agent
        string note
    }
```

### Indexes Quan Trọng:
```sql
-- High-traffic queries optimization
CREATE INDEX idx_enrollments_student_semester ON ENROLLMENTS(student_id, semester_id);
CREATE INDEX idx_enrollments_section_status ON ENROLLMENTS(section_id, status_id);
CREATE INDEX idx_course_sections_semester_status ON COURSE_SECTIONS(semester_id, status);
CREATE INDEX idx_users_username_active ON USERS(username, is_active);
CREATE INDEX idx_enrollment_history_time ON ENROLLMENT_HISTORY(action_time);

-- Composite indexes for complex queries
CREATE INDEX idx_students_major_status ON STUDENTS(major_id, status);
CREATE INDEX idx_courses_dept_active ON COURSES(department_id, is_active);
```

---

## 3. Sơ Đồ Luồng Đăng Ký Môn Học (User Flow & Data Flow)

### 3.1. Luồng Người Dùng - Đăng Ký Môn Học

```mermaid
flowchart TD
    Start([Sinh Viên Truy Cập Hệ Thống]) --> Login{Đăng Nhập}
    Login -->|Thành Công| CheckRegPeriod{Kiểm Tra<br/>Thời Gian Đăng Ký}
    Login -->|Thất Bại| LoginError[Hiển thị Lỗi<br/>Đăng Nhập]
    LoginError --> Login
    
    CheckRegPeriod -->|Trong Thời Gian| Dashboard[Dashboard<br/>Trang Chủ]
    CheckRegPeriod -->|Ngoài Thời Gian| RegClosed[Thông Báo<br/>Hết Hạn Đăng Ký]
    RegClosed --> End1([Kết Thúc])
    
    Dashboard --> ViewCourses[Xem Danh Sách<br/>Môn Học]
    ViewCourses --> FilterSearch[Lọc/Tìm Kiếm<br/>Môn Học]
    FilterSearch --> CourseList[Hiển Thị DS<br/>Môn Học Khả Dụng]
    
    CourseList --> SelectCourse[Chọn Môn Học]
    SelectCourse --> CheckPrereq{Kiểm Tra<br/>Điều Kiện}
    
    CheckPrereq -->|Không Đủ ĐK| ShowError[Thông Báo Lỗi<br/>Không Đủ Điều Kiện]
    ShowError --> CourseList
    
    CheckPrereq -->|Đủ Điều Kiện| CheckSlot{Kiểm Tra<br/>Chỗ Trống}
    
    CheckSlot -->|Đã Đầy| Waitlist{Vào Danh Sách<br/>Chờ?}
    Waitlist -->|Có| AddWaitlist[Thêm Vào<br/>Waitlist]
    Waitlist -->|Không| CourseList
    AddWaitlist --> NotifyWait[Thông Báo<br/>Đang Chờ]
    NotifyWait --> ViewCart
    
    CheckSlot -->|Còn Chỗ| CheckConflict{Kiểm Tra<br/>Trùng Lịch}
    
    CheckConflict -->|Trùng Lịch| ConflictError[Thông Báo<br/>Trùng Lịch Học]
    ConflictError --> CourseList
    
    CheckConflict -->|Không Trùng| CheckCredits{Kiểm Tra<br/>Số Tín Chỉ}
    
    CheckCredits -->|Vượt Quá| CreditError[Thông Báo<br/>Vượt Số Tín Chỉ]
    CreditError --> CourseList
    
    CheckCredits -->|OK| AddToCart[Thêm Vào<br/>Giỏ Đăng Ký]
    AddToCart --> ContinueReg{Đăng Ký<br/>Thêm Môn?}
    
    ContinueReg -->|Có| CourseList
    ContinueReg -->|Không| ViewCart[Xem Giỏ<br/>Đăng Ký]
    
    ViewCart --> ReviewCart{Xem Lại<br/>Giỏ Hàng}
    ReviewCart -->|Chỉnh Sửa| EditCart[Sửa/Xóa Môn]
    EditCart --> ViewCart
    
    ReviewCart -->|Xác Nhận| SubmitReg[Gửi Đăng Ký]
    SubmitReg --> ProcessReg[Xử Lý Đăng Ký]
    
    ProcessReg --> Transaction{Transaction<br/>Database}
    
    Transaction -->|Lock Failed| QueueProcess[Xếp Hàng Chờ<br/>SQS Queue]
    QueueProcess --> RetryReg[Thử Lại<br/>Đăng Ký]
    RetryReg --> Transaction
    
    Transaction -->|Success| ReserveSlot[Giữ Chỗ<br/>Lock Record]
    ReserveSlot --> UpdateDB[Cập Nhật<br/>Database]
    UpdateDB --> ClearCache[Clear Cache<br/>Redis]
    ClearCache --> SendConfirm[Gửi Email<br/>Xác Nhận]
    SendConfirm --> Success[Thông Báo<br/>Đăng Ký Thành Công]
    
    Transaction -->|Failed| Failed[Thông Báo<br/>Đăng Ký Thất Bại]
    Failed --> Retry{Thử Lại?}
    Retry -->|Có| ProcessReg
    Retry -->|Không| ViewCart
    
    Success --> PrintSchedule[In Lịch Học]
    PrintSchedule --> End2([Kết Thúc])

    style Start fill:#90EE90
    style End1 fill:#FFB6C6
    style End2 fill:#90EE90
    style Transaction fill:#FFD700
    style Success fill:#90EE90
    style Failed fill:#FF6B6B
```

### 3.2. Luồng Dữ Liệu - Backend Processing

```mermaid
sequenceDiagram
    participant Client as Client Browser
    participant CF as CloudFront CDN
    participant ALB as Load Balancer
    participant WS as Web Server
    participant API as API Server
    participant Redis as Redis Cache
    participant DB as RDS Database
    participant SQS as SQS Queue
    participant Email as Email Service

    Note over Client,Email: Luồng Đăng Ký Môn Học Chi Tiết

    Client->>CF: 1. Request: GET /courses
    CF->>ALB: Forward Request
    ALB->>WS: Route to Available Server
    WS->>API: API Call: Get Courses
    
    API->>Redis: Check Cache: courses_list
    alt Cache Hit
        Redis-->>API: Return Cached Data
        API-->>WS: Course List
    else Cache Miss
        API->>DB: Query: SELECT * FROM courses<br/>WHERE semester_id = ? AND status = 'open'
        DB-->>API: Course Data
        API->>Redis: Store Cache (TTL: 60s)
        API-->>WS: Course List
    end
    
    WS-->>ALB: Response
    ALB-->>CF: Response
    CF-->>Client: 200 OK: Course List

    Note over Client,Email: Sinh Viên Chọn Môn và Gửi Đăng Ký

    Client->>ALB: 2. POST /api/enroll<br/>{student_id, section_id}
    ALB->>WS: Route Request
    WS->>API: Process Enrollment

    Note over API,DB: Kiểm Tra Điều Kiện

    API->>Redis: Get: student_info:{student_id}
    Redis-->>API: Student Data
    
    API->>Redis: Get: section_slots:{section_id}
    Redis-->>API: Available Slots Count
    
    alt Slots Available (from cache)
        Note over API: Proceed to validation
    else No Cache or Unreliable
        API->>DB: SELECT available_slots<br/>FROM course_sections<br/>WHERE section_id = ?<br/>FOR UPDATE
        DB-->>API: Real-time Slot Count
    end

    Note over API,DB: Critical Section - Transaction Begin

    API->>DB: START TRANSACTION
    
    API->>DB: Check Prerequisites<br/>SELECT grade FROM enrollments<br/>WHERE student_id = ?<br/>AND course_id IN (prerequisites)
    DB-->>API: Prerequisite Check Result
    
    alt Prerequisites Not Met
        API->>DB: ROLLBACK
        API-->>Client: 400 Error: Prerequisites Not Met
    else Prerequisites OK
        API->>DB: Check Schedule Conflict<br/>SELECT 1 FROM enrollments e<br/>JOIN course_schedules cs1 ON e.section_id<br/>JOIN course_schedules cs2<br/>WHERE overlap exists
        DB-->>API: Conflict Check Result
        
        alt Schedule Conflict
            API->>DB: ROLLBACK
            API-->>Client: 400 Error: Schedule Conflict
        else No Conflict
            API->>DB: Lock Row & Check Slot<br/>SELECT available_slots<br/>FROM course_sections<br/>WHERE section_id = ?<br/>FOR UPDATE
            DB-->>API: Current Slot Count
            
            alt No Slots Available
                API->>DB: INSERT INTO enrollments<br/>(..., status='waitlist')
                API->>DB: COMMIT
                API->>SQS: Queue: Send Waitlist Email
                API-->>Client: 200: Added to Waitlist
            else Slot Available
                API->>DB: INSERT INTO enrollments<br/>(..., status='registered')
                API->>DB: UPDATE course_sections<br/>SET available_slots = available_slots - 1,<br/>enrolled_students = enrolled_students + 1<br/>WHERE section_id = ?
                API->>DB: INSERT INTO enrollment_history<br/>(enrollment_id, action='registered')
                API->>DB: COMMIT
                
                Note over API,Redis: Update Cache After Success
                
                API->>Redis: DECR section_slots:{section_id}
                API->>Redis: DEL student_enrollments:{student_id}
                API->>Redis: DEL course_section:{section_id}
                
                API->>SQS: Queue: Send Confirmation Email
                API->>SQS: Queue: Update Analytics
                
                API-->>Client: 200: Enrollment Successful
                
                SQS->>Email: Send Confirmation Email
                Email-->>Client: Email Delivered
            end
        end
    end

    Note over Client,Email: Monitoring & Scaling

    API->>API: Log Metrics to CloudWatch
    
    alt High CPU Usage (>70%)
        API->>ALB: Report High Load
        ALB->>ALB: Trigger Auto Scaling
        Note over ALB: Scale Out: Add New Instances
    end
```

### 3.3. Luồng Xử Lý Khi Tải Cao (High Traffic Scenario)

```mermaid
flowchart TD
    subgraph LoadBalancing["Load Balancing & Scaling"]
        Traffic[Lượng Traffic Cao<br/>1000+ requests/second]
        ALB[Application Load Balancer]
        Health[Health Check<br/>Every 30s]
    end

    subgraph AutoScaling["Auto Scaling Logic"]
        CW[CloudWatch Metrics]
        Alarm1[CPU > 70%<br/>Alarm]
        Alarm2[Request Count > 5000<br/>Alarm]
        ScaleOut[Scale Out<br/>+2 Instances]
        ScaleIn[Scale In<br/>-1 Instance]
    end

    subgraph Caching["Caching Strategy"]
        RedisCheck{Redis<br/>Cache Hit?}
        GetCache[Lấy Từ Cache<br/>Latency: 1-2ms]
        GetDB[Query Database<br/>Latency: 50-100ms]
        SetCache[Cập Nhật Cache<br/>TTL: 30-60s]
    end

    subgraph RateLimiting["Rate Limiting"]
        RateLimit[API Rate Limit<br/>100 req/min per user]
        ThrottleCheck{Check<br/>Rate Limit}
        Allow[Allow Request]
        Block[429 Too Many<br/>Requests]
    end

    subgraph QueueProcessing["Queue Processing"]
        AsyncQueue[SQS Queue<br/>Non-Critical Tasks]
        EmailQ[Email Queue]
        LogQ[Logging Queue]
        AnalyticsQ[Analytics Queue]
        Worker[Background Workers<br/>Lambda/EC2]
    end

    subgraph DatabaseOpt["Database Optimization"]
        WriteDB[(Primary DB<br/>Write Operations)]
        ReadDB[(Read Replica<br/>Read Operations)]
        ConnPool[Connection Pool<br/>Max: 100]
        IndexOpt[Optimized Indexes<br/>Query Time: <50ms]
    end

    Traffic --> ALB
    ALB --> Health
    Health --> CW
    
    CW --> Alarm1
    CW --> Alarm2
    Alarm1 & Alarm2 --> ScaleOut
    
    ALB --> RateLimit
    RateLimit --> ThrottleCheck
    ThrottleCheck -->|Pass| Allow
    ThrottleCheck -->|Fail| Block
    
    Allow --> RedisCheck
    RedisCheck -->|Hit| GetCache
    RedisCheck -->|Miss| GetDB
    GetDB --> SetCache
    GetDB --> ConnPool
    
    ConnPool --> WriteDB
    ConnPool --> ReadDB
    WriteDB & ReadDB --> IndexOpt
    
    Allow --> AsyncQueue
    AsyncQueue --> EmailQ
    AsyncQueue --> LogQ
    AsyncQueue --> AnalyticsQ
    
    EmailQ & LogQ & AnalyticsQ --> Worker

    style Traffic fill:#FF6B6B
    style ScaleOut fill:#90EE90
    style GetCache fill:#90EE90
    style GetDB fill:#FFD700
    style Block fill:#FF6B6B
```

### 3.4. Luồng Xử Lý Đồng Thời (Concurrency Control)

```mermaid
flowchart LR
    subgraph Request["Concurrent Requests"]
        R1[Request 1<br/>Student A]
        R2[Request 2<br/>Student B]
        R3[Request 3<br/>Student C]
        R4[Request 4<br/>Student D]
    end

    subgraph OptimisticLock["Optimistic Locking"]
        OL1[Read: available_slots = 1<br/>version = 5]
        OL2{Update WHERE<br/>version = 5}
        OL3[SUCCESS<br/>version = 6]
        OL4[FAIL<br/>version changed]
    end

    subgraph PessimisticLock["Pessimistic Locking"]
        PL1[SELECT ... FOR UPDATE<br/>Row Locked]
        PL2[Student A Processing<br/>Others Wait]
        PL3[Update & Release Lock]
        PL4[Next Student Acquires Lock]
    end

    subgraph RedisLock["Distributed Lock - Redis"]
        RL1[SET lock:section:123<br/>NX EX 5]
        RL2{Lock<br/>Acquired?}
        RL3[Process Enrollment]
        RL4[DEL lock:section:123]
        RL5[Retry After 100ms]
    end

    subgraph QueueBased["Queue-Based Processing"]
        QB1[Add to Queue<br/>Position: 1]
        QB2[Add to Queue<br/>Position: 2]
        QB3[Add to Queue<br/>Position: 3]
        QB4[Process Sequentially<br/>FIFO]
        QB5[Notify User<br/>Real-time Updates]
    end

    R1 & R2 & R3 & R4 --> RL1
    RL1 --> RL2
    RL2 -->|Yes| RL3
    RL2 -->|No| RL5
    RL3 --> PL1
    RL5 -.Retry.-> RL2
    
    PL1 --> PL2
    PL2 --> PL3
    PL3 --> RL4
    RL4 --> PL4
    
    PL4 --> QB1 & QB2 & QB3
    QB1 & QB2 & QB3 --> QB4
    QB4 --> QB5

    style R1 fill:#87CEEB
    style R2 fill:#87CEEB
    style R3 fill:#87CEEB
    style R4 fill:#87CEEB
    style RL3 fill:#90EE90
    style RL5 fill:#FFD700
    style QB4 fill:#90EE90
```

---

## 4. Chi Tiết Kỹ Thuật Implementation

### 4.1. Auto Scaling Configuration

```json
{
  "AutoScalingGroup": {
    "MinSize": 2,
    "MaxSize": 20,
    "DesiredCapacity": 4,
    "HealthCheckType": "ELB",
    "HealthCheckGracePeriod": 300,
    "VPCZoneIdentifier": ["subnet-private-1a", "subnet-private-1b"],
    "TargetGroupARNs": ["arn:aws:elasticloadbalancing:..."],
    "ScalingPolicies": [
      {
        "PolicyName": "scale-out-cpu",
        "AdjustmentType": "ChangeInCapacity",
        "ScalingAdjustment": 2,
        "Cooldown": 300,
        "MetricAggregationType": "Average",
        "TargetTrackingConfiguration": {
          "PredefinedMetricType": "ASGAverageCPUUtilization",
          "TargetValue": 70.0
        }
      },
      {
        "PolicyName": "scale-out-request-count",
        "TargetTrackingConfiguration": {
          "PredefinedMetricType": "ALBRequestCountPerTarget",
          "TargetValue": 5000
        }
      }
    ]
  }
}
```

### 4.2. Load Balancer Configuration

```json
{
  "LoadBalancer": {
    "Type": "application",
    "Scheme": "internet-facing",
    "IpAddressType": "ipv4",
    "Subnets": ["subnet-public-1a", "subnet-public-1b"],
    "SecurityGroups": ["sg-alb"],
    "Listeners": [
      {
        "Protocol": "HTTPS",
        "Port": 443,
        "SslPolicy": "ELBSecurityPolicy-TLS-1-2-2017-01",
        "Certificates": [{"CertificateArn": "arn:aws:acm:..."}],
        "DefaultActions": [
          {
            "Type": "forward",
            "TargetGroupArn": "arn:aws:elasticloadbalancing:..."
          }
        ]
      }
    ],
    "TargetGroup": {
      "Protocol": "HTTP",
      "Port": 80,
      "HealthCheck": {
        "Protocol": "HTTP",
        "Path": "/health",
        "Interval": 30,
        "Timeout": 5,
        "HealthyThreshold": 2,
        "UnhealthyThreshold": 3
      },
      "Stickiness": {
        "Enabled": true,
        "Type": "lb_cookie",
        "DurationSeconds": 3600
      }
    }
  }
}
```

### 4.3. Redis Cache Strategy

```javascript
// Cache key patterns
const CACHE_KEYS = {
  courseList: (semesterId) => `courses:semester:${semesterId}`,
  courseDetail: (courseId) => `course:${courseId}`,
  sectionSlots: (sectionId) => `section:slots:${sectionId}`,
  studentEnrollments: (studentId) => `student:enrollments:${studentId}`,
  sessionData: (sessionId) => `session:${sessionId}`
};

// TTL Strategy
const CACHE_TTL = {
  courseList: 300,        // 5 minutes - moderate changes
  courseDetail: 3600,     // 1 hour - rarely changes
  sectionSlots: 30,       // 30 seconds - frequently changes
  studentEnrollments: 60, // 1 minute - moderate changes
  sessionData: 1800       // 30 minutes - session timeout
};

// Example: Get available slots with cache
async function getAvailableSlots(sectionId) {
  const cacheKey = CACHE_KEYS.sectionSlots(sectionId);
  
  // Try cache first
  let slots = await redis.get(cacheKey);
  
  if (slots === null) {
    // Cache miss - query database
    slots = await db.query(
      'SELECT available_slots FROM course_sections WHERE section_id = ?',
      [sectionId]
    );
    
    // Store in cache with short TTL (high volatility)
    await redis.setex(cacheKey, CACHE_TTL.sectionSlots, slots);
  }
  
  return slots;
}

// Invalidate cache after enrollment
async function invalidateCacheAfterEnrollment(studentId, sectionId) {
  const keys = [
    CACHE_KEYS.sectionSlots(sectionId),
    CACHE_KEYS.studentEnrollments(studentId)
  ];
  
  await redis.del(...keys);
}
```

### 4.4. Database Transaction - Enrollment

```sql
-- Optimized enrollment transaction with proper locking
START TRANSACTION;

-- 1. Lock the section row to prevent race conditions
SELECT 
    section_id,
    available_slots,
    max_students,
    enrolled_students
FROM course_sections
WHERE section_id = ?
FOR UPDATE;

-- 2. Check if slots available
-- This check is done in application code after locking

-- 3. Check prerequisites (if applicable)
SELECT COUNT(*) as met_prerequisites
FROM prerequisites p
LEFT JOIN enrollments e ON (
    e.student_id = ? 
    AND e.course_id = p.required_course_id
    AND e.grade_letter IN ('A', 'B+', 'B', 'C+', 'C')
    AND e.status_id = 'completed'
)
WHERE p.course_id = (
    SELECT course_id FROM course_sections WHERE section_id = ?
)
GROUP BY p.course_id
HAVING COUNT(p.prerequisite_id) = COUNT(e.enrollment_id);

-- 4. Check schedule conflicts
SELECT COUNT(*) as conflicts
FROM enrollments e1
JOIN course_sections cs1 ON e1.section_id = cs1.section_id
JOIN course_schedules sch1 ON cs1.section_id = sch1.section_id
JOIN course_schedules sch2 ON sch2.section_id = ?
WHERE e1.student_id = ?
  AND e1.semester_id = cs1.semester_id
  AND sch1.day_of_week = sch2.day_of_week
  AND (
    (sch1.start_time <= sch2.start_time AND sch1.end_time > sch2.start_time)
    OR
    (sch1.start_time < sch2.end_time AND sch1.end_time >= sch2.end_time)
  );

-- 5. If all checks pass, insert enrollment
INSERT INTO enrollments (
    student_id,
    section_id,
    semester_id,
    enrolled_at,
    status_id,
    attempt_number
) VALUES (
    ?,
    ?,
    (SELECT semester_id FROM course_sections WHERE section_id = ?),
    NOW(),
    'registered',
    1
);

-- 6. Update section counts
UPDATE course_sections
SET 
    enrolled_students = enrolled_students + 1,
    available_slots = available_slots - 1,
    status = CASE 
        WHEN available_slots - 1 <= 0 THEN 'full'
        ELSE 'open'
    END
WHERE section_id = ?;

-- 7. Log the enrollment action
INSERT INTO enrollment_history (
    enrollment_id,
    action,
    action_time,
    ip_address,
    user_agent
) VALUES (
    LAST_INSERT_ID(),
    'registered',
    NOW(),
    ?,
    ?
);

COMMIT;
```

### 4.5. API Endpoints

```javascript
// Core API Endpoints

// Authentication
POST   /api/auth/login              // Login
POST   /api/auth/logout             // Logout
POST   /api/auth/refresh            // Refresh token
GET    /api/auth/me                 // Get current user

// Courses
GET    /api/courses                 // List all courses (with filters)
GET    /api/courses/:id             // Get course detail
GET    /api/courses/:id/sections    // Get course sections
GET    /api/sections/:id            // Get section detail
GET    /api/sections/:id/schedule   // Get section schedule

// Enrollment
POST   /api/enrollments             // Register for course
DELETE /api/enrollments/:id         // Drop course
GET    /api/enrollments/my          // Get my enrollments
POST   /api/enrollments/waitlist    // Join waitlist
GET    /api/enrollments/:id/status  // Check enrollment status

// Student
GET    /api/students/me             // Get student profile
GET    /api/students/me/schedule    // Get my schedule
GET    /api/students/me/transcript  // Get transcript
PUT    /api/students/me             // Update profile

// Admin
GET    /api/admin/enrollments      // View all enrollments
PUT    /api/admin/enrollments/:id  // Approve/reject enrollment
GET    /api/admin/statistics       // Get system statistics
POST   /api/admin/sections         // Create new section

// Health & Monitoring
GET    /health                     // Health check for ALB
GET    /metrics                    // Prometheus metrics
```

### 4.6. Monitoring & Alerts

```yaml
# CloudWatch Alarms Configuration
Alarms:
  - Name: HighCPUUtilization
    Metric: CPUUtilization
    Threshold: 70
    Period: 300
    EvaluationPeriods: 2
    Action: ScaleOut + SNS Notification

  - Name: HighRequestCount
    Metric: RequestCount
    Threshold: 10000
    Period: 60
    EvaluationPeriods: 1
    Action: ScaleOut + SNS Notification

  - Name: High5XXErrors
    Metric: HTTPCode_Target_5XX_Count
    Threshold: 10
    Period: 60
    EvaluationPeriods: 2
    Action: SNS Notification to DevOps

  - Name: HighDatabaseConnections
    Metric: DatabaseConnections
    Threshold: 80
    Period: 300
    EvaluationPeriods: 1
    Action: SNS Notification

  - Name: LowAvailableSlots
    Custom Metric: AvailableSlots
    Threshold: 10
    Period: 60
    Action: Log to CloudWatch + Alert Admins

# Dashboard Widgets
Dashboard:
  - Widget: RequestCount (per minute)
  - Widget: ActiveInstances (ASG)
  - Widget: CPUUtilization (average)
  - Widget: ResponseTime (p50, p95, p99)
  - Widget: DatabaseConnections
  - Widget: CacheHitRate (Redis)
  - Widget: EnrollmentSuccessRate
```

---

## 5. Kế Hoạch Triển Khai (Deployment Plan)

### Phase 1: Infrastructure Setup (Week 1-2)
- [ ] Thiết lập VPC, Subnets, Security Groups
- [ ] Cấu hình RDS Database (Multi-AZ)
- [ ] Cấu hình ElastiCache Redis Cluster
- [ ] Thiết lập S3 Buckets
- [ ] Cấu hình CloudWatch Logging

### Phase 2: Application Deployment (Week 3-4)
- [ ] Deploy Backend API lên EC2 instances
- [ ] Cấu hình Load Balancer
- [ ] Thiết lập Auto Scaling Group
- [ ] Deploy Frontend lên S3 + CloudFront
- [ ] Cấu hình Route 53

### Phase 3: Testing (Week 5)
- [ ] Unit Testing
- [ ] Integration Testing
- [ ] Load Testing (JMeter/Locust)
- [ ] Security Testing
- [ ] Penetration Testing

### Phase 4: Optimization (Week 6)
- [ ] Database Query Optimization
- [ ] Cache Strategy Tuning
- [ ] Auto Scaling Policy Adjustment
- [ ] Performance Monitoring Setup

### Phase 5: Go-Live (Week 7)
- [ ] Soft Launch (Limited Users)
- [ ] Monitor System Performance
- [ ] Full Launch
- [ ] 24/7 Monitoring & Support

---

## 6. Ước Tính Chi Phí AWS (Monthly)

### Scenario 1: Normal Load (1000 students)
- **EC2 (t3.medium x 4 instances)**: $120
- **RDS (db.t3.large Multi-AZ)**: $280
- **ElastiCache (cache.t3.medium)**: $70
- **Load Balancer**: $25
- **CloudFront**: $15
- **S3**: $5
- **CloudWatch**: $10
- **Data Transfer**: $30
- **Total**: ~$555/month

### Scenario 2: High Load (10,000 students, registration period)
- **EC2 (t3.large x 12 instances)**: $600
- **RDS (db.r5.xlarge Multi-AZ)**: $800
- **ElastiCache (cache.r5.large cluster)**: $220
- **Load Balancer**: $50
- **CloudFront**: $80
- **S3**: $20
- **CloudWatch**: $30
- **Data Transfer**: $150
- **Total**: ~$1,950/month

---

## 7. Best Practices & Recommendations

### 7.1. Security
✅ Use HTTPS everywhere (SSL/TLS)
✅ Implement rate limiting per user
✅ Use AWS WAF to prevent DDoS
✅ Enable MFA for admin accounts
✅ Encrypt data at rest (RDS encryption)
✅ Regular security audits
✅ Use AWS Secrets Manager for credentials

### 7.2. Performance
✅ Use CloudFront CDN for static assets
✅ Implement aggressive caching strategy
✅ Use database connection pooling
✅ Optimize database queries with proper indexes
✅ Use async processing for non-critical tasks
✅ Implement pagination for large result sets
✅ Use compression (gzip) for API responses

### 7.3. Reliability
✅ Multi-AZ deployment for high availability
✅ Automated backups (daily)
✅ Health checks for all services
✅ Graceful degradation during failures
✅ Circuit breaker pattern for external services
✅ Disaster recovery plan

### 7.4. Scalability
✅ Stateless application design
✅ Horizontal scaling over vertical
✅ Use SQS for decoupling services
✅ Database read replicas
✅ Auto-scaling based on metrics
✅ Load testing before registration period

### 7.5. Monitoring
✅ Real-time monitoring dashboard
✅ Alert thresholds for critical metrics
✅ Application performance monitoring (APM)
✅ Log aggregation and analysis
✅ User behavior analytics
✅ Incident response procedures

---

## 8. Tech Stack Recommendation

### Frontend
- **Framework**: React.js / Vue.js / Next.js
- **UI Library**: Material-UI / Ant Design
- **State Management**: Redux / Zustand
- **HTTP Client**: Axios
- **WebSocket**: Socket.io (real-time updates)

### Backend
- **Runtime**: Node.js / Python (FastAPI) / Java (Spring Boot)
- **API**: RESTful / GraphQL
- **Authentication**: JWT + OAuth2
- **Validation**: Joi / Pydantic
- **ORM**: Sequelize / TypeORM / SQLAlchemy

### Database
- **Primary**: PostgreSQL / MySQL (RDS)
- **Cache**: Redis (ElastiCache)
- **Search**: Elasticsearch (optional)

### DevOps
- **CI/CD**: GitHub Actions / GitLab CI
- **IaC**: Terraform / CloudFormation
- **Containers**: Docker
- **Orchestration**: ECS / EKS (optional)

---

## 9. Tài Liệu Tham Khảo

- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Redis Caching Strategies](https://redis.io/docs/manual/patterns/)
- [Database Concurrency Control](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking.html)

---

**Lưu Ý**: Đây là thiết kế tham khảo. Trong thực tế cần điều chỉnh dựa trên:
- Số lượng sinh viên thực tế
- Ngân sách dự án
- Yêu cầu cụ thể của trường
- Quy mô môn học và lịch học
- Thời gian đăng ký (concurrent users)

**Version**: 1.0  
**Last Updated**: November 14, 2025  
**Author**: System Architecture Team
