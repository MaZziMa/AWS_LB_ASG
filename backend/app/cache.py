"""
Redis cache management
Handles caching strategy for high-traffic operations
"""
import redis.asyncio as redis
from typing import Optional, Any
import json
import logging
from app.config import settings

logger = logging.getLogger(__name__)


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


# Global cache instance
cache = RedisCache()
