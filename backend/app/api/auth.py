"""
API Routes - Authentication (DynamoDB version)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
from boto3.dynamodb.conditions import Key

from app.dynamodb import get_db, get_item, put_item, query_items, Tables
from app.schemas_dynamodb import UserLogin, Token, UserResponse, TokenData
from app.auth import verify_password, create_access_token, create_refresh_token, get_current_user

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/login", response_model=Token)
async def login(credentials: UserLogin):
    """User login - returns JWT tokens"""
    # Query DynamoDB by username using GSI
    db_client = get_db()
    table = db_client.get_table(Tables.USERS)
    
    try:
        response = table.query(
            IndexName='username-index',
            KeyConditionExpression=Key('username').eq(credentials.username)
        )
        items = response.get('Items', [])
        
        if not items:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password"
            )
        
        user = items[0]
        
        if not verify_password(credentials.password, user.get('password_hash', '')):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password"
            )
        
        if not user.get('is_active', False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is inactive"
            )
        
        # Update last login
        from app.dynamodb import update_item
        await update_item(Tables.USERS, {'user_id': user['user_id']}, {'last_login': datetime.utcnow().isoformat()})
        
        # Create tokens
        token_data = {
            "user_id": user['user_id'],
            "username": user['username'],
            "user_type": user.get('user_type', 'student')
        }
        
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)
        
        return Token(
            access_token=access_token,
            refresh_token=refresh_token
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Login error: {str(e)}")


@router.post("/logout")
async def logout(current_user: TokenData = Depends(get_current_user)):
    """User logout (client should discard tokens)"""
    return {"message": "Logged out successfully"}


@router.get("/me")
async def get_current_user_info(current_user: TokenData = Depends(get_current_user)):
    """Get current user information"""
    user = await get_item(Tables.USERS, {'user_id': current_user.user_id})
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "user_id": user.get('user_id'),
        "username": user.get('username'),
        "email": user.get('email'),
        "full_name": user.get('full_name'),
        "user_type": user.get('user_type'),
        "is_active": user.get('is_active', True)
    }


@router.post("/refresh", response_model=Token)
async def refresh_access_token(
    current_user: TokenData = Depends(get_current_user)
):
    """Refresh access token using refresh token"""
    token_data = {
        "user_id": current_user.user_id,
        "username": current_user.username,
        "user_type": current_user.user_type.value
    }
    
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token
    )
