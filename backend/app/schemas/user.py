"""User schemas."""
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field


class UserResponse(BaseModel):
    """User response schema."""
    id: UUID
    email: EmailStr
    name: str | None
    avatar_url: str | None
    country: str | None
    timezone: str
    preferred_language: str
    is_email_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """User update schema."""
    name: str | None = Field(None, max_length=255)
    avatar_url: str | None = Field(None, max_length=500)
    country: str | None = Field(None, max_length=100)
    timezone: str | None = Field(None, max_length=100)
    preferred_language: str | None = Field(None, max_length=10)


class UserEmailCreate(BaseModel):
    """Create additional email schema."""
    email: EmailStr
    receive_notifications: bool = True


class UserEmailResponse(BaseModel):
    """User email response schema."""
    id: UUID
    email: EmailStr
    is_verified: bool
    is_primary: bool
    receive_notifications: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class ChangePasswordRequest(BaseModel):
    """Change password request schema."""
    current_password: str
    new_password: str = Field(..., min_length=8)
