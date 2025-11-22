"""
Database Optimization Layer
Handles indexing, query optimization, and connection pooling for DynamoDB
"""
import boto3
from botocore.config import Config
from typing import List, Dict, Any, Optional
import logging
from functools import lru_cache

logger = logging.getLogger(__name__)


class DynamoDBOptimizer:
    """
    DynamoDB optimization utilities
    Implements best practices: GSI usage, batch operations, connection pooling
    """
    
    def __init__(self):
        # Configure boto3 with optimized settings
        self.config = Config(
            retries={'max_attempts': 3, 'mode': 'adaptive'},
            max_pool_connections=50,  # Increase connection pool
            connect_timeout=5,
            read_timeout=10,
        )
        
        self.dynamodb = boto3.resource('dynamodb', config=self.config)
        self.client = boto3.client('dynamodb', config=self.config)
    
    @staticmethod
    def create_gsi_definitions() -> List[Dict]:
        """
        Global Secondary Index definitions for optimal query patterns
        
        Query Patterns Optimized:
        1. Get courses by semester + department (CoursesBySemester)
        2. Get enrollments by user (EnrollmentsByUser)
        3. Get enrollments by course (EnrollmentsByCourse)
        4. Get courses by instructor (CoursesByInstructor)
        """
        return [
            {
                'IndexName': 'CoursesBySemester',
                'KeySchema': [
                    {'AttributeName': 'semester_id', 'KeyType': 'HASH'},
                    {'AttributeName': 'department_id', 'KeyType': 'RANGE'}
                ],
                'Projection': {'ProjectionType': 'ALL'},
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 10,
                    'WriteCapacityUnits': 5
                }
            },
            {
                'IndexName': 'EnrollmentsByUser',
                'KeySchema': [
                    {'AttributeName': 'user_id', 'KeyType': 'HASH'},
                    {'AttributeName': 'enrolled_at', 'KeyType': 'RANGE'}
                ],
                'Projection': {'ProjectionType': 'ALL'},
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 15,
                    'WriteCapacityUnits': 5
                }
            },
            {
                'IndexName': 'EnrollmentsByCourse',
                'KeySchema': [
                    {'AttributeName': 'course_id', 'KeyType': 'HASH'},
                    {'AttributeName': 'enrolled_at', 'KeyType': 'RANGE'}
                ],
                'Projection': {'ProjectionType': 'ALL'},
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 10,
                    'WriteCapacityUnits': 5
                }
            },
            {
                'IndexName': 'CoursesByInstructor',
                'KeySchema': [
                    {'AttributeName': 'instructor_id', 'KeyType': 'HASH'},
                    {'AttributeName': 'course_code', 'KeyType': 'RANGE'}
                ],
                'Projection': {'ProjectionType': 'KEYS_ONLY'},  # Lighter projection
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 5,
                    'WriteCapacityUnits': 2
                }
            }
        ]
    
    async def batch_get_items(
        self,
        table_name: str,
        keys: List[Dict[str, Any]],
        consistent_read: bool = False
    ) -> List[Dict]:
        """
        Batch get items (up to 100 at a time) with automatic chunking
        Reduces round trips: 100 GetItem → 1 BatchGetItem
        """
        if not keys:
            return []
        
        items = []
        # DynamoDB BatchGetItem limit is 100 keys
        chunk_size = 100
        
        for i in range(0, len(keys), chunk_size):
            chunk = keys[i:i + chunk_size]
            
            try:
                response = self.client.batch_get_item(
                    RequestItems={
                        table_name: {
                            'Keys': chunk,
                            'ConsistentRead': consistent_read
                        }
                    }
                )
                
                items.extend(response.get('Responses', {}).get(table_name, []))
                
                # Handle unprocessed keys (throttling)
                unprocessed = response.get('UnprocessedKeys', {})
                while unprocessed:
                    logger.warning(f"Retrying {len(unprocessed)} unprocessed keys")
                    response = self.client.batch_get_item(RequestItems=unprocessed)
                    items.extend(response.get('Responses', {}).get(table_name, []))
                    unprocessed = response.get('UnprocessedKeys', {})
                    
            except Exception as e:
                logger.error(f"Batch get error for chunk {i}: {e}")
                raise
        
        return items
    
    async def batch_write_items(
        self,
        table_name: str,
        items: List[Dict[str, Any]],
        operation: str = 'put'  # 'put' or 'delete'
    ) -> int:
        """
        Batch write items (up to 25 at a time) with automatic chunking
        Reduces write latency: 25 PutItem → 1 BatchWriteItem
        """
        if not items:
            return 0
        
        written_count = 0
        chunk_size = 25  # DynamoDB BatchWriteItem limit
        
        for i in range(0, len(items), chunk_size):
            chunk = items[i:i + chunk_size]
            
            # Format requests
            requests = []
            for item in chunk:
                if operation == 'put':
                    requests.append({'PutRequest': {'Item': item}})
                elif operation == 'delete':
                    requests.append({'DeleteRequest': {'Key': item}})
            
            try:
                response = self.client.batch_write_item(
                    RequestItems={table_name: requests}
                )
                
                written_count += len(chunk)
                
                # Handle unprocessed items
                unprocessed = response.get('UnprocessedItems', {})
                while unprocessed:
                    logger.warning(f"Retrying {len(unprocessed)} unprocessed items")
                    response = self.client.batch_write_item(RequestItems=unprocessed)
                    unprocessed = response.get('UnprocessedItems', {})
                    
            except Exception as e:
                logger.error(f"Batch write error for chunk {i}: {e}")
                raise
        
        return written_count
    
    def query_with_gsi(
        self,
        table_name: str,
        index_name: str,
        key_condition: str,
        expression_values: Dict,
        limit: Optional[int] = None,
        scan_forward: bool = True
    ) -> List[Dict]:
        """
        Query using Global Secondary Index
        Much faster than Scan for filtered queries
        
        Example:
            optimizer.query_with_gsi(
                'Courses',
                'CoursesBySemester',
                'semester_id = :sid AND department_id = :did',
                {':sid': {'N': '1'}, ':did': {'N': '5'}},
                limit=50
            )
        """
        table = self.dynamodb.Table(table_name)
        
        query_params = {
            'IndexName': index_name,
            'KeyConditionExpression': key_condition,
            'ExpressionAttributeValues': expression_values,
            'ScanIndexForward': scan_forward
        }
        
        if limit:
            query_params['Limit'] = limit
        
        try:
            response = table.query(**query_params)
            items = response.get('Items', [])
            
            # Handle pagination if needed
            while 'LastEvaluatedKey' in response and (not limit or len(items) < limit):
                query_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
                response = table.query(**query_params)
                items.extend(response.get('Items', []))
            
            return items[:limit] if limit else items
            
        except Exception as e:
            logger.error(f"GSI query error on {index_name}: {e}")
            raise
    
    @lru_cache(maxsize=100)
    def get_table_info(self, table_name: str) -> Dict:
        """
        Cached table metadata (indexes, key schema)
        Avoids repeated DescribeTable calls
        """
        try:
            response = self.client.describe_table(TableName=table_name)
            return response['Table']
        except Exception as e:
            logger.error(f"Failed to get table info for {table_name}: {e}")
            return {}


# Singleton instance
db_optimizer = DynamoDBOptimizer()


def get_optimized_db():
    """Dependency injection for optimized DynamoDB client"""
    return db_optimizer
