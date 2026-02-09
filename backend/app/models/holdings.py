"""Holdings-related database models."""
import uuid
from datetime import datetime, date
from decimal import Decimal
from sqlalchemy import Column, String, Text, Boolean, DateTime, Date, ForeignKey, Enum as SQLEnum, Integer, Numeric, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import enum

from app.database import Base


class SnapshotSource(enum.Enum):
    """Source of holdings snapshot."""
    ARK_DAILY = "ark_daily"
    SEC_13F = "sec_13f"


class ChangeType(enum.Enum):
    """Type of holdings change."""
    NEW = "new"  # New position
    ADDED = "added"  # Increased existing position
    REDUCED = "reduced"  # Decreased existing position
    SOLD_OUT = "sold_out"  # Completely exited position


class ActionType(enum.Enum):
    """Type of investor action (for trades)."""
    BUY = "buy"
    SELL = "sell"


class HoldingsSnapshot(Base):
    """Point-in-time snapshot of an investor's holdings."""
    __tablename__ = "holdings_snapshots"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    snapshot_date = Column(Date, nullable=False)
    source = Column(SQLEnum(SnapshotSource), nullable=False)
    
    # For 13F filings
    filing_date = Column(Date, nullable=True)
    period_end_date = Column(Date, nullable=True)
    
    # Metadata
    total_positions = Column(Integer, default=0)
    total_value = Column(Numeric(20, 2), nullable=True)
    raw_data_url = Column(String(500), nullable=True)
    
    is_processed = Column(Boolean, default=False)
    processed_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    investor = relationship("Investor", back_populates="holdings_snapshots")
    records = relationship("HoldingRecord", back_populates="snapshot", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index('idx_snapshot_investor_date', 'investor_id', 'snapshot_date'),
    )


class HoldingRecord(Base):
    """Individual holding within a snapshot."""
    __tablename__ = "holding_records"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    snapshot_id = Column(UUID(as_uuid=True), ForeignKey("holdings_snapshots.id", ondelete="CASCADE"), nullable=False)
    
    ticker = Column(String(20), nullable=False, index=True)
    company_name = Column(String(255), nullable=True)
    cusip = Column(String(20), nullable=True)
    sector = Column(String(100), nullable=True)  # Sector classification
    
    shares = Column(Numeric(20, 4), nullable=True)
    market_value = Column(Numeric(20, 2), nullable=True)
    weight_percent = Column(Numeric(10, 4), nullable=True)  # Portfolio weight %
    
    # Additional fields
    share_price = Column(Numeric(20, 4), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    snapshot = relationship("HoldingsSnapshot", back_populates="records")
    
    __table_args__ = (
        Index('idx_holding_snapshot_ticker', 'snapshot_id', 'ticker'),
    )


class HoldingsChange(Base):
    """Computed change between two snapshots."""
    __tablename__ = "holdings_changes"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    ticker = Column(String(20), nullable=False, index=True)
    company_name = Column(String(255), nullable=True)
    
    change_type = Column(SQLEnum(ChangeType), nullable=False)
    
    # Date context
    from_date = Column(Date, nullable=False)
    to_date = Column(Date, nullable=False)
    
    # Change details
    shares_before = Column(Numeric(20, 4), nullable=True)
    shares_after = Column(Numeric(20, 4), nullable=True)
    shares_delta = Column(Numeric(20, 4), nullable=True)
    shares_delta_percent = Column(Numeric(10, 4), nullable=True)
    
    weight_before = Column(Numeric(10, 4), nullable=True)
    weight_after = Column(Numeric(10, 4), nullable=True)
    weight_delta = Column(Numeric(10, 4), nullable=True)
    
    value_before = Column(Numeric(20, 2), nullable=True)
    value_after = Column(Numeric(20, 2), nullable=True)
    value_delta = Column(Numeric(20, 2), nullable=True)
    
    # Market price range during period
    price_range_low = Column(Numeric(20, 4), nullable=True)
    price_range_high = Column(Numeric(20, 4), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_change_investor_date', 'investor_id', 'to_date'),
    )


class InvestorAction(Base):
    """Explicit investor action/trade (primarily for ARK daily trades)."""
    __tablename__ = "investor_actions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    action_type = Column(SQLEnum(ActionType), nullable=False)
    ticker = Column(String(20), nullable=False, index=True)
    company_name = Column(String(255), nullable=True)
    
    # Trade details
    trade_date = Column(Date, nullable=False)
    shares = Column(Numeric(20, 4), nullable=True)
    estimated_value = Column(Numeric(20, 2), nullable=True)
    weight_percent = Column(Numeric(10, 4), nullable=True)
    
    # Market price range for the trade date
    price_range_low = Column(Numeric(20, 4), nullable=True)
    price_range_high = Column(Numeric(20, 4), nullable=True)
    
    # Fund/ETF info (for ARK)
    fund_name = Column(String(100), nullable=True)
    
    # Source reference
    source_record_id = Column(UUID(as_uuid=True), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    investor = relationship("Investor", back_populates="actions")
    
    __table_args__ = (
        Index('idx_action_investor_date', 'investor_id', 'trade_date'),
        Index('idx_action_ticker_date', 'ticker', 'trade_date'),
    )
