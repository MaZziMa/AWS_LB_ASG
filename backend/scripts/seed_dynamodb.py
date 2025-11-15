"""
Seed DynamoDB with sample data for Course Registration System
"""
import sys
import os
from datetime import datetime, timedelta
import uuid
import asyncio

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.dynamodb import db, put_item, Tables
from app.auth import hash_password


async def seed_users():
    """Create sample users: admin, teachers, students"""
    print("📝 Seeding users...")
    
    users = [
        {
            'user_id': str(uuid.uuid4()),
            'username': 'admin',
            'email': 'admin@university.edu',
            'password_hash': hash_password('admin123'),
            'full_name': 'System Administrator',
            'user_type': 'admin',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'user_id': str(uuid.uuid4()),
            'username': 'teacher1',
            'email': 'john.smith@university.edu',
            'password_hash': hash_password('teacher123'),
            'full_name': 'Dr. John Smith',
            'user_type': 'teacher',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'user_id': str(uuid.uuid4()),
            'username': 'teacher2',
            'email': 'jane.doe@university.edu',
            'password_hash': hash_password('teacher123'),
            'full_name': 'Prof. Jane Doe',
            'user_type': 'teacher',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'user_id': str(uuid.uuid4()),
            'username': 'student1',
            'email': 'alice@student.edu',
            'password_hash': hash_password('student123'),
            'full_name': 'Alice Johnson',
            'user_type': 'student',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'user_id': str(uuid.uuid4()),
            'username': 'student2',
            'email': 'bob@student.edu',
            'password_hash': hash_password('student123'),
            'full_name': 'Bob Wilson',
            'user_type': 'student',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
    ]
    
    for user in users:
        await put_item(Tables.USERS, user)
        print(f"  ✅ Created user: {user['username']} ({user['user_type']})")
    
    return users


async def seed_courses(teacher_ids):
    """Create sample courses"""
    print("\n📚 Seeding courses...")
    
    courses = [
        {
            'course_id': str(uuid.uuid4()),
            'course_code': 'CS101',
            'course_name': 'Introduction to Programming',
            'department': 'Computer Science',
            'credits': 3,
            'description': 'Learn fundamental programming concepts using Python',
            'semester': 'Fall 2025',
            'max_students': 30,
            'enrolled_count': 0,
            'teacher_id': teacher_ids[0],
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'course_id': str(uuid.uuid4()),
            'course_code': 'CS201',
            'course_name': 'Data Structures and Algorithms',
            'department': 'Computer Science',
            'credits': 4,
            'description': 'Advanced data structures and algorithm design',
            'semester': 'Fall 2025',
            'max_students': 25,
            'enrolled_count': 0,
            'teacher_id': teacher_ids[0],
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'course_id': str(uuid.uuid4()),
            'course_code': 'MATH201',
            'course_name': 'Calculus II',
            'department': 'Mathematics',
            'credits': 4,
            'description': 'Integral calculus and series',
            'semester': 'Fall 2025',
            'max_students': 40,
            'enrolled_count': 0,
            'teacher_id': teacher_ids[1],
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'course_id': str(uuid.uuid4()),
            'course_code': 'PHYS101',
            'course_name': 'General Physics I',
            'department': 'Physics',
            'credits': 4,
            'description': 'Mechanics and thermodynamics',
            'semester': 'Fall 2025',
            'max_students': 35,
            'enrolled_count': 0,
            'teacher_id': teacher_ids[1],
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'course_id': str(uuid.uuid4()),
            'course_code': 'ENG101',
            'course_name': 'Academic Writing',
            'department': 'English',
            'credits': 3,
            'description': 'Essay writing and composition',
            'semester': 'Fall 2025',
            'max_students': 20,
            'enrolled_count': 0,
            'teacher_id': teacher_ids[1],
            'is_active': True,
            'created_at': datetime.utcnow().isoformat()
        },
    ]
    
    for course in courses:
        await put_item(Tables.COURSES, course)
        print(f"  ✅ Created course: {course['course_code']} - {course['course_name']}")
    
    return courses


async def seed_enrollments(student_ids, course_ids):
    """Create sample enrollments"""
    print("\n📋 Seeding enrollments...")
    
    enrollments = [
        {
            'enrollment_id': str(uuid.uuid4()),
            'student_id': student_ids[0],
            'course_id': course_ids[0],
            'semester': 'Fall 2025',
            'status': 'enrolled',
            'grade': None,
            'enrollment_date': datetime.utcnow().isoformat(),
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'enrollment_id': str(uuid.uuid4()),
            'student_id': student_ids[0],
            'course_id': course_ids[2],
            'semester': 'Fall 2025',
            'status': 'enrolled',
            'grade': None,
            'enrollment_date': datetime.utcnow().isoformat(),
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'enrollment_id': str(uuid.uuid4()),
            'student_id': student_ids[1],
            'course_id': course_ids[0],
            'semester': 'Fall 2025',
            'status': 'enrolled',
            'grade': None,
            'enrollment_date': datetime.utcnow().isoformat(),
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'enrollment_id': str(uuid.uuid4()),
            'student_id': student_ids[1],
            'course_id': course_ids[1],
            'semester': 'Fall 2025',
            'status': 'enrolled',
            'grade': None,
            'enrollment_date': datetime.utcnow().isoformat(),
            'created_at': datetime.utcnow().isoformat()
        },
    ]
    
    for enrollment in enrollments:
        await put_item(Tables.ENROLLMENTS, enrollment)
        print(f"  ✅ Created enrollment: Student {enrollment['student_id'][:8]}... → Course {enrollment['course_id'][:8]}...")
    
    return enrollments


async def main():
    """Main seeding function"""
    print("🌱 Starting DynamoDB seeding process...\n")
    
    try:
        # Connect to DynamoDB
        db.connect()
        print("✅ Connected to DynamoDB\n")
        
        # Seed data
        users = await seed_users()
        
        # Get teacher and student IDs
        teacher_ids = [u['user_id'] for u in users if u['user_type'] == 'teacher']
        student_ids = [u['user_id'] for u in users if u['user_type'] == 'student']
        
        courses = await seed_courses(teacher_ids)
        course_ids = [c['course_id'] for c in courses]
        
        enrollments = await seed_enrollments(student_ids, course_ids)
        
        # Summary
        print("\n" + "="*60)
        print("✅ Seeding completed successfully!")
        print("="*60)
        print(f"📊 Summary:")
        print(f"   - Users created: {len(users)}")
        print(f"   - Courses created: {len(courses)}")
        print(f"   - Enrollments created: {len(enrollments)}")
        print("\n🔐 Login credentials:")
        print("   Admin:    username=admin    password=admin123")
        print("   Teacher:  username=teacher1 password=teacher123")
        print("   Student:  username=student1 password=student123")
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ Error during seeding: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        db.disconnect()
        print("\n✅ Disconnected from DynamoDB")


if __name__ == "__main__":
    asyncio.run(main())
