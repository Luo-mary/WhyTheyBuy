"""Report models."""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, Date, ForeignKey, Enum as SQLEnum, Boolean, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import enum

from app.database import Base


class ReportType(enum.Enum):
    """Type of report."""
    INVESTOR_CHANGE = "investor_change"
    WEEKLY_DIGEST = "weekly_digest"
    DAILY_DIGEST = "daily_digest"


class Report(Base):
    """Generated report for user."""
    __tablename__ = "reports"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="SET NULL"), nullable=True)
    
    report_type = Column(SQLEnum(ReportType), nullable=False)
    report_date = Column(Date, nullable=False)
    
    # Content
    title = Column(String(500), nullable=False)
    summary_json = Column(JSONB, nullable=True)  # AI-generated summary
    
    # Email delivery
    email_sent = Column(Boolean, default=False)
    email_sent_at = Column(DateTime, nullable=True)
    email_recipient = Column(String(255), nullable=True)
    
    # Viewing
    is_read = Column(Boolean, default=False)
    read_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="reports")
    
    __table_args__ = (
        Index('idx_report_user_date', 'user_id', 'report_date'),
    )


class AICompanyReport(Base):
    """AI-generated company rationale report."""
    __tablename__ = "ai_company_reports"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="SET NULL"), nullable=True)
    ticker = Column(String(20), nullable=False, index=True)
    
    # Generated content
    json_payload = Column(JSONB, nullable=False)
    
    # Inputs used (for traceability)
    input_data = Column(JSONB, nullable=True)
    
    generated_at = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_ai_report_user_ticker', 'user_id', 'ticker'),
    )
