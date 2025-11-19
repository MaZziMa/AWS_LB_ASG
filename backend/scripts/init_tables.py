#!/usr/bin/env python3
"""Initialize DynamoDB tables"""
from app.config import settings
from app.dynamodb import db, init_tables

print("Connecting to DynamoDB...")
db.connect()

print("Creating tables...")
try:
    init_tables()
    print("✓ Tables created successfully!")
except Exception as e:
    print(f"Error: {e}")
    # Tables might already exist
    print("Tables may already exist, continuing...")
