"""
Simplified schemas for DynamoDB
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


# User Schemas
class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: str
    username: str
    user_type: str


class UserResponse(BaseModel):
    user_id: str
    username: str
    email: str
    full_name: str
    user_type: str
    is_active: bool


# Course Schemas
class CourseBase(BaseModel):
    course_code: str
    course_name: str
    credits: int
    description: Optional[str] = None


class CourseResponse(CourseBase):
    course_id: str
    semester_id: str
    department_id: str
    teacher_id: str


# Enrollment Schemas
class EnrollmentCreate(BaseModel):
    section_id: str


class EnrollmentResponse(BaseModel):
    enrollment_id: str
    student_id: str
    section_id: str
    status: str
    enrolled_at: str
