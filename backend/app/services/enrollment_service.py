"""
Enrollment Service - Core Business Logic
Implements enrollment flow from SYSTEM_DESIGN.md Section 3.2
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import joinedload
from fastapi import HTTPException, status
from typing import List, Optional, Tuple
from datetime import datetime
import logging

from app.models import (
    Enrollment, CourseSection, Course, CourseSchedule, 
    Prerequisite, Student, EnrollmentHistory, EnrollmentStatus,
    SectionStatus, EnrollmentAction
)
from app.schemas import EnrollmentCreate, EnrollmentResponse
from app.cache import cache, CacheKeys, CacheTTL
from app.aws import sqs_client, cloudwatch_client

logger = logging.getLogger(__name__)


class EnrollmentService:
    """Service for handling course enrollment operations"""
    
    @staticmethod
    async def check_registration_period(db: AsyncSession, semester_id: int) -> bool:
        """Check if registration is open for the semester"""
        from app.models import Semester
        
        result = await db.execute(
            select(Semester).where(Semester.semester_id == semester_id)
        )
        semester = result.scalar_one_or_none()
        
        if not semester:
            return False
        
        now = datetime.utcnow()
        return semester.registration_start <= now <= semester.registration_end
    
    @staticmethod
    async def check_prerequisites(
        db: AsyncSession, 
        student_id: int, 
        course_id: int
    ) -> Tuple[bool, Optional[str]]:
        """
        Check if student meets course prerequisites
        Returns (is_met, error_message)
        """
        # Get prerequisites
        result = await db.execute(
            select(Prerequisite).where(Prerequisite.course_id == course_id)
        )
        prerequisites = result.scalars().all()
        
        if not prerequisites:
            return True, None
        
        # Check each prerequisite
        for prereq in prerequisites:
            # Check if student has completed the required course
            result = await db.execute(
                select(Enrollment)
                .where(
                    and_(
                        Enrollment.student_id == student_id,
                        Enrollment.course_id == prereq.required_course_id,
                        Enrollment.grade_letter.in_(['A', 'B+', 'B', 'C+', 'C'])
                    )
                )
            )
            completed = result.scalar_one_or_none()
            
            if not completed:
                return False, f"Missing prerequisite: Course ID {prereq.required_course_id}"
            
            if prereq.min_grade and completed.final_grade < prereq.min_grade:
                return False, f"Grade too low for prerequisite"
        
        return True, None
    
    @staticmethod
    async def check_schedule_conflict(
        db: AsyncSession,
        student_id: int,
        section_id: int,
        semester_id: int
    ) -> Tuple[bool, Optional[str]]:
        """
        Check if new section conflicts with student's existing schedule
        Returns (has_conflict, error_message)
        """
        # Get schedule for the new section
        result = await db.execute(
            select(CourseSchedule)
            .where(CourseSchedule.section_id == section_id)
        )
        new_schedules = result.scalars().all()
        
        # Get student's current enrollments for the semester
        result = await db.execute(
            select(Enrollment)
            .where(
                and_(
                    Enrollment.student_id == student_id,
                    Enrollment.semester_id == semester_id
                )
            )
            .options(joinedload(Enrollment.section))
        )
        current_enrollments = result.scalars().all()
        
        # Check for time conflicts
        for enrollment in current_enrollments:
            result = await db.execute(
                select(CourseSchedule)
                .where(CourseSchedule.section_id == enrollment.section_id)
            )
            existing_schedules = result.scalars().all()
            
            for new_sch in new_schedules:
                for exist_sch in existing_schedules:
                    if new_sch.day_of_week == exist_sch.day_of_week:
                        # Check time overlap
                        if (new_sch.start_time <= exist_sch.start_time < new_sch.end_time or
                            new_sch.start_time < exist_sch.end_time <= new_sch.end_time):
                            return True, "Schedule conflict detected"
        
        return False, None
    
    @staticmethod
    async def check_credit_limit(
        db: AsyncSession,
        student_id: int,
        semester_id: int,
        new_credits: int,
        max_credits: int = 24
    ) -> Tuple[bool, Optional[str]]:
        """
        Check if adding new course exceeds credit limit
        Returns (exceeds_limit, error_message)
        """
        # Calculate current credits
        result = await db.execute(
            select(func.sum(Course.credits))
            .join(CourseSection, CourseSection.course_id == Course.course_id)
            .join(Enrollment, Enrollment.section_id == CourseSection.section_id)
            .where(
                and_(
                    Enrollment.student_id == student_id,
                    Enrollment.semester_id == semester_id
                )
            )
        )
        current_credits = result.scalar() or 0
        
        if current_credits + new_credits > max_credits:
            return True, f"Exceeds credit limit ({current_credits + new_credits}/{max_credits})"
        
        return False, None
    
    @staticmethod
    async def get_available_slots(
        db: AsyncSession,
        section_id: int,
        use_cache: bool = True
    ) -> int:
        """Get available slots for a section (with cache)"""
        if use_cache:
            # Try cache first
            cache_key = CacheKeys.section_slots(section_id)
            cached_slots = await cache.get(cache_key)
            if cached_slots is not None:
                return cached_slots
        
        # Query database with row lock
        result = await db.execute(
            select(CourseSection.available_slots)
            .where(CourseSection.section_id == section_id)
            .with_for_update()
        )
        slots = result.scalar_one_or_none()
        
        if slots is not None and use_cache:
            # Update cache
            await cache.set(
                CacheKeys.section_slots(section_id),
                slots,
                CacheTTL.SECTION_SLOTS
            )
        
        return slots if slots is not None else 0
    
    @staticmethod
    async def enroll_student(
        db: AsyncSession,
        student_id: int,
        section_id: int,
        ip_address: str = None,
        user_agent: str = None
    ) -> EnrollmentResponse:
        """
        Main enrollment function - implements the full enrollment flow
        From SYSTEM_DESIGN.md Section 3.2 (Backend Processing)
        """
        try:
            # 1. Get section and course info
            result = await db.execute(
                select(CourseSection)
                .options(joinedload(CourseSection.course))
                .where(CourseSection.section_id == section_id)
            )
            section = result.scalar_one_or_none()
            
            if not section:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Section not found"
                )
            
            # 2. Check registration period
            is_open = await EnrollmentService.check_registration_period(
                db, section.semester_id
            )
            if not is_open:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Registration period is closed"
                )
            
            # 3. Acquire distributed lock using Redis
            lock_key = CacheKeys.enrollment_lock(section_id)
            lock_acquired = await cache.acquire_lock(lock_key, ttl=10)
            
            if not lock_acquired:
                # Add to queue for retry
                await sqs_client.send_message({
                    "student_id": student_id,
                    "section_id": section_id,
                    "action": "retry_enrollment"
                })
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="System busy, request queued for processing"
                )
            
            try:
                # 4. START TRANSACTION (implicit with async session)
                
                # 5. Check prerequisites
                prereq_met, prereq_error = await EnrollmentService.check_prerequisites(
                    db, student_id, section.course_id
                )
                if not prereq_met:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=prereq_error
                    )
                
                # 6. Check schedule conflicts
                has_conflict, conflict_error = await EnrollmentService.check_schedule_conflict(
                    db, student_id, section_id, section.semester_id
                )
                if has_conflict:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=conflict_error
                    )
                
                # 7. Check credit limit
                exceeds, credit_error = await EnrollmentService.check_credit_limit(
                    db, student_id, section.semester_id, section.course.credits
                )
                if exceeds:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=credit_error
                    )
                
                # 8. Lock section row and check available slots
                available_slots = await EnrollmentService.get_available_slots(
                    db, section_id, use_cache=False
                )
                
                # Get status ID for registered/waitlist
                result = await db.execute(
                    select(EnrollmentStatus.status_id)
                    .where(EnrollmentStatus.status_code == 'registered')
                )
                registered_status_id = result.scalar_one()
                
                result = await db.execute(
                    select(EnrollmentStatus.status_id)
                    .where(EnrollmentStatus.status_code == 'waitlist')
                )
                waitlist_status_id = result.scalar_one()
                
                if available_slots <= 0:
                    # Add to waitlist
                    enrollment = Enrollment(
                        student_id=student_id,
                        section_id=section_id,
                        semester_id=section.semester_id,
                        status_id=waitlist_status_id,
                        enrolled_at=datetime.utcnow()
                    )
                    db.add(enrollment)
                    await db.flush()
                    
                    # Log history
                    history = EnrollmentHistory(
                        enrollment_id=enrollment.enrollment_id,
                        action=EnrollmentAction.WAITLISTED,
                        action_time=datetime.utcnow(),
                        ip_address=ip_address,
                        user_agent=user_agent
                    )
                    db.add(history)
                    
                    # Send waitlist email
                    await sqs_client.send_email_message({
                        "to": student_id,
                        "template": "waitlist",
                        "section_id": section_id
                    })
                    
                    await db.commit()
                    
                    return EnrollmentResponse.from_orm(enrollment)
                
                # 9. Create enrollment (slots available)
                enrollment = Enrollment(
                    student_id=student_id,
                    section_id=section_id,
                    semester_id=section.semester_id,
                    status_id=registered_status_id,
                    enrolled_at=datetime.utcnow()
                )
                db.add(enrollment)
                
                # 10. Update section counts
                section.enrolled_students += 1
                section.available_slots -= 1
                
                if section.available_slots <= 0:
                    section.status = SectionStatus.FULL
                
                await db.flush()
                
                # 11. Log enrollment history
                history = EnrollmentHistory(
                    enrollment_id=enrollment.enrollment_id,
                    action=EnrollmentAction.REGISTERED,
                    action_time=datetime.utcnow(),
                    ip_address=ip_address,
                    user_agent=user_agent
                )
                db.add(history)
                
                # 12. COMMIT transaction
                await db.commit()
                
                # 13. Invalidate cache
                await cache.delete(
                    CacheKeys.section_slots(section_id),
                    CacheKeys.student_enrollments(student_id)
                )
                
                # 14. Send confirmation email (async via SQS)
                await sqs_client.send_email_message({
                    "to": student_id,
                    "template": "enrollment_success",
                    "section_id": section_id
                })
                
                # 15. Log metrics to CloudWatch
                await cloudwatch_client.put_metric("EnrollmentSuccess", 1)
                
                logger.info(f"Student {student_id} enrolled in section {section_id}")
                
                return EnrollmentResponse.from_orm(enrollment)
                
            finally:
                # Release distributed lock
                await cache.release_lock(lock_key)
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Enrollment error: {e}")
            await cloudwatch_client.put_metric("EnrollmentError", 1)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Enrollment failed"
            )
    
    @staticmethod
    async def drop_enrollment(
        db: AsyncSession,
        enrollment_id: int,
        student_id: int
    ) -> bool:
        """Drop an enrollment"""
        result = await db.execute(
            select(Enrollment)
            .where(
                and_(
                    Enrollment.enrollment_id == enrollment_id,
                    Enrollment.student_id == student_id
                )
            )
            .options(joinedload(Enrollment.section))
        )
        enrollment = result.scalar_one_or_none()
        
        if not enrollment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Enrollment not found"
            )
        
        # Update enrollment status
        result = await db.execute(
            select(EnrollmentStatus.status_id)
            .where(EnrollmentStatus.status_code == 'dropped')
        )
        dropped_status_id = result.scalar_one()
        enrollment.status_id = dropped_status_id
        
        # Update section counts
        section = enrollment.section
        section.enrolled_students -= 1
        section.available_slots += 1
        
        if section.status == SectionStatus.FULL:
            section.status = SectionStatus.OPEN
        
        # Log history
        history = EnrollmentHistory(
            enrollment_id=enrollment_id,
            action=EnrollmentAction.DROPPED,
            action_time=datetime.utcnow()
        )
        db.add(history)
        
        await db.commit()
        
        # Clear cache
        await cache.delete(
            CacheKeys.section_slots(section.section_id),
            CacheKeys.student_enrollments(student_id)
        )
        
        return True
