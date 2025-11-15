"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime, date, time
from app.models import UserType, StudentStatus, SectionStatus, DayOfWeek


# User Schemas
class UserBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    full_name: str = Field(..., max_length=100)
    phone: Optional[str] = None
    user_type: UserType


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserLogin(BaseModel):
    username: str
    password: str


class UserResponse(UserBase):
    user_id: int
    is_active: bool
    created_at: datetime
    last_login: Optional[datetime]
    
    class Config:
        from_attributes = True


# Token Schemas
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int
    username: str
    user_type: UserType


# Course Schemas
class CourseBase(BaseModel):
    course_code: str
    course_name: str
    credits: int = Field(..., ge=1, le=6)
    description: Optional[str] = None
    max_students: Optional[int] = None


class CourseCreate(CourseBase):
    department_id: int
    semester_id: int
    teacher_id: Optional[int] = None


class CourseResponse(CourseBase):
    course_id: int
    department_id: int
    semester_id: int
    teacher_id: Optional[int]
    is_active: bool
    
    class Config:
        from_attributes = True


# Course Section Schemas
class CourseSectionBase(BaseModel):
    section_code: str
    max_students: int = Field(..., gt=0)


class CourseSectionCreate(CourseSectionBase):
    course_id: int
    semester_id: int
    teacher_id: Optional[int] = None


class CourseSectionResponse(CourseSectionBase):
    section_id: int
    course_id: int
    semester_id: int
    teacher_id: Optional[int]
    enrolled_students: int
    available_slots: int
    status: SectionStatus
    
    class Config:
        from_attributes = True


# Schedule Schemas
class CourseScheduleBase(BaseModel):
    day_of_week: DayOfWeek
    start_time: time
    end_time: time
    start_date: date
    end_date: date


class CourseScheduleCreate(CourseScheduleBase):
    section_id: int
    classroom_id: int


class CourseScheduleResponse(CourseScheduleBase):
    schedule_id: int
    section_id: int
    classroom_id: int
    
    class Config:
        from_attributes = True


# Enrollment Schemas
class EnrollmentCreate(BaseModel):
    section_id: int
    
    @validator('section_id')
    def section_id_must_be_positive(cls, v):
        if v <= 0:
            raise ValueError('section_id must be positive')
        return v


class EnrollmentBatchCreate(BaseModel):
    section_ids: List[int] = Field(..., max_items=5)
    
    @validator('section_ids')
    def validate_section_ids(cls, v):
        if len(v) == 0:
            raise ValueError('At least one section_id required')
        if len(set(v)) != len(v):
            raise ValueError('Duplicate section_ids not allowed')
        return v


class EnrollmentResponse(BaseModel):
    enrollment_id: int
    student_id: int
    section_id: int
    semester_id: int
    enrolled_at: datetime
    status_id: int
    final_grade: Optional[float]
    grade_letter: Optional[str]
    
    class Config:
        from_attributes = True


class EnrollmentDetailResponse(EnrollmentResponse):
    """Detailed enrollment with course info"""
    course_name: str
    course_code: str
    section_code: str
    credits: int
    teacher_name: Optional[str]


# Student Schemas
class StudentBase(BaseModel):
    student_code: str
    admission_year: int
    major_id: int


class StudentCreate(StudentBase):
    user_id: int


class StudentResponse(StudentBase):
    student_id: int
    user_id: int
    gpa: float
    total_credits: int
    status: StudentStatus
    
    class Config:
        from_attributes = True


class StudentProfileResponse(StudentResponse):
    """Complete student profile with user info"""
    username: str
    email: str
    full_name: str
    phone: Optional[str]
    major_name: str
    department_name: str


# Semester Schemas
class SemesterBase(BaseModel):
    semester_code: str
    year: int
    term: int
    start_date: date
    end_date: date
    registration_start: datetime
    registration_end: datetime


class SemesterCreate(SemesterBase):
    pass


class SemesterResponse(SemesterBase):
    semester_id: int
    is_active: bool
    
    class Config:
        from_attributes = True


# Statistics & Analytics Schemas
class EnrollmentStatistics(BaseModel):
    total_enrollments: int
    successful_enrollments: int
    waitlist_enrollments: int
    dropped_enrollments: int
    success_rate: float


class SectionStatistics(BaseModel):
    section_id: int
    course_name: str
    section_code: str
    total_slots: int
    enrolled: int
    available: int
    enrollment_rate: float


class SystemHealthResponse(BaseModel):
    status: str
    timestamp: datetime
    database: str
    cache: str
    version: str


# Error Response Schema
class ErrorResponse(BaseModel):
    detail: str
    error_code: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
