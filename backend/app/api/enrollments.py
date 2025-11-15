"""
API Routes - Enrollment Endpoints
Implements API endpoints from SYSTEM_DESIGN.md Section 4.5
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.database import get_db
from app.schemas import (
    EnrollmentCreate, EnrollmentResponse, EnrollmentDetailResponse,
    EnrollmentBatchCreate
)
from app.auth import get_current_student, TokenData
from app.services.enrollment_service import EnrollmentService
from app.models import Student

router = APIRouter(prefix="/api/enrollments", tags=["Enrollments"])


@router.post("", response_model=EnrollmentResponse, status_code=status.HTTP_201_CREATED)
async def enroll_in_course(
    enrollment_data: EnrollmentCreate,
    request: Request,
    current_user: TokenData = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
):
    """
    Register for a course section
    
    - Checks prerequisites
    - Checks schedule conflicts
    - Checks available slots
    - Creates enrollment or adds to waitlist
    """
    # Get student_id from user
    from sqlalchemy import select
    result = await db.execute(
        select(Student.student_id).where(Student.user_id == current_user.user_id)
    )
    student_id = result.scalar_one()
    
    # Get client info for audit log
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    return await EnrollmentService.enroll_student(
        db=db,
        student_id=student_id,
        section_id=enrollment_data.section_id,
        ip_address=ip_address,
        user_agent=user_agent
    )


@router.delete("/{enrollment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def drop_course(
    enrollment_id: int,
    current_user: TokenData = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
):
    """Drop a course enrollment"""
    from sqlalchemy import select
    result = await db.execute(
        select(Student.student_id).where(Student.user_id == current_user.user_id)
    )
    student_id = result.scalar_one()
    
    await EnrollmentService.drop_enrollment(db, enrollment_id, student_id)
    return


@router.get("/my", response_model=List[EnrollmentDetailResponse])
async def get_my_enrollments(
    semester_id: int = None,
    current_user: TokenData = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
):
    """Get current user's enrollments"""
    from sqlalchemy import select, and_
    from sqlalchemy.orm import joinedload
    from app.models import Enrollment, CourseSection, Course, Teacher, User
    
    # Get student_id
    result = await db.execute(
        select(Student.student_id).where(Student.user_id == current_user.user_id)
    )
    student_id = result.scalar_one()
    
    # Build query
    query = select(Enrollment).where(Enrollment.student_id == student_id)
    
    if semester_id:
        query = query.where(Enrollment.semester_id == semester_id)
    
    query = query.options(
        joinedload(Enrollment.section).joinedload(CourseSection.course),
        joinedload(Enrollment.section).joinedload(CourseSection.teacher).joinedload(Teacher.user)
    )
    
    result = await db.execute(query)
    enrollments = result.unique().scalars().all()
    
    # Build detailed response
    response = []
    for enr in enrollments:
        teacher_name = None
        if enr.section.teacher and enr.section.teacher.user:
            teacher_name = enr.section.teacher.user.full_name
        
        response.append(EnrollmentDetailResponse(
            enrollment_id=enr.enrollment_id,
            student_id=enr.student_id,
            section_id=enr.section_id,
            semester_id=enr.semester_id,
            enrolled_at=enr.enrolled_at,
            status_id=enr.status_id,
            final_grade=enr.final_grade,
            grade_letter=enr.grade_letter,
            course_name=enr.section.course.course_name,
            course_code=enr.section.course.course_code,
            section_code=enr.section.section_code,
            credits=enr.section.course.credits,
            teacher_name=teacher_name
        ))
    
    return response


@router.get("/{enrollment_id}/status")
async def check_enrollment_status(
    enrollment_id: int,
    current_user: TokenData = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
):
    """Check enrollment status"""
    from sqlalchemy import select
    from app.models import Enrollment, EnrollmentStatus
    
    result = await db.execute(
        select(Enrollment)
        .options(joinedload(Enrollment.status))
        .where(Enrollment.enrollment_id == enrollment_id)
    )
    enrollment = result.scalar_one_or_none()
    
    if not enrollment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Enrollment not found"
        )
    
    return {
        "enrollment_id": enrollment.enrollment_id,
        "status": enrollment.status.status_name,
        "enrolled_at": enrollment.enrolled_at
    }


@router.post("/waitlist", status_code=status.HTTP_201_CREATED)
async def join_waitlist(
    enrollment_data: EnrollmentCreate,
    current_user: TokenData = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
):
    """Manually join waitlist for a full section"""
    # Implementation similar to enroll_in_course but forces waitlist
    pass
