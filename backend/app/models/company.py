"""Company and market data models."""
import uuid
from datetime import datetime, date
from decimal import Decimal
from sqlalchemy import Column, String, Text, Boolean, DateTime, Date, Numeric, Index
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Company(Base):
    """Company profile information."""
    __tablename__ = "companies"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ticker = Column(String(20), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    
    # Exchange info
    exchange = Column(String(50), nullable=True)
    currency = Column(String(10), default="USD")
    
    # Classification
    sector = Column(String(100), nullable=True)
    industry = Column(String(200), nullable=True)
    
    # Profile
    description = Column(Text, nullable=True)
    website = Column(String(500), nullable=True)
    logo_url = Column(String(500), nullable=True)
    
    # Financial data
    market_cap = Column(Numeric(20, 2), nullable=True)
    shares_outstanding = Column(Numeric(20, 0), nullable=True)
    
    # IPO info
    ipo_date = Column(Date, nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    profile_last_updated = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class MarketPrice(Base):
    """Daily market price data for companies."""
    __tablename__ = "market_prices"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ticker = Column(String(20), nullable=False, index=True)
    price_date = Column(Date, nullable=False)
    
    # OHLCV data
    open_price = Column(Numeric(20, 4), nullable=True)
    high_price = Column(Numeric(20, 4), nullable=True)
    low_price = Column(Numeric(20, 4), nullable=True)
    close_price = Column(Numeric(20, 4), nullable=True)
    volume = Column(Numeric(20, 0), nullable=True)
    
    # Adjusted prices (for splits/dividends)
    adj_close = Column(Numeric(20, 4), nullable=True)
    
    # Source
    source = Column(String(50), default="alpha_vantage")
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_price_ticker_date', 'ticker', 'price_date', unique=True),
    )
