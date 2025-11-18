# Initialize Backend Database with Sample Data
# Creates DynamoDB tables and populates with initial data

param(
    [string]$Region = "us-east-1",
    [string]$TablePrefix = "CourseReg"
)

Write-Host "=== Initializing Database with Sample Data ===" -ForegroundColor Cyan

# Create tables first
Write-Host "`n[Step 1] Creating DynamoDB tables..." -ForegroundColor Green
.\create-dynamodb-tables.ps1 -Region $Region -TablePrefix $TablePrefix

Write-Host "`n[Step 2] Waiting for tables to become active..." -ForegroundColor Green
Start-Sleep -Seconds 10

# Create Python script for data initialization
$initScript = @'
import boto3
import hashlib
import json
from datetime import datetime, timedelta
import sys

region = sys.argv[1] if len(sys.argv) > 1 else "us-east-1"
prefix = sys.argv[2] if len(sys.argv) > 2 else "CourseReg"

dynamodb = boto3.resource('dynamodb', region_name=region)

def hash_password(password):
    """Simple password hashing"""
    return hashlib.sha256(password.encode()).hexdigest()

print("[Step 3] Inserting sample data...")

# 1. Departments
print("  - Departments...")
dept_table = dynamodb.Table(f"{prefix}_Departments")
departments = [
    {"department_id": "DEPT001", "name": "Computer Science", "code": "CS"},
    {"department_id": "DEPT002", "name": "Mathematics", "code": "MATH"},
    {"department_id": "DEPT003", "name": "Physics", "code": "PHYS"},
]
for dept in departments:
    dept_table.put_item(Item=dept)

# 2. Majors
print("  - Majors...")
major_table = dynamodb.Table(f"{prefix}_Majors")
majors = [
    {"major_id": "MAJ001", "name": "Computer Science", "code": "CS", "department_id": "DEPT001"},
    {"major_id": "MAJ002", "name": "Software Engineering", "code": "SE", "department_id": "DEPT001"},
    {"major_id": "MAJ003", "name": "Applied Mathematics", "code": "AMATH", "department_id": "DEPT002"},
]
for major in majors:
    major_table.put_item(Item=major)

# 3. Semesters
print("  - Semesters...")
semester_table = dynamodb.Table(f"{prefix}_Semesters")
semesters = [
    {
        "semester_id": "SEM202401",
        "name": "Spring 2024",
        "code": "SP24",
        "start_date": "2024-01-15",
        "end_date": "2024-05-15",
        "is_active": False
    },
    {
        "semester_id": "SEM202402",
        "name": "Fall 2024",
        "code": "FA24",
        "start_date": "2024-08-15",
        "end_date": "2024-12-15",
        "is_active": False
    },
    {
        "semester_id": "SEM202501",
        "name": "Spring 2025",
        "code": "SP25",
        "start_date": "2025-01-15",
        "end_date": "2025-05-15",
        "is_active": True
    }
]
for sem in semesters:
    semester_table.put_item(Item=sem)

# 4. Users (base users)
print("  - Users...")
user_table = dynamodb.Table(f"{prefix}_Users")
users = [
    {
        "user_id": "USER001",
        "email": "student1@university.edu",
        "password_hash": hash_password("password123"),
        "role": "student",
        "is_active": True,
        "created_at": datetime.now().isoformat()
    },
    {
        "user_id": "USER002",
        "email": "student2@university.edu",
        "password_hash": hash_password("password123"),
        "role": "student",
        "is_active": True,
        "created_at": datetime.now().isoformat()
    },
    {
        "user_id": "USER003",
        "email": "teacher1@university.edu",
        "password_hash": hash_password("password123"),
        "role": "teacher",
        "is_active": True,
        "created_at": datetime.now().isoformat()
    },
    {
        "user_id": "USER004",
        "email": "admin@university.edu",
        "password_hash": hash_password("admin123"),
        "role": "admin",
        "is_active": True,
        "created_at": datetime.now().isoformat()
    }
]
for user in users:
    user_table.put_item(Item=user)

# 5. Students
print("  - Students...")
student_table = dynamodb.Table(f"{prefix}_Students")
students = [
    {
        "student_id": "STU001",
        "user_id": "USER001",
        "student_code": "CS2024001",
        "first_name": "John",
        "last_name": "Doe",
        "major_id": "MAJ001",
        "enrollment_year": 2024,
        "current_semester": 1
    },
    {
        "student_id": "STU002",
        "user_id": "USER002",
        "student_code": "CS2024002",
        "first_name": "Jane",
        "last_name": "Smith",
        "major_id": "MAJ002",
        "enrollment_year": 2024,
        "current_semester": 1
    }
]
for student in students:
    student_table.put_item(Item=student)

# 6. Teachers
print("  - Teachers...")
teacher_table = dynamodb.Table(f"{prefix}_Teachers")
teachers = [
    {
        "teacher_id": "TCH001",
        "user_id": "USER003",
        "teacher_code": "PROF001",
        "first_name": "Dr. Robert",
        "last_name": "Johnson",
        "department_id": "DEPT001",
        "title": "Professor"
    }
]
for teacher in teachers:
    teacher_table.put_item(Item=teacher)

# 7. Admins
print("  - Admins...")
admin_table = dynamodb.Table(f"{prefix}_Admins")
admins = [
    {
        "admin_id": "ADM001",
        "user_id": "USER004",
        "first_name": "Admin",
        "last_name": "User",
        "role": "system_admin"
    }
]
for admin in admins:
    admin_table.put_item(Item=admin)

# 8. Courses
print("  - Courses...")
course_table = dynamodb.Table(f"{prefix}_Courses")
courses = [
    {
        "course_id": "CRS001",
        "course_code": "CS101",
        "course_name": "Introduction to Programming",
        "department_id": "DEPT001",
        "credits": 3,
        "description": "Basic programming concepts using Python"
    },
    {
        "course_id": "CRS002",
        "course_code": "CS102",
        "course_name": "Data Structures",
        "department_id": "DEPT001",
        "credits": 4,
        "description": "Arrays, linked lists, trees, graphs"
    },
    {
        "course_id": "CRS003",
        "course_code": "CS201",
        "course_name": "Algorithms",
        "department_id": "DEPT001",
        "credits": 4,
        "description": "Algorithm design and analysis"
    },
    {
        "course_id": "CRS004",
        "course_code": "MATH101",
        "course_name": "Calculus I",
        "department_id": "DEPT002",
        "credits": 4,
        "description": "Differential calculus"
    }
]
for course in courses:
    course_table.put_item(Item=course)

# 9. Prerequisites
print("  - Prerequisites...")
prereq_table = dynamodb.Table(f"{prefix}_Prerequisites")
prereqs = [
    {"course_id": "CRS002", "prerequisite_course_id": "CRS001"},
    {"course_id": "CRS003", "prerequisite_course_id": "CRS002"}
]
for prereq in prereqs:
    prereq_table.put_item(Item=prereq)

# 10. Classrooms
print("  - Classrooms...")
classroom_table = dynamodb.Table(f"{prefix}_Classrooms")
classrooms = [
    {"classroom_id": "ROOM001", "building": "Engineering", "room_number": "101", "capacity": 50},
    {"classroom_id": "ROOM002", "building": "Engineering", "room_number": "102", "capacity": 40},
    {"classroom_id": "ROOM003", "building": "Science", "room_number": "201", "capacity": 60}
]
for room in classrooms:
    classroom_table.put_item(Item=room)

# 11. Course Sections
print("  - Course Sections...")
section_table = dynamodb.Table(f"{prefix}_CourseSections")
sections = [
    {
        "section_id": "SEC001",
        "course_id": "CRS001",
        "semester_id": "SEM202501",
        "section_number": "01",
        "teacher_id": "TCH001",
        "max_students": 50,
        "enrolled_count": 0,
        "status": "open"
    },
    {
        "section_id": "SEC002",
        "course_id": "CRS002",
        "semester_id": "SEM202501",
        "section_number": "01",
        "teacher_id": "TCH001",
        "max_students": 40,
        "enrolled_count": 0,
        "status": "open"
    },
    {
        "section_id": "SEC003",
        "course_id": "CRS004",
        "semester_id": "SEM202501",
        "section_number": "01",
        "teacher_id": "TCH001",
        "max_students": 60,
        "enrolled_count": 0,
        "status": "open"
    }
]
for section in sections:
    section_table.put_item(Item=section)

# 12. Course Schedules
print("  - Course Schedules...")
schedule_table = dynamodb.Table(f"{prefix}_CourseSchedules")
schedules = [
    {
        "schedule_id": "SCH001",
        "section_id": "SEC001",
        "classroom_id": "ROOM001",
        "day_of_week": "Monday",
        "start_time": "09:00",
        "end_time": "10:30"
    },
    {
        "schedule_id": "SCH002",
        "section_id": "SEC001",
        "classroom_id": "ROOM001",
        "day_of_week": "Wednesday",
        "start_time": "09:00",
        "end_time": "10:30"
    },
    {
        "schedule_id": "SCH003",
        "section_id": "SEC002",
        "classroom_id": "ROOM002",
        "day_of_week": "Tuesday",
        "start_time": "10:00",
        "end_time": "11:30"
    },
    {
        "schedule_id": "SCH004",
        "section_id": "SEC002",
        "classroom_id": "ROOM002",
        "day_of_week": "Thursday",
        "start_time": "10:00",
        "end_time": "11:30"
    }
]
for schedule in schedules:
    schedule_table.put_item(Item=schedule)

print("\n✓ Sample data inserted successfully!")
print("\nTest accounts created:")
print("  Student 1: student1@university.edu / password123")
print("  Student 2: student2@university.edu / password123")
print("  Teacher:   teacher1@university.edu / password123")
print("  Admin:     admin@university.edu / admin123")
'@

$initScriptPath = ".\temp-init-data.py"
$initScript | Out-File -FilePath $initScriptPath -Encoding utf8

# Run Python script
Write-Host "`nRunning data initialization script..." -ForegroundColor Yellow
python $initScriptPath $Region $TablePrefix

Remove-Item $initScriptPath -ErrorAction SilentlyContinue

Write-Host "`n=== Database Initialization Complete ===" -ForegroundColor Green
Write-Host "`nYou can now deploy the application with:" -ForegroundColor Yellow
Write-Host "  .\deploy-project.ps1" -ForegroundColor White
