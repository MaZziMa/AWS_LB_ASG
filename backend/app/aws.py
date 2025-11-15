"""
AWS Services Integration
SQS, CloudWatch, S3, SES
"""
import boto3
from botocore.exceptions import ClientError
import logging
import json
from typing import Dict, Any
from app.config import settings

logger = logging.getLogger(__name__)


class SQSClient:
    """Amazon SQS client for async message queue"""
    
    def __init__(self):
        self.client = boto3.client(
            'sqs',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )
        self.queue_url = settings.SQS_QUEUE_URL
        self.email_queue_url = settings.SQS_EMAIL_QUEUE_URL
    
    async def send_message(self, message_body: Dict[str, Any]) -> bool:
        """Send message to SQS queue"""
        try:
            response = self.client.send_message(
                QueueUrl=self.queue_url,
                MessageBody=json.dumps(message_body)
            )
            logger.info(f"Message sent to SQS: {response['MessageId']}")
            return True
        except ClientError as e:
            logger.error(f"SQS send error: {e}")
            return False
    
    async def send_email_message(self, message_body: Dict[str, Any]) -> bool:
        """Send email message to email queue"""
        try:
            response = self.client.send_message(
                QueueUrl=self.email_queue_url,
                MessageBody=json.dumps(message_body)
            )
            logger.info(f"Email message queued: {response['MessageId']}")
            return True
        except ClientError as e:
            logger.error(f"Email queue error: {e}")
            return False


class CloudWatchClient:
    """Amazon CloudWatch client for metrics and logging"""
    
    def __init__(self):
        self.client = boto3.client(
            'cloudwatch',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )
        self.namespace = settings.CLOUDWATCH_NAMESPACE
    
    async def put_metric(
        self,
        metric_name: str,
        value: float,
        unit: str = "Count",
        dimensions: Dict[str, str] = None
    ) -> bool:
        """Push custom metric to CloudWatch"""
        try:
            metric_data = {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow()
            }
            
            if dimensions:
                metric_data['Dimensions'] = [
                    {'Name': k, 'Value': v} for k, v in dimensions.items()
                ]
            
            self.client.put_metric_data(
                Namespace=self.namespace,
                MetricData=[metric_data]
            )
            return True
        except ClientError as e:
            logger.error(f"CloudWatch metric error: {e}")
            return False


class S3Client:
    """Amazon S3 client for file storage"""
    
    def __init__(self):
        self.client = boto3.client(
            's3',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )
        self.bucket_name = settings.S3_BUCKET_NAME
    
    async def upload_file(self, file_path: str, object_name: str) -> str:
        """Upload file to S3"""
        try:
            self.client.upload_file(file_path, self.bucket_name, object_name)
            url = f"https://{self.bucket_name}.s3.{settings.AWS_REGION}.amazonaws.com/{object_name}"
            logger.info(f"File uploaded to S3: {url}")
            return url
        except ClientError as e:
            logger.error(f"S3 upload error: {e}")
            return None
    
    async def get_presigned_url(self, object_name: str, expiration: int = 3600) -> str:
        """Generate presigned URL for temporary access"""
        try:
            url = self.client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': object_name},
                ExpiresIn=expiration
            )
            return url
        except ClientError as e:
            logger.error(f"S3 presigned URL error: {e}")
            return None


class SESClient:
    """Amazon SES client for email sending"""
    
    def __init__(self):
        self.client = boto3.client(
            'ses',
            region_name=settings.SES_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )
        self.sender_email = settings.SES_SENDER_EMAIL
    
    async def send_email(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: str = None
    ) -> bool:
        """Send email via SES"""
        try:
            message = {
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': body_text}}
            }
            
            if body_html:
                message['Body']['Html'] = {'Data': body_html}
            
            response = self.client.send_email(
                Source=self.sender_email,
                Destination={'ToAddresses': [to_email]},
                Message=message
            )
            logger.info(f"Email sent: {response['MessageId']}")
            return True
        except ClientError as e:
            logger.error(f"SES send error: {e}")
            return False


# Global instances
sqs_client = SQSClient()
cloudwatch_client = CloudWatchClient()
s3_client = S3Client()
ses_client = SESClient()


# Fix import for datetime
from datetime import datetime
