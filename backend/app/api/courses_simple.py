"""
API Routes - Courses (DynamoDB Implementation)
"""
from fastapi import APIRouter, HTTPException, status, Depends
from typing import Optional, List
import uuid
from datetime import datetime

from app.dynamodb import get_item, put_item, scan_items, query_items, update_item, delete_item, Tables, db
from app.auth import get_current_user
from app.schemas_dynamodb import TokenData
from boto3.dynamodb.conditions import Key, Attr

router = APIRouter(prefix="/api/courses", tags=["Courses"])


@router.get("")
async def list_courses(semester: Optional[str] = None):
    """List all courses, optionally filtered by semester"""
    try:
        if semester:
            # Use GSI index for fast semester queries
            table = db.get_table(Tables.COURSES)
            response = table.query(
                IndexName='semester-index',
                KeyConditionExpression=Key('semester').eq(semester),
                FilterExpression=Attr('is_active').eq(True)
            )
            courses = response.get('Items', [])
        else:
            # If no semester filter, scan all courses
            # Note: Consider requiring semester parameter for production
            courses = await scan_items(Tables.COURSES)
            courses = [c for c in courses if c.get('is_active', True)]
        
        return courses
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load courses: {str(e)}")


@router.get("/{course_id}")
async def get_course(course_id: str):
    """Get course details by ID"""
    course = await get_item(Tables.COURSES, {'course_id': course_id})
    
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    
    return course


@router.post("")
async def create_course(
    course_data: dict,
    current_user: TokenData = Depends(get_current_user)
):
    """Create a new course (admin only)"""
    # Check if user is admin
    if current_user.user_type != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can create courses"
        )
    
    # Generate course ID
    course_id = str(uuid.uuid4())
    
    # Prepare course data
    new_course = {
        'course_id': course_id,
        'course_code': course_data.get('course_code'),
        'course_name': course_data.get('course_name'),
        'department': course_data.get('department'),
        'credits': course_data.get('credits', 3),
        'description': course_data.get('description', ''),
        'semester': course_data.get('semester', 'Fall 2025'),
        'max_students': course_data.get('max_students', 30),
        'enrolled_count': 0,
        'teacher_id': course_data.get('teacher_id'),
        'is_active': True,
        'created_at': datetime.utcnow().isoformat(),
        'updated_at': datetime.utcnow().isoformat()
    }
    
    # Save to DynamoDB
    await put_item(Tables.COURSES, new_course)
    
    return new_course


@router.put("/{course_id}")
async def update_course(
    course_id: str,
    course_data: dict,
    current_user: TokenData = Depends(get_current_user)
):
    """Update course (admin only)"""
    if current_user.user_type != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can update courses"
        )
    
    # Check if course exists
    course = await get_item(Tables.COURSES, {'course_id': course_id})
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    
    # Update fields
    updates = {
        'updated_at': datetime.utcnow().isoformat()
    }
    
    # Add fields to update
    for field in ['course_code', 'course_name', 'department', 'credits', 
                  'description', 'semester', 'max_students', 'teacher_id']:
        if field in course_data:
            updates[field] = course_data[field]
    
    # Update in DynamoDB
    await update_item(Tables.COURSES, {'course_id': course_id}, updates)
    
    # Get updated course
    updated_course = await get_item(Tables.COURSES, {'course_id': course_id})
    return updated_course


@router.delete("/{course_id}")
async def delete_course(
    course_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Delete course (admin only) - soft delete by setting is_active to False"""
    if current_user.user_type != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can delete courses"
        )
    
    # Check if course exists
    course = await get_item(Tables.COURSES, {'course_id': course_id})
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    
    # Soft delete - set is_active to False
    await update_item(Tables.COURSES, {'course_id': course_id}, {
        'is_active': False,
        'updated_at': datetime.utcnow().isoformat()
    })
    
    return {"message": "Course deleted successfully"}
