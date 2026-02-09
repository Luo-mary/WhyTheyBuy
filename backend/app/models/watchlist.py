"""Watchlist models."""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from app.database import Base


class NotificationFrequency(enum.Enum):
    """Notification frequency preferences."""
    INSTANT = "instant"  # Immediate notification on change
    DAILY = "daily"  # Daily digest
    WEEKLY = "weekly"  # Weekly digest


class Watchlist(Base):
    """User's watchlist for monitoring investors."""
    __tablename__ = "watchlists"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), default="My Watchlist")
    is_default = Column(Boolean, default=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="watchlists")
    items = relationship("WatchlistItem", back_populates="watchlist", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index('idx_watchlist_user', 'user_id'),
    )


class WatchlistItem(Base):
    """Individual investor in a watchlist."""
    __tablename__ = "watchlist_items"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    watchlist_id = Column(UUID(as_uuid=True), ForeignKey("watchlists.id", ondelete="CASCADE"), nullable=False)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    # Notification preferences
    notification_frequency = Column(
        SQLEnum(NotificationFrequency), 
        default=NotificationFrequency.DAILY
    )
    email_enabled = Column(Boolean, default=True)
    
    # Notes
    user_notes = Column(String(500), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    watchlist = relationship("Watchlist", back_populates="items")
    
    __table_args__ = (
        Index('idx_watchlist_item_investor', 'watchlist_id', 'investor_id', unique=True),
    )
