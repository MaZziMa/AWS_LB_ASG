"""
Main FastAPI Application
Course Registration System with Auto Scaling & Load Balancing
"""
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from contextlib import asynccontextmanager
import logging
import time
# from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
# from fastapi.responses import Response

from app.config import settings
from app.dynamodb import db, init_tables
from app.cache import cache
from app.api import auth
from app.api import courses_simple as courses
from app.api import enrollments_simple as enrollments

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics (disabled to avoid duplication)
# REQUEST_COUNT = Counter(
#     'http_requests_total',
#     'Total HTTP requests',
#     ['method', 'endpoint', 'status']
# )
# REQUEST_DURATION = Histogram(
#     'http_request_duration_seconds',
#     'HTTP request duration',
#     ['method', 'endpoint']
# )
# ENROLLMENT_SUCCESS = Counter('enrollment_success_total', 'Successful enrollments')
# ENROLLMENT_ERROR = Counter('enrollment_error_total', 'Failed enrollments')


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - startup and shutdown events"""
    # Startup
    logger.info("Starting Course Registration System...")
    logger.info(f"Environment: {settings.ENVIRONMENT}")
    logger.info(f"Version: {settings.APP_VERSION}")
    
    try:
        # Connect to DynamoDB
        db.connect()
        logger.info("DynamoDB connected")
        
        # Connect to Redis
        await cache.connect()
        logger.info("Redis connected")
        
        logger.info("Application started successfully")
        
        yield
        
    finally:
        # Shutdown
        logger.info("Shutting down...")
        await cache.disconnect()
        db.disconnect()
        logger.info("Application shutdown complete")


# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Course Registration System with AWS Auto Scaling & Load Balancing",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests and track metrics"""
    start_time = time.time()
    
    # Process request
    response = await call_next(request)
    
    # Calculate duration
    duration = time.time() - start_time
    
    # Log request
    logger.info(
        f"{request.method} {request.url.path} - "
        f"Status: {response.status_code} - "
        f"Duration: {duration:.3f}s"
    )
    
    # Track metrics (disabled)
    # REQUEST_COUNT.labels(
    #     method=request.method,
    #     endpoint=request.url.path,
    #     status=response.status_code
    # ).inc()
    # 
    # REQUEST_DURATION.labels(
    #     method=request.method,
    #     endpoint=request.url.path
    # ).observe(duration)
    
    return response


# Exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle validation errors"""
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": "Validation error",
            "errors": exc.errors()
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error"
        }
    )


# Include routers
app.include_router(auth.router)
app.include_router(courses.router)
app.include_router(enrollments.router)


# Health check endpoint (for ALB)
@app.get("/health", tags=["Health"])
async def health_check():
    """
    Health check endpoint for AWS Application Load Balancer
    Returns 200 if application is healthy
    """
    return {
        "status": "healthy",
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT
    }


# Metrics endpoint (for Prometheus) - Disabled
@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """Prometheus metrics endpoint"""
    return {"message": "Metrics disabled - use CloudWatch instead"}


# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """API root endpoint"""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "docs": "/api/docs",
        "health": "/health",
        "metrics": "/metrics"
    }


# Additional endpoints for admin
@app.get("/api/admin/statistics", tags=["Admin"])
async def get_statistics():
    """Get system statistics (admin only)"""
    # TODO: Implement statistics endpoint
    return {"message": "Statistics endpoint"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=False,
        workers=1  # Single worker to avoid Prometheus metric duplication
    )
