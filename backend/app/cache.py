"""
Redis cache management
Handles caching strategy for high-traffic operations
"""
import redis.asyncio as redis
from typing import Optional, Any, Callable
import json
import logging
import hashlib
from functools import wraps
from app.config import settings

logger = logging.getLogger(__name__)


class CacheTTL:
    """Cache TTL constants (seconds)"""
    COURSE_LIST = 300       # 5 minutes - courses change rarely
    COURSE_DETAIL = 600     # 10 minutes
    USER_PROFILE = 180      # 3 minutes
    ENROLLMENT_LIST = 60    # 1 minute - enrollments change frequently
    POPULAR_COURSES = 900   # 15 minutes


class CacheKeys:
    """Cache key patterns"""
    
    @staticmethod
    def course_list(semester_id: int, department_id: int = None) -> str:
        base = f"courses:semester:{semester_id}"
        return f"{base}:dept:{department_id}" if department_id else base
    
    @staticmethod
    def course_detail(course_id: str) -> str:
        return f"course:{course_id}"
    
    @staticmethod
    def user_enrollments(user_id: str) -> str:
        return f"enrollments:user:{user_id}"
    
    @staticmethod
    def enrollment_count(course_id: str) -> str:
        return f"enrollment_count:{course_id}"


class RedisCache:
    """Redis cache manager with connection pooling"""
    
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.pool: Optional[redis.ConnectionPool] = None
    
    async def connect(self):
        """Connect to Redis with connection pool"""
        try:
            self.pool = redis.ConnectionPool.from_url(
                settings.REDIS_URL,
                password=settings.REDIS_PASSWORD if settings.REDIS_PASSWORD else None,
                max_connections=settings.REDIS_MAX_CONNECTIONS,
                decode_responses=True,
                socket_keepalive=True,
                socket_connect_timeout=5,
            )
            self.redis_client = redis.Redis(connection_pool=self.pool)
            
            # Test connection
            await self.redis_client.ping()
            logger.info("Redis connected successfully")
        except Exception as e:
            # Do not block app startup in development if Redis is unavailable
            logger.warning(f"Redis connection unavailable, continuing without cache: {e}")
            self.redis_client = None
            self.pool = None
    
    async def disconnect(self):
        """Close Redis connections"""
        if self.redis_client:
            await self.redis_client.close()
        if self.pool:
            await self.pool.disconnect()
        logger.info("Redis disconnected")
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache with JSON deserialization"""
        if not self.redis_client:
            return None
        
        try:
            value = await self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
        except Exception as e:
            logger.warning(f"Cache GET error for {key}: {e}")
            return None
    
    async def set(self, key: str, value: Any, ttl: int = 300) -> bool:
        """Set value in cache with JSON serialization and TTL"""
        if not self.redis_client:
            return False
        
        try:
            serialized = json.dumps(value)
            await self.redis_client.setex(key, ttl, serialized)
            return True
        except Exception as e:
            logger.warning(f"Cache SET error for {key}: {e}")
            return False
    
    async def delete(self, *keys: str) -> int:
        """Delete keys from cache"""
        if not self.redis_client or not keys:
            return 0
        
        try:
            return await self.redis_client.delete(*keys)
        except Exception as e:
            logger.warning(f"Cache DELETE error: {e}")
            return 0
    
    async def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching pattern (e.g., 'courses:*')"""
        if not self.redis_client:
            return 0
        
        try:
            keys = await self.redis_client.keys(pattern)
            if keys:
                return await self.redis_client.delete(*keys)
            return 0
        except Exception as e:
            logger.warning(f"Cache DELETE_PATTERN error for {pattern}: {e}")
            return 0
    
    async def increment(self, key: str, amount: int = 1, ttl: int = None) -> int:
        """Increment counter (useful for rate limiting)"""
        if not self.redis_client:
            return 0
        
        try:
            new_value = await self.redis_client.incr(key, amount)
            if ttl and new_value == amount:  # First increment
                await self.redis_client.expire(key, ttl)
            return new_value
        except Exception as e:
            logger.warning(f"Cache INCREMENT error for {key}: {e}")
            return 0
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        try:
            value = await self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
        except Exception as e:
            logger.error(f"Redis GET error for key {key}: {e}")
            return None
    
    async def set(self, key: str, value: Any, ttl: int = 300) -> bool:
        """Set value in cache with TTL (seconds)"""
        try:
            serialized = json.dumps(value)
            await self.redis_client.setex(key, ttl, serialized)
            return True
        except Exception as e:
            logger.error(f"Redis SET error for key {key}: {e}")
            return False
    
    async def delete(self, *keys: str) -> bool:
        """Delete one or more keys"""
        try:
            await self.redis_client.delete(*keys)
            return True
        except Exception as e:
            logger.error(f"Redis DELETE error: {e}")
            return False
    
    async def increment(self, key: str) -> int:
        """Increment counter"""
        try:
            return await self.redis_client.incr(key)
        except Exception as e:
            logger.error(f"Redis INCR error for key {key}: {e}")
            return 0
    
    async def decrement(self, key: str) -> int:
        """Decrement counter"""
        try:
            return await self.redis_client.decr(key)
        except Exception as e:
            logger.error(f"Redis DECR error for key {key}: {e}")
            return 0
    
    async def exists(self, key: str) -> bool:
        """Check if key exists"""
        try:
            return await self.redis_client.exists(key) > 0
        except Exception as e:
            logger.error(f"Redis EXISTS error for key {key}: {e}")
            return False
    
    async def acquire_lock(self, lock_key: str, ttl: int = 5) -> bool:
        """
        Acquire distributed lock using Redis
        Returns True if lock acquired, False otherwise
        """
        try:
            # SET NX EX - Set if Not eXists with EXpiration
            return await self.redis_client.set(lock_key, "1", nx=True, ex=ttl)
        except Exception as e:
            logger.error(f"Redis LOCK error for key {lock_key}: {e}")
            return False
    
    async def release_lock(self, lock_key: str) -> bool:
        """Release distributed lock"""
        return await self.delete(lock_key)


# Cache key patterns (from SYSTEM_DESIGN.md)
class CacheKeys:
    """Cache key patterns for different entities"""
    
    @staticmethod
    def course_list(semester_id: int) -> str:
        return f"courses:semester:{semester_id}"
    
    @staticmethod
    def course_detail(course_id: int) -> str:
        return f"course:{course_id}"
    
    @staticmethod
    def section_slots(section_id: int) -> str:
        return f"section:slots:{section_id}"
    
    @staticmethod
    def student_enrollments(student_id: int) -> str:
        return f"student:enrollments:{student_id}"
    
    @staticmethod
    def session_data(session_id: str) -> str:
        return f"session:{session_id}"
    
    @staticmethod
    def enrollment_lock(section_id: int) -> str:
        return f"lock:section:{section_id}"


# TTL Strategy (from SYSTEM_DESIGN.md)
class CacheTTL:
    """Cache TTL in seconds for different data types"""
    COURSE_LIST = 300           # 5 minutes - moderate changes
    COURSE_DETAIL = 3600        # 1 hour - rarely changes
    SECTION_SLOTS = 30          # 30 seconds - frequently changes
    STUDENT_ENROLLMENTS = 60    # 1 minute - moderate changes
    SESSION_DATA = 1800         # 30 minutes - session timeout


def cached(key_func: Callable, ttl: int = 300):
    """
    Decorator for automatic caching
    
    Usage:
        @cached(lambda course_id: CacheKeys.course_detail(course_id), ttl=600)
        async def get_course(course_id: str):
            # expensive operation
            return result
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = key_func(*args, **kwargs)
            
            # Try cache first
            cached_value = await cache.get(cache_key)
            if cached_value is not None:
                logger.debug(f"Cache HIT: {cache_key}")
                return cached_value
            
            # Cache miss - execute function
            logger.debug(f"Cache MISS: {cache_key}")
            result = await func(*args, **kwargs)
            
            # Store in cache
            if result is not None:
                await cache.set(cache_key, result, ttl)
            
            return result
        return wrapper
    return decorator


# Global cache instance
cache = RedisCache()
