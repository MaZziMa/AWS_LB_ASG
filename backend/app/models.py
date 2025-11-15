"""
Database Models (SQLAlchemy ORM)
Based on the Entity Relationship Diagram from SYSTEM_DESIGN.md
"""
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, Date, Time,
    ForeignKey, Enum, Text, CheckConstraint, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum
from app.database import Base


# Enums
class UserType(str, enum.Enum):
    STUDENT = "student"
    TEACHER = "teacher"
    ADMIN = "admin"


class StudentStatus(str, enum.Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    GRADUATED = "graduated"


class AdminRole(str, enum.Enum):
    SUPER_ADMIN = "super_admin"
    REGISTRAR = "registrar"
    DEAN = "dean"


class SectionStatus(str, enum.Enum):
    OPEN = "open"
    FULL = "full"
    CLOSED = "closed"


class DayOfWeek(str, enum.Enum):
    MONDAY = "Monday"
    TUESDAY = "Tuesday"
    WEDNESDAY = "Wednesday"
    THURSDAY = "Thursday"
    FRIDAY = "Friday"
    SATURDAY = "Saturday"
    SUNDAY = "Sunday"


class EnrollmentAction(str, enum.Enum):
    REGISTERED = "registered"
    APPROVED = "approved"
    DROPPED = "dropped"
    WAITLISTED = "waitlisted"


# Models
class User(Base):
    """User accounts (students, teachers, admins)"""
    __tablename__ = "users"
    
    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=False)
    phone = Column(String(20))
    user_type = Column(Enum(UserType), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    last_login = Column(DateTime)
    
    # Relationships
    student = relationship("Student", back_populates="user", uselist=False)
    teacher = relationship("Teacher", back_populates="user", uselist=False)
    admin = relationship("Admin", back_populates="user", uselist=False)
    
    __table_args__ = (
        Index('idx_users_username_active', 'username', 'is_active'),
    )


class Department(Base):
    """Academic departments"""
    __tablename__ = "departments"
    
    department_id = Column(Integer, primary_key=True, index=True)
    department_code = Column(String(20), unique=True, nullable=False)
    department_name = Column(String(100), nullable=False)
    description = Column(Text)
    head_teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"))
    
    # Relationships
    majors = relationship("Major", back_populates="department")
    courses = relationship("Course", back_populates="department")
    teachers = relationship("Teacher", back_populates="department", foreign_keys="[Teacher.department_id]")


class Major(Base):
    """Academic majors/programs"""
    __tablename__ = "majors"
    
    major_id = Column(Integer, primary_key=True, index=True)
    major_code = Column(String(20), unique=True, nullable=False)
    major_name = Column(String(100), nullable=False)
    department_id = Column(Integer, ForeignKey("departments.department_id"), nullable=False)
    total_credits_required = Column(Integer, nullable=False)
    
    # Relationships
    department = relationship("Department", back_populates="majors")
    students = relationship("Student", back_populates="major")


class Student(Base):
    """Student information"""
    __tablename__ = "students"
    
    student_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), unique=True, nullable=False)
    student_code = Column(String(20), unique=True, nullable=False)
    major_id = Column(Integer, ForeignKey("majors.major_id"), nullable=False)
    admission_year = Column(Integer, nullable=False)
    gpa = Column(Float, default=0.0)
    total_credits = Column(Integer, default=0)
    status = Column(Enum(StudentStatus), default=StudentStatus.ACTIVE, nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="student")
    major = relationship("Major", back_populates="students")
    enrollments = relationship("Enrollment", back_populates="student")
    
    __table_args__ = (
        Index('idx_students_major_status', 'major_id', 'status'),
    )


class Teacher(Base):
    """Teacher/instructor information"""
    __tablename__ = "teachers"
    
    teacher_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), unique=True, nullable=False)
    teacher_code = Column(String(20), unique=True, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.department_id"), nullable=False)
    title = Column(String(50))  # Professor, Associate Professor, etc.
    specialization = Column(String(100))
    
    # Relationships
    user = relationship("User", back_populates="teacher")
    department = relationship("Department", back_populates="teachers", foreign_keys=[department_id])
    courses = relationship("Course", back_populates="teacher")
    sections = relationship("CourseSection", back_populates="teacher")


class Admin(Base):
    """Admin user information"""
    __tablename__ = "admins"
    
    admin_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), unique=True, nullable=False)
    admin_code = Column(String(20), unique=True, nullable=False)
    role = Column(Enum(AdminRole), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="admin")


class Semester(Base):
    """Academic semesters"""
    __tablename__ = "semesters"
    
    semester_id = Column(Integer, primary_key=True, index=True)
    semester_code = Column(String(20), unique=True, nullable=False)  # 2024-1, 2024-2
    year = Column(Integer, nullable=False)
    term = Column(Integer, nullable=False)  # 1, 2, summer
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    registration_start = Column(DateTime, nullable=False)
    registration_end = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=False, nullable=False)
    
    # Relationships
    courses = relationship("Course", back_populates="semester")
    sections = relationship("CourseSection", back_populates="semester")


class Course(Base):
    """Courses offered"""
    __tablename__ = "courses"
    
    course_id = Column(Integer, primary_key=True, index=True)
    course_code = Column(String(20), unique=True, nullable=False)
    course_name = Column(String(100), nullable=False)
    credits = Column(Integer, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.department_id"), nullable=False)
    semester_id = Column(Integer, ForeignKey("semesters.semester_id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"))
    description = Column(Text)
    max_students = Column(Integer)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Relationships
    department = relationship("Department", back_populates="courses")
    semester = relationship("Semester", back_populates="courses")
    teacher = relationship("Teacher", back_populates="courses")
    sections = relationship("CourseSection", back_populates="course")
    prerequisites = relationship("Prerequisite", foreign_keys="[Prerequisite.course_id]", back_populates="course")
    
    __table_args__ = (
        Index('idx_courses_dept_active', 'department_id', 'is_active'),
    )


class CourseSection(Base):
    """Course sections (multiple sections per course)"""
    __tablename__ = "course_sections"
    
    section_id = Column(Integer, primary_key=True, index=True)
    course_id = Column(Integer, ForeignKey("courses.course_id"), nullable=False)
    semester_id = Column(Integer, ForeignKey("semesters.semester_id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.teacher_id"))
    section_code = Column(String(10), nullable=False)  # A1, A2, B1
    max_students = Column(Integer, nullable=False)
    enrolled_students = Column(Integer, default=0, nullable=False)
    available_slots = Column(Integer, nullable=False)
    status = Column(Enum(SectionStatus), default=SectionStatus.OPEN, nullable=False)
    
    # Relationships
    course = relationship("Course", back_populates="sections")
    semester = relationship("Semester", back_populates="sections")
    teacher = relationship("Teacher", back_populates="sections")
    schedules = relationship("CourseSchedule", back_populates="section")
    enrollments = relationship("Enrollment", back_populates="section")
    
    __table_args__ = (
        Index('idx_course_sections_semester_status', 'semester_id', 'status'),
        CheckConstraint('enrolled_students <= max_students', name='check_enrolled_le_max'),
        CheckConstraint('available_slots >= 0', name='check_slots_positive'),
    )


class Classroom(Base):
    """Classrooms"""
    __tablename__ = "classrooms"
    
    classroom_id = Column(Integer, primary_key=True, index=True)
    building = Column(String(50), nullable=False)
    room_number = Column(String(20), nullable=False)
    capacity = Column(Integer, nullable=False)
    equipment = Column(String(200))  # projector, computer, etc.
    
    # Relationships
    schedules = relationship("CourseSchedule", back_populates="classroom")


class CourseSchedule(Base):
    """Course schedules (time & location)"""
    __tablename__ = "course_schedules"
    
    schedule_id = Column(Integer, primary_key=True, index=True)
    section_id = Column(Integer, ForeignKey("course_sections.section_id"), nullable=False)
    classroom_id = Column(Integer, ForeignKey("classrooms.classroom_id"), nullable=False)
    day_of_week = Column(Enum(DayOfWeek), nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    
    # Relationships
    section = relationship("CourseSection", back_populates="schedules")
    classroom = relationship("Classroom", back_populates="schedules")


class Prerequisite(Base):
    """Course prerequisites"""
    __tablename__ = "prerequisites"
    
    prerequisite_id = Column(Integer, primary_key=True, index=True)
    course_id = Column(Integer, ForeignKey("courses.course_id"), nullable=False)
    required_course_id = Column(Integer, ForeignKey("courses.course_id"), nullable=False)
    min_grade = Column(Float)  # Minimum grade required
    
    # Relationships
    course = relationship("Course", foreign_keys=[course_id], back_populates="prerequisites")
    required_course = relationship("Course", foreign_keys=[required_course_id])


class EnrollmentStatus(Base):
    """Enrollment status lookup table"""
    __tablename__ = "enrollment_status"
    
    status_id = Column(Integer, primary_key=True, index=True)
    status_code = Column(String(20), unique=True, nullable=False)
    status_name = Column(String(50), nullable=False)
    description = Column(Text)
    
    # Relationships
    enrollments = relationship("Enrollment", back_populates="status")


class Enrollment(Base):
    """Student course enrollments"""
    __tablename__ = "enrollments"
    
    enrollment_id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.student_id"), nullable=False)
    section_id = Column(Integer, ForeignKey("course_sections.section_id"), nullable=False)
    semester_id = Column(Integer, ForeignKey("semesters.semester_id"), nullable=False)
    enrolled_at = Column(DateTime, default=func.now(), nullable=False)
    status_id = Column(Integer, ForeignKey("enrollment_status.status_id"), nullable=False)
    final_grade = Column(Float)
    grade_letter = Column(String(5))  # A, B+, B, C+, C, D, F
    attempt_number = Column(Integer, default=1, nullable=False)
    
    # Relationships
    student = relationship("Student", back_populates="enrollments")
    section = relationship("CourseSection", back_populates="enrollments")
    status = relationship("EnrollmentStatus", back_populates="enrollments")
    history = relationship("EnrollmentHistory", back_populates="enrollment")
    
    __table_args__ = (
        Index('idx_enrollments_student_semester', 'student_id', 'semester_id'),
        Index('idx_enrollments_section_status', 'section_id', 'status_id'),
    )


class EnrollmentHistory(Base):
    """Audit log for enrollment actions"""
    __tablename__ = "enrollment_history"
    
    history_id = Column(Integer, primary_key=True, index=True)
    enrollment_id = Column(Integer, ForeignKey("enrollments.enrollment_id"), nullable=False)
    action = Column(Enum(EnrollmentAction), nullable=False)
    action_time = Column(DateTime, default=func.now(), nullable=False)
    ip_address = Column(String(50))
    user_agent = Column(String(200))
    note = Column(Text)
    
    # Relationships
    enrollment = relationship("Enrollment", back_populates="history")
    
    __table_args__ = (
        Index('idx_enrollment_history_time', 'action_time'),
    )
