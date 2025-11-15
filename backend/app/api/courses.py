"""
API Routes - Courses (DynamoDB version)
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional

from app.dynamodb import get_db, query_items, scan_items, Tables
from app.schemas_dynamodb import CourseResponse
from app.cache import cache, CacheKeys, CacheTTL
from app.auth import get_current_user

router = APIRouter(prefix="/api/courses", tags=["Courses"])


@router.get("", response_model=List[CourseResponse])
async def list_courses(
    semester_id: int,
    department_id: Optional[int] = None,
    search: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """
    List all courses with filters
    Results are cached in Redis for performance
    """
    # Try cache first
    cache_key = CacheKeys.course_list(semester_id)
    cached_courses = await cache.get(cache_key)
    
    if cached_courses:
        # Apply filters on cached data
        courses = cached_courses
    else:
        # Query database
        query = select(Course).where(
            and_(
                Course.semester_id == semester_id,
                Course.is_active == True
            )
        )
        
        if department_id:
            query = query.where(Course.department_id == department_id)
        
        if search:
            search_pattern = f"%{search}%"
            query = query.where(
                or_(
                    Course.course_name.ilike(search_pattern),
                    Course.course_code.ilike(search_pattern)
                )
            )
        
        query = query.offset(skip).limit(limit)
        
        result = await db.execute(query)
        courses = result.scalars().all()
        
        # Cache results
        await cache.set(cache_key, [CourseResponse.from_orm(c).dict() for c in courses], CacheTTL.COURSE_LIST)
    
    return courses


@router.get("/{course_id}", response_model=CourseResponse)
async def get_course_detail(
    course_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get course details"""
    # Try cache
    cache_key = CacheKeys.course_detail(course_id)
    cached = await cache.get(cache_key)
    
    if cached:
        return cached
    
    result = await db.execute(
        select(Course).where(Course.course_id == course_id)
    )
    course = result.scalar_one_or_none()
    
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found"
        )
    
    response = CourseResponse.from_orm(course)
    
    # Cache result
    await cache.set(cache_key, response.dict(), CacheTTL.COURSE_DETAIL)
    
    return response


@router.get("/{course_id}/sections", response_model=List[CourseSectionResponse])
async def get_course_sections(
    course_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get all sections for a course"""
    result = await db.execute(
        select(CourseSection)
        .where(CourseSection.course_id == course_id)
        .options(joinedload(CourseSection.teacher))
    )
    sections = result.scalars().all()
    
    return [CourseSectionResponse.from_orm(s) for s in sections]


# Fix import
from sqlalchemy import or_
