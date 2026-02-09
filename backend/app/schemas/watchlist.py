"""Watchlist schemas."""
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, field_validator

from app.models.watchlist import NotificationFrequency
from app.schemas.investor import InvestorResponse


class WatchlistItemCreate(BaseModel):
    """Create watchlist item schema."""
    # Can be either UUID or investor slug
    investor_id: str
    notification_frequency: NotificationFrequency = NotificationFrequency.DAILY
    email_enabled: bool = True
    user_notes: str | None = None

    @field_validator('investor_id')
    @classmethod
    def validate_investor_id(cls, v):
        """Accept either UUID string or slug."""
        return str(v)


class WatchlistItemUpdate(BaseModel):
    """Update watchlist item schema."""
    notification_frequency: NotificationFrequency | None = None
    email_enabled: bool | None = None
    user_notes: str | None = None


class WatchlistItemResponse(BaseModel):
    """Watchlist item response schema."""
    id: UUID
    watchlist_id: UUID
    investor_id: UUID
    notification_frequency: NotificationFrequency
    email_enabled: bool
    user_notes: str | None
    created_at: datetime
    investor: InvestorResponse | None = None
    
    class Config:
        from_attributes = True


class WatchlistResponse(BaseModel):
    """Watchlist response schema."""
    id: UUID
    user_id: UUID
    name: str
    is_default: bool
    created_at: datetime
    items: list[WatchlistItemResponse] | None = None
    items_count: int = 0
    
    class Config:
        from_attributes = True
