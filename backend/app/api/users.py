"""User management API routes."""
import base64
from datetime import datetime
import secrets
from fastapi import APIRouter, HTTPException, status, BackgroundTasks, UploadFile, File
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.models.user import User, UserEmail
from app.schemas.user import (
    UserResponse,
    UserUpdate,
    UserEmailCreate,
    UserEmailResponse,
    ChangePasswordRequest,
)
from app.services.auth import hash_password, verify_password
from app.services.email import send_verification_email

router = APIRouter()

# Max avatar size: 2MB
MAX_AVATAR_SIZE = 2 * 1024 * 1024
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}


@router.get("/profile", response_model=UserResponse)
async def get_profile(user: CurrentUser):
    """Get current user profile."""
    return user


@router.patch("/profile", response_model=UserResponse)
async def update_profile(request: UserUpdate, user: CurrentUser, db: DB):
    """Update user profile."""
    update_data = request.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(user, field, value)

    user.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)

    return user


@router.post("/avatar", response_model=UserResponse)
async def upload_avatar(user: CurrentUser, db: DB, file: UploadFile = File(...)):
    """Upload user avatar image."""
    # Validate file type
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_MIME_TYPES)}",
        )

    # Read file content
    content = await file.read()

    # Validate file size
    if len(content) > MAX_AVATAR_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {MAX_AVATAR_SIZE // (1024 * 1024)}MB",
        )

    # Convert to base64 data URL
    base64_data = base64.b64encode(content).decode("utf-8")
    data_url = f"data:{file.content_type};base64,{base64_data}"

    # Update user
    user.avatar_url = data_url
    user.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)

    return user


@router.delete("/avatar", response_model=UserResponse)
async def remove_avatar(user: CurrentUser, db: DB):
    """Remove user avatar."""
    user.avatar_url = None
    user.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)

    return user


@router.post("/change-password")
async def change_password(request: ChangePasswordRequest, user: CurrentUser, db: DB):
    """Change user password."""
    if not verify_password(request.current_password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )
    
    user.hashed_password = hash_password(request.new_password)
    user.updated_at = datetime.utcnow()
    await db.commit()
    
    return {"message": "Password changed successfully"}


@router.get("/emails", response_model=list[UserEmailResponse])
async def get_emails(user: CurrentUser, db: DB):
    """Get user's notification emails."""
    result = await db.execute(
        select(UserEmail).where(UserEmail.user_id == user.id)
    )
    return result.scalars().all()


@router.post("/emails", response_model=UserEmailResponse, status_code=status.HTTP_201_CREATED)
async def add_email(
    request: UserEmailCreate, 
    user: CurrentUser, 
    db: DB,
    background_tasks: BackgroundTasks
):
    """Add a notification email."""
    # Check if email already exists for user
    result = await db.execute(
        select(UserEmail).where(
            UserEmail.user_id == user.id,
            UserEmail.email == request.email.lower()
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already added",
        )
    
    # Create email record
    verification_token = secrets.token_urlsafe(32)
    user_email = UserEmail(
        user_id=user.id,
        email=request.email.lower(),
        receive_notifications=request.receive_notifications,
        verification_token=verification_token,
    )
    db.add(user_email)
    await db.commit()
    await db.refresh(user_email)
    
    # Send verification email
    background_tasks.add_task(send_verification_email, request.email, verification_token)
    
    return user_email


@router.delete("/emails/{email_id}")
async def remove_email(email_id: str, user: CurrentUser, db: DB):
    """Remove a notification email."""
    result = await db.execute(
        select(UserEmail).where(
            UserEmail.id == email_id,
            UserEmail.user_id == user.id
        )
    )
    user_email = result.scalar_one_or_none()
    
    if not user_email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email not found",
        )
    
    if user_email.is_primary:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove primary email",
        )
    
    await db.delete(user_email)
    await db.commit()
    
    return {"message": "Email removed successfully"}


@router.patch("/emails/{email_id}", response_model=UserEmailResponse)
async def update_email_settings(
    email_id: str,
    receive_notifications: bool,
    user: CurrentUser,
    db: DB
):
    """Update email notification settings."""
    result = await db.execute(
        select(UserEmail).where(
            UserEmail.id == email_id,
            UserEmail.user_id == user.id
        )
    )
    user_email = result.scalar_one_or_none()
    
    if not user_email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email not found",
        )
    
    user_email.receive_notifications = receive_notifications
    await db.commit()
    await db.refresh(user_email)
    
    return user_email


@router.post("/emails/{email_id}/verify")
async def verify_additional_email(email_id: str, token: str, db: DB):
    """Verify an additional email address."""
    result = await db.execute(
        select(UserEmail).where(
            UserEmail.id == email_id,
            UserEmail.verification_token == token
        )
    )
    user_email = result.scalar_one_or_none()
    
    if not user_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification token",
        )
    
    user_email.is_verified = True
    user_email.verified_at = datetime.utcnow()
    user_email.verification_token = None
    await db.commit()
    
    return {"message": "Email verified successfully"}


@router.delete("/account")
async def delete_account(user: CurrentUser, db: DB):
    """Delete user account."""
    # Soft delete - deactivate account
    user.is_active = False
    user.updated_at = datetime.utcnow()
    await db.commit()
    
    return {"message": "Account deleted successfully"}
