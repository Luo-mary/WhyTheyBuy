"""Authentication API routes."""
from datetime import datetime, timedelta
import secrets
from fastapi import APIRouter, HTTPException, status, BackgroundTasks
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.models.user import User, PasswordResetToken
from app.models.subscription import Subscription, SubscriptionTier, SubscriptionStatus
from app.schemas.auth import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    RefreshTokenRequest,
    PasswordResetRequest,
    PasswordResetConfirm,
    EmailVerifyRequest,
)
from app.schemas.user import UserResponse
from app.services.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_token,
)
from app.services.email import send_password_reset_email, send_verification_email
from app.config import settings

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest, db: DB, background_tasks: BackgroundTasks):
    """Register a new user."""
    # Check if email exists
    result = await db.execute(select(User).where(User.email == request.email.lower()))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    # Create user
    user = User(
        email=request.email.lower(),
        hashed_password=hash_password(request.password),
        name=request.name,
        country=request.country,
        timezone=request.timezone,
    )
    db.add(user)
    await db.flush()
    
    # Create free subscription
    subscription = Subscription(
        user_id=user.id,
        tier=SubscriptionTier.FREE,
        status=SubscriptionStatus.ACTIVE,
    )
    db.add(subscription)
    
    await db.commit()
    await db.refresh(user)
    
    # Send verification email (non-blocking)
    try:
        background_tasks.add_task(send_verification_email, user.email, user.id)
    except Exception as e:
        # Log but don't fail registration if email fails
        import logging
        logging.error(f"Failed to queue verification email: {e}")
    
    return user


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: DB):
    """Login and get access token."""
    result = await db.execute(
        select(User).where(User.email == request.email.lower())
    )
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )
    
    # Update last login
    user.last_login_at = datetime.utcnow()
    await db.commit()
    
    # Generate tokens
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshTokenRequest, db: DB):
    """Refresh access token."""
    payload = verify_token(request.refresh_token, token_type="refresh")
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
    
    user_id = payload.get("sub")
    
    # Verify user exists and is active
    result = await db.execute(
        select(User).where(User.id == user_id, User.is_active == True)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    
    # Generate new tokens
    access_token = create_access_token(str(user.id))
    new_refresh_token = create_refresh_token(str(user.id))
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


@router.post("/password-reset/request")
async def request_password_reset(
    request: PasswordResetRequest, 
    db: DB, 
    background_tasks: BackgroundTasks
):
    """Request password reset email."""
    result = await db.execute(
        select(User).where(User.email == request.email.lower())
    )
    user = result.scalar_one_or_none()
    
    # Always return success to prevent email enumeration
    if user:
        # Generate reset token
        token = secrets.token_urlsafe(32)
        reset_token = PasswordResetToken(
            user_id=user.id,
            token=token,
            expires_at=datetime.utcnow() + timedelta(hours=1),
        )
        db.add(reset_token)
        await db.commit()
        
        # Send email
        background_tasks.add_task(send_password_reset_email, user.email, token)
    
    return {"message": "If the email exists, a reset link has been sent"}


@router.post("/password-reset/confirm")
async def confirm_password_reset(request: PasswordResetConfirm, db: DB):
    """Confirm password reset with token."""
    result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.token == request.token,
            PasswordResetToken.expires_at > datetime.utcnow(),
            PasswordResetToken.used_at == None,
        )
    )
    reset_token = result.scalar_one_or_none()
    
    if not reset_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )
    
    # Update password
    result = await db.execute(select(User).where(User.id == reset_token.user_id))
    user = result.scalar_one()
    user.hashed_password = hash_password(request.new_password)
    
    # Mark token as used
    reset_token.used_at = datetime.utcnow()
    
    await db.commit()
    
    return {"message": "Password reset successfully"}


@router.post("/verify-email")
async def verify_email(request: EmailVerifyRequest, db: DB):
    """Verify email with token."""
    payload = verify_token(request.token, token_type="email_verify")
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification token",
        )
    
    user_id = payload.get("sub")
    
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    
    user.is_email_verified = True
    user.email_verified_at = datetime.utcnow()
    await db.commit()
    
    return {"message": "Email verified successfully"}


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(user: CurrentUser):
    """Get current user information."""
    return user


@router.post("/logout")
async def logout():
    """Logout (client-side token removal)."""
    # JWT is stateless, so logout is handled client-side
    # In production, you might want to blacklist the token in Redis
    return {"message": "Logged out successfully"}
