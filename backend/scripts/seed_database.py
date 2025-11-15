#!/usr/bin/env python3
"""
Seed Database with Sample Data
Creates test users, courses, and enrollments
"""
import asyncio
import sys
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta

# Add parent directory to path
sys.path.insert(0, '..')

from app.database import AsyncSessionLocal, init_db
from app.models import (
    User, Student, Teacher, Admin, Department, Major, Semester,
    Course, CourseSection, Classroom, CourseSchedule,
    EnrollmentStatus, UserType, StudentStatus, SectionStatus, DayOfWeek
)
from app.auth import hash_password


async def create_enrollment_statuses(db: AsyncSession):
    """Create enrollment status lookup data"""
    statuses = [
        {"status_code": "registered", "status_name": "Registered", "description": "Successfully registered"},
        {"status_code": "waitlist", "status_name": "Waitlist", "description": "Added to waitlist"},
        {"status_code": "approved", "status_name": "Approved", "description": "Registration approved"},
        {"status_code": "dropped", "status_name": "Dropped", "description": "Course dropped"},
        {"status_code": "completed", "status_name": "Completed", "description": "Course completed"},
    ]
    
    for status_data in statuses:
        status = EnrollmentStatus(**status_data)
        db.add(status)
    
    await db.commit()
    print("✓ Enrollment statuses created")


async def create_departments_and_majors(db: AsyncSession):
    """Create departments and majors"""
    departments_data = [
        {"department_code": "CS", "department_name": "Computer Science", "description": "Department of Computer Science"},
        {"department_code": "MATH", "department_name": "Mathematics", "description": "Department of Mathematics"},
        {"department_code": "ENG", "department_name": "English", "description": "Department of English"},
    ]
    
    departments = []
    for dept_data in departments_data:
        dept = Department(**dept_data)
        db.add(dept)
        departments.append(dept)
    
    await db.flush()
    
    # Create majors
    majors_data = [
        {"major_code": "CS", "major_name": "Computer Science", "department_id": departments[0].department_id, "total_credits_required": 120},
        {"major_code": "SE", "major_name": "Software Engineering", "department_id": departments[0].department_id, "total_credits_required": 120},
        {"major_code": "MATH", "major_name": "Mathematics", "department_id": departments[1].department_id, "total_credits_required": 120},
    ]
    
    for major_data in majors_data:
        major = Major(**major_data)
        db.add(major)
    
    await db.commit()
    print("✓ Departments and majors created")
    return departments


async def create_users_and_students(db: AsyncSession, departments):
    """Create test users and students"""
    # Create admin user
    admin_user = User(
        username="admin",
        email="admin@university.edu",
        password_hash=hash_password("admin123"),
        full_name="System Administrator",
        user_type=UserType.ADMIN,
        is_active=True
    )
    db.add(admin_user)
    await db.flush()
    
    admin = Admin(
        user_id=admin_user.user_id,
        admin_code="ADM001",
        role="super_admin"
    )
    db.add(admin)
    
    # Create teacher user
    teacher_user = User(
        username="teacher1",
        email="teacher1@university.edu",
        password_hash=hash_password("teacher123"),
        full_name="John Doe",
        user_type=UserType.TEACHER,
        is_active=True
    )
    db.add(teacher_user)
    await db.flush()
    
    teacher = Teacher(
        user_id=teacher_user.user_id,
        teacher_code="TCH001",
        department_id=departments[0].department_id,
        title="Professor",
        specialization="Algorithms"
    )
    db.add(teacher)
    
    # Create 10 student users
    students = []
    for i in range(1, 11):
        student_user = User(
            username=f"student{i}",
            email=f"student{i}@university.edu",
            password_hash=hash_password("student123"),
            full_name=f"Student {i}",
            phone=f"123-456-{7890 + i}",
            user_type=UserType.STUDENT,
            is_active=True
        )
        db.add(student_user)
        await db.flush()
        
        student = Student(
            user_id=student_user.user_id,
            student_code=f"STU{2024000 + i}",
            major_id=1,  # CS major
            admission_year=2024,
            gpa=3.5 + (i * 0.05),
            total_credits=0,
            status=StudentStatus.ACTIVE
        )
        db.add(student)
        students.append(student)
    
    await db.commit()
    print("✓ Users, teachers, and students created")
    return teacher, students


async def create_semester(db: AsyncSession):
    """Create current semester"""
    now = datetime.now()
    semester = Semester(
        semester_code="2025-1",
        year=2025,
        term=1,
        start_date=now.date(),
        end_date=(now + timedelta(days=120)).date(),
        registration_start=now - timedelta(days=7),
        registration_end=now + timedelta(days=14),
        is_active=True
    )
    db.add(semester)
    await db.commit()
    print("✓ Semester created")
    return semester


async def create_classrooms(db: AsyncSession):
    """Create classrooms"""
    classrooms_data = [
        {"building": "A", "room_number": "101", "capacity": 50, "equipment": "Projector, Computer"},
        {"building": "A", "room_number": "102", "capacity": 40, "equipment": "Projector"},
        {"building": "B", "room_number": "201", "capacity": 60, "equipment": "Projector, Computer, Whiteboard"},
        {"building": "B", "room_number": "202", "capacity": 30, "equipment": "Computer Lab"},
    ]
    
    classrooms = []
    for room_data in classrooms_data:
        classroom = Classroom(**room_data)
        db.add(classroom)
        classrooms.append(classroom)
    
    await db.commit()
    print("✓ Classrooms created")
    return classrooms


async def create_courses_and_sections(db: AsyncSession, semester, teacher, departments, classrooms):
    """Create courses and sections"""
    courses_data = [
        {"course_code": "CS101", "course_name": "Introduction to Programming", "credits": 3, "max_students": 100},
        {"course_code": "CS102", "course_name": "Data Structures", "credits": 3, "max_students": 80},
        {"course_code": "CS201", "course_name": "Algorithms", "credits": 4, "max_students": 60},
        {"course_code": "CS202", "course_name": "Database Systems", "credits": 3, "max_students": 70},
        {"course_code": "MATH101", "course_name": "Calculus I", "credits": 4, "max_students": 120},
    ]
    
    sections = []
    for i, course_data in enumerate(courses_data):
        course = Course(
            **course_data,
            department_id=departments[0].department_id if i < 4 else departments[1].department_id,
            semester_id=semester.semester_id,
            teacher_id=teacher.teacher_id,
            description=f"Description for {course_data['course_name']}",
            is_active=True
        )
        db.add(course)
        await db.flush()
        
        # Create 2 sections per course
        for section_num in range(1, 3):
            section = CourseSection(
                course_id=course.course_id,
                semester_id=semester.semester_id,
                teacher_id=teacher.teacher_id,
                section_code=f"A{section_num}",
                max_students=course.max_students // 2,
                enrolled_students=0,
                available_slots=course.max_students // 2,
                status=SectionStatus.OPEN
            )
            db.add(section)
            await db.flush()
            
            # Create schedule
            schedule = CourseSchedule(
                section_id=section.section_id,
                classroom_id=classrooms[i % len(classrooms)].classroom_id,
                day_of_week=DayOfWeek.MONDAY if section_num == 1 else DayOfWeek.WEDNESDAY,
                start_time=datetime.strptime("09:00", "%H:%M").time(),
                end_time=datetime.strptime("11:00", "%H:%M").time(),
                start_date=semester.start_date,
                end_date=semester.end_date
            )
            db.add(schedule)
            sections.append(section)
    
    await db.commit()
    print("✓ Courses and sections created")
    return sections


async def main():
    """Main seeding function"""
    print("🌱 Starting database seeding...")
    
    # Initialize database
    await init_db()
    
    async with AsyncSessionLocal() as db:
        try:
            # Create data
            await create_enrollment_statuses(db)
            departments = await create_departments_and_majors(db)
            teacher, students = await create_users_and_students(db, departments)
            semester = await create_semester(db)
            classrooms = await create_classrooms(db)
            sections = await create_courses_and_sections(db, semester, teacher, departments, classrooms)
            
            print("\n✅ Database seeded successfully!")
            print(f"   - 3 Departments")
            print(f"   - 3 Majors")
            print(f"   - 1 Admin, 1 Teacher, 10 Students")
            print(f"   - 1 Active Semester")
            print(f"   - 4 Classrooms")
            print(f"   - 5 Courses with 10 Sections")
            print(f"\n🔑 Login credentials:")
            print(f"   Admin: username=admin, password=admin123")
            print(f"   Teacher: username=teacher1, password=teacher123")
            print(f"   Students: username=student1-10, password=student123")
            
        except Exception as e:
            print(f"\n❌ Error seeding database: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
