"""
DynamoDB connection and table management
Replaces database.py for NoSQL AWS DynamoDB
"""
import boto3
from boto3.dynamodb.conditions import Key, Attr
from typing import Optional, Dict, Any, List
import logging
from app.config import settings

logger = logging.getLogger(__name__)


class DynamoDBClient:
    """DynamoDB client wrapper for course registration system"""
    
    def __init__(self):
        self.dynamodb = None
        self.resource = None
        self.client = None
        
    def connect(self):
        """Initialize DynamoDB connection"""
        try:
            # Create boto3 session
            session = boto3.Session(
                region_name=settings.DYNAMODB_REGION,
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID if settings.AWS_ACCESS_KEY_ID else None,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY if settings.AWS_SECRET_ACCESS_KEY else None
            )
            
            # DynamoDB resource (high-level)
            if settings.DYNAMODB_ENDPOINT_URL:
                # Local DynamoDB
                self.resource = session.resource(
                    'dynamodb',
                    endpoint_url=settings.DYNAMODB_ENDPOINT_URL
                )
                self.client = session.client(
                    'dynamodb',
                    endpoint_url=settings.DYNAMODB_ENDPOINT_URL
                )
            else:
                # AWS DynamoDB
                self.resource = session.resource('dynamodb')
                self.client = session.client('dynamodb')
            
            logger.info("DynamoDB connected successfully")
            return True
        except Exception as e:
            logger.error(f"DynamoDB connection error: {e}")
            return False
    
    def get_table(self, table_name: str):
        """Get DynamoDB table object"""
        full_name = f"{settings.DYNAMODB_TABLE_PREFIX}_{table_name}"
        return self.resource.Table(full_name)
    
    def disconnect(self):
        """Close DynamoDB connections"""
        self.dynamodb = None
        self.resource = None
        self.client = None
        logger.info("DynamoDB disconnected")


# Table name constants
class Tables:
    """DynamoDB table names"""
    USERS = "Users"
    STUDENTS = "Students"
    TEACHERS = "Teachers"
    ADMINS = "Admins"
    DEPARTMENTS = "Departments"
    MAJORS = "Majors"
    SEMESTERS = "Semesters"
    COURSES = "Courses"
    COURSE_SECTIONS = "CourseSections"
    CLASSROOMS = "Classrooms"
    COURSE_SCHEDULES = "CourseSchedules"
    PREREQUISITES = "Prerequisites"
    ENROLLMENTS = "Enrollments"
    ENROLLMENT_STATUS = "EnrollmentStatus"
    ENROLLMENT_HISTORY = "EnrollmentHistory"


# Global DynamoDB client
db = DynamoDBClient()


def init_tables():
    """
    Initialize DynamoDB tables with schema
    Run this once to create tables
    """
    try:
        client = db.client
        prefix = settings.DYNAMODB_TABLE_PREFIX
        
        # Users table
        client.create_table(
            TableName=f"{prefix}_Users",
            KeySchema=[
                {'AttributeName': 'user_id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'user_id', 'AttributeType': 'S'},
                {'AttributeName': 'username', 'AttributeType': 'S'},
                {'AttributeName': 'email', 'AttributeType': 'S'}
            ],
            GlobalSecondaryIndexes=[
                {
                    'IndexName': 'username-index',
                    'KeySchema': [{'AttributeName': 'username', 'KeyType': 'HASH'}],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
                },
                {
                    'IndexName': 'email-index',
                    'KeySchema': [{'AttributeName': 'email', 'KeyType': 'HASH'}],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
                }
            ],
            ProvisionedThroughput={'ReadCapacityUnits': 10, 'WriteCapacityUnits': 10}
        )
        
        # Courses table
        client.create_table(
            TableName=f"{prefix}_Courses",
            KeySchema=[
                {'AttributeName': 'course_id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'course_id', 'AttributeType': 'S'},
                {'AttributeName': 'semester_id', 'AttributeType': 'S'},
                {'AttributeName': 'department_id', 'AttributeType': 'S'}
            ],
            GlobalSecondaryIndexes=[
                {
                    'IndexName': 'semester-index',
                    'KeySchema': [
                        {'AttributeName': 'semester_id', 'KeyType': 'HASH'},
                        {'AttributeName': 'course_id', 'KeyType': 'RANGE'}
                    ],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 10, 'WriteCapacityUnits': 5}
                },
                {
                    'IndexName': 'department-index',
                    'KeySchema': [{'AttributeName': 'department_id', 'KeyType': 'HASH'}],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
                }
            ],
            ProvisionedThroughput={'ReadCapacityUnits': 10, 'WriteCapacityUnits': 10}
        )
        
        # Enrollments table
        client.create_table(
            TableName=f"{prefix}_Enrollments",
            KeySchema=[
                {'AttributeName': 'enrollment_id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'enrollment_id', 'AttributeType': 'S'},
                {'AttributeName': 'student_id', 'AttributeType': 'S'},
                {'AttributeName': 'section_id', 'AttributeType': 'S'},
                {'AttributeName': 'semester_id', 'AttributeType': 'S'}
            ],
            GlobalSecondaryIndexes=[
                {
                    'IndexName': 'student-semester-index',
                    'KeySchema': [
                        {'AttributeName': 'student_id', 'KeyType': 'HASH'},
                        {'AttributeName': 'semester_id', 'KeyType': 'RANGE'}
                    ],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 10, 'WriteCapacityUnits': 5}
                },
                {
                    'IndexName': 'section-index',
                    'KeySchema': [{'AttributeName': 'section_id', 'KeyType': 'HASH'}],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {'ReadCapacityUnits': 10, 'WriteCapacityUnits': 5}
                }
            ],
            ProvisionedThroughput={'ReadCapacityUnits': 10, 'WriteCapacityUnits': 10}
        )
        
        logger.info("DynamoDB tables created successfully")
        return True
        
    except client.exceptions.ResourceInUseException:
        logger.info("Tables already exist")
        return True
    except Exception as e:
        logger.error(f"Error creating tables: {e}")
        return False


def get_db():
    """
    Dependency for FastAPI routes
    Returns DynamoDB client
    """
    if not db.resource:
        db.connect()
    return db


# Helper functions for DynamoDB operations
async def get_item(table_name: str, key: Dict[str, Any]) -> Optional[Dict]:
    """Get single item from DynamoDB"""
    try:
        table = db.get_table(table_name)
        response = table.get_item(Key=key)
        return response.get('Item')
    except Exception as e:
        logger.error(f"Error getting item from {table_name}: {e}")
        return None


async def put_item(table_name: str, item: Dict[str, Any]) -> bool:
    """Put item into DynamoDB"""
    try:
        table = db.get_table(table_name)
        table.put_item(Item=item)
        return True
    except Exception as e:
        logger.error(f"Error putting item to {table_name}: {e}")
        return False


async def query_items(table_name: str, key_condition, filter_condition=None) -> List[Dict]:
    """Query items from DynamoDB"""
    try:
        table = db.get_table(table_name)
        
        if filter_condition:
            response = table.query(
                KeyConditionExpression=key_condition,
                FilterExpression=filter_condition
            )
        else:
            response = table.query(KeyConditionExpression=key_condition)
        
        return response.get('Items', [])
    except Exception as e:
        logger.error(f"Error querying {table_name}: {e}")
        return []


async def scan_items(table_name: str, filter_condition=None) -> List[Dict]:
    """Scan table (use sparingly, prefer query)"""
    try:
        table = db.get_table(table_name)
        
        if filter_condition:
            response = table.scan(FilterExpression=filter_condition)
        else:
            response = table.scan()
        
        return response.get('Items', [])
    except Exception as e:
        logger.error(f"Error scanning {table_name}: {e}")
        return []


async def update_item(table_name: str, key: Dict[str, Any], updates: Dict[str, Any]) -> bool:
    """Update item in DynamoDB"""
    try:
        table = db.get_table(table_name)
        
        # Build update expression
        update_expr = "SET " + ", ".join([f"#{k} = :{k}" for k in updates.keys()])
        expr_attr_names = {f"#{k}": k for k in updates.keys()}
        expr_attr_values = {f":{k}": v for k, v in updates.items()}
        
        table.update_item(
            Key=key,
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values
        )
        return True
    except Exception as e:
        logger.error(f"Error updating item in {table_name}: {e}")
        return False


async def delete_item(table_name: str, key: Dict[str, Any]) -> bool:
    """Delete item from DynamoDB"""
    try:
        table = db.get_table(table_name)
        table.delete_item(Key=key)
        return True
    except Exception as e:
        logger.error(f"Error deleting item from {table_name}: {e}")
        return False
