"""
API Routes - Enrollments (DynamoDB Implementation)
"""
from fastapi import APIRouter, HTTPException, status, Depends
from typing import List
import uuid
from datetime import datetime
from boto3.dynamodb.conditions import Key

from app.dynamodb import get_db, get_item, put_item, scan_items, update_item, delete_item, query_items, Tables, db
from app.auth import get_current_user
from app.schemas_dynamodb import TokenData
from boto3.dynamodb.conditions import Attr

router = APIRouter(prefix="/api/enrollments", tags=["Enrollments"])


@router.post("")
async def enroll_course(
    enrollment_data: dict,
    current_user: TokenData = Depends(get_current_user)
):
    """Enroll in a course"""
    course_id = enrollment_data.get('course_id')
    
    if not course_id:
        raise HTTPException(status_code=400, detail="course_id is required")
    
    # Check if course exists
    course = await get_item(Tables.COURSES, {'course_id': course_id})
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    
    if not course.get('is_active', False):
        raise HTTPException(status_code=400, detail="Course is not active")
    
    # Check if already enrolled using GSI
    table = db.get_table(Tables.ENROLLMENTS)
    response = table.query(
        IndexName='student-semester-index',
        KeyConditionExpression=Key('student_id').eq(current_user.user_id),
        FilterExpression=Attr('course_id').eq(course_id)
    )
    if response.get('Items'):
        raise HTTPException(status_code=400, detail="Already enrolled in this course")
    
    # Check capacity
    enrolled_count = course.get('enrolled_count', 0)
    max_students = course.get('max_students', 30)
    
    if enrolled_count >= max_students:
        raise HTTPException(status_code=400, detail="Course is full")
    
    # Create enrollment
    enrollment_id = str(uuid.uuid4())
    new_enrollment = {
        'enrollment_id': enrollment_id,
        'student_id': current_user.user_id,
        'course_id': course_id,
        'semester': course.get('semester', 'Fall 2025'),
        'status': 'enrolled',
        'grade': None,
        'enrollment_date': datetime.utcnow().isoformat(),
        'created_at': datetime.utcnow().isoformat()
    }
    
    # Save enrollment
    await put_item(Tables.ENROLLMENTS, new_enrollment)
    
    # Update course enrolled count
    await update_item(Tables.COURSES, {'course_id': course_id}, {
        'enrolled_count': enrolled_count + 1,
        'updated_at': datetime.utcnow().isoformat()
    })
    
    return new_enrollment


@router.get("/my-enrollments")
async def get_my_enrollments(
    current_user: TokenData = Depends(get_current_user)
):
    """Get current user's enrollments"""
    try:
        # Use GSI to query enrollments by student_id
        table = db.get_table(Tables.ENROLLMENTS)
        response = table.query(
            IndexName='student-semester-index',
            KeyConditionExpression=Key('student_id').eq(current_user.user_id)
        )
        my_enrollments = response.get('Items', [])
        
        # Enrich with course data
        result = []
        for enrollment in my_enrollments:
            course_id = enrollment.get('course_id')
            course = await get_item(Tables.COURSES, {'course_id': course_id})
            
            enrollment_with_course = {
                **enrollment,
                'course': course
            }
            result.append(enrollment_with_course)
        
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load enrollments: {str(e)}")


@router.delete("/{enrollment_id}")
async def drop_course(
    enrollment_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Drop a course (delete enrollment)"""
    # Check if enrollment exists
    enrollment = await get_item(Tables.ENROLLMENTS, {'enrollment_id': enrollment_id})
    
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found")
    
    # Check ownership
    if enrollment.get('student_id') != current_user.user_id and current_user.user_type != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only drop your own enrollments"
        )
    
    course_id = enrollment.get('course_id')
    
    # Delete enrollment
    await delete_item(Tables.ENROLLMENTS, {'enrollment_id': enrollment_id})
    
    # Update course enrolled count
    course = await get_item(Tables.COURSES, {'course_id': course_id})
    if course:
        enrolled_count = course.get('enrolled_count', 0)
        if enrolled_count > 0:
            await update_item(Tables.COURSES, {'course_id': course_id}, {
                'enrolled_count': enrolled_count - 1,
                'updated_at': datetime.utcnow().isoformat()
            })
    
    return {"message": "Course dropped successfully"}


@router.get("/course/{course_id}")
async def get_course_enrollments(
    course_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Get all enrollments for a course (admin/teacher only)"""
    if current_user.user_type not in ['admin', 'teacher']:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and teachers can view course enrollments"
        )
    
    # Get all enrollments
    all_enrollments = await scan_items(Tables.ENROLLMENTS)
    
    # Filter by course
    course_enrollments = [e for e in all_enrollments if e.get('course_id') == course_id]
    
    # Enrich with student data
    result = []
    for enrollment in course_enrollments:
        student_id = enrollment.get('student_id')
        student = await get_item(Tables.USERS, {'user_id': student_id})
        
        enrollment_with_student = {
            **enrollment,
            'student': student
        }
        result.append(enrollment_with_student)
    
    return result
