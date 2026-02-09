"""
Generic Investor and Disclosure Mechanism models.

This module implements a pluggable framework for monitoring ANY investor or institution
by abstracting over different public disclosure mechanisms.

Core concept: "Investor entities + disclosure sources + update frequency + interpretation rules"
"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey, Enum as SQLEnum, Integer, Float
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
from sqlalchemy.orm import relationship
import enum

from app.database import Base


# =============================================================================
# INVESTOR TYPE ENUMERATION
# =============================================================================

class InvestorType(enum.Enum):
    """
    Generic investor/institution types.
    
    The system is NOT limited to specific types - this enum provides
    categorization for UI and analytics purposes.
    """
    ETF_MANAGER = "etf_manager"              # Manages publicly traded ETFs (ARK, etc.)
    MUTUAL_FUND = "mutual_fund"              # Traditional mutual funds
    HEDGE_FUND = "hedge_fund"                # Hedge funds with 13F/letter disclosures
    PUBLIC_INSTITUTION = "public_institution" # Large institutions (pension funds, etc.)
    INDIVIDUAL_INVESTOR = "individual"        # Notable individual investors (Buffett, etc.)
    VENTURE_PE = "venture_pe"                # VC/PE with occasional public disclosures
    SOVEREIGN_WEALTH = "sovereign_wealth"    # Sovereign wealth funds
    FAMILY_OFFICE = "family_office"          # Family offices with public disclosures
    OTHER = "other"                          # Any other type


# =============================================================================
# DISCLOSURE MECHANISM ENUMERATION
# =============================================================================

class DisclosureSourceType(enum.Enum):
    """
    Types of public disclosure mechanisms.
    
    Each mechanism has different:
    - Data granularity (daily, quarterly, irregular)
    - Available fields (shares, value, weight, dates)
    - Known limitations (reporting delays, no execution prices)
    """
    ETF_HOLDINGS = "etf_holdings"            # Daily/periodic ETF holdings disclosure
    SEC_13F = "sec_13f"                      # SEC Form 13F (quarterly, 45-day delay)
    SEC_13D_G = "sec_13d_g"                  # SEC Form 13D/13G (>5% ownership)
    FUND_REPORT = "fund_report"             # Fund reports (semi-annual, annual)
    ANNUAL_LETTER = "annual_letter"         # Shareholder letters (Berkshire, etc.)
    REGULATORY_FILING = "regulatory_filing" # Other regulatory filings
    PUBLIC_STATEMENT = "public_statement"   # Public interviews, presentations
    FORM_4 = "form_4"                       # SEC Form 4 (insider transactions)
    NPORT = "nport"                         # SEC Form N-PORT (mutual fund holdings)
    CUSTOM = "custom"                       # Custom/other disclosure source


class DataGranularity(enum.Enum):
    """Data update frequency for disclosure sources."""
    REAL_TIME = "real_time"     # Intraday updates (rare)
    DAILY = "daily"             # Daily disclosure (ETFs)
    WEEKLY = "weekly"           # Weekly updates
    MONTHLY = "monthly"         # Monthly reports
    QUARTERLY = "quarterly"     # Quarterly filings (13F)
    SEMI_ANNUAL = "semi_annual" # Semi-annual reports
    ANNUAL = "annual"           # Annual reports/letters
    IRREGULAR = "irregular"     # No fixed schedule


class AlertFrequency(enum.Enum):
    """Supported alert frequencies based on disclosure type."""
    INSTANT = "instant"         # Immediate notification (for daily data)
    DAILY_DIGEST = "daily"      # Daily summary
    WEEKLY_DIGEST = "weekly"    # Weekly summary
    ON_DISCLOSURE = "on_disclosure"  # When new disclosure appears


# =============================================================================
# SUPPORTED FEATURES
# =============================================================================

class SupportedFeature(enum.Enum):
    """Features that can be enabled per investor based on data availability."""
    HOLDINGS_DIFF = "holdings_diff"         # Show holdings changes
    TRADE_HISTORY = "trade_history"         # Show individual trades (ARK-style)
    AI_SUMMARY = "ai_summary"               # Generate AI summaries
    AI_RATIONALE = "ai_rationale"           # Generate AI rationales
    INSTANT_ALERTS = "instant_alerts"       # Support instant notifications
    WEIGHT_TRACKING = "weight_tracking"     # Track portfolio weights
    VALUE_TRACKING = "value_tracking"       # Track position values


# =============================================================================
# TRANSPARENCY ENUMERATIONS
# =============================================================================

class TransparencyLabel(enum.Enum):
    """
    Simplified transparency labels for UI display.
    
    IMPORTANT: This is NOT a performance or quality ranking.
    This reflects disclosure characteristics only.
    """
    HIGH = "high"           # Score 70-100: Frequent, timely, granular
    MEDIUM = "medium"       # Score 40-69: Moderate disclosure
    LOW = "low"             # Score 0-39: Infrequent, delayed, limited


class SourceReliabilityLevel(enum.Enum):
    """
    Reliability level of disclosure sources.
    Based on whether source is official/regulatory vs informal.
    """
    OFFICIAL_REGULATORY = "official_regulatory"  # SEC filings, exchange requirements
    OFFICIAL_VOLUNTARY = "official_voluntary"    # Official company disclosures
    THIRD_PARTY_VERIFIED = "third_party_verified"  # Verified by data providers
    SELF_REPORTED = "self_reported"              # Self-reported, unverified
    INFORMAL = "informal"                        # Interviews, social media


class DataGranularityLevel(enum.Enum):
    """
    Level of detail available in disclosures.
    """
    POSITION_LEVEL = "position_level"        # Full position details (shares, value, weight)
    AGGREGATE_ONLY = "aggregate_only"        # Only aggregated data
    PARTIAL = "partial"                      # Some positions detailed, others not
    NARRATIVE_ONLY = "narrative_only"        # Text descriptions only, no numbers


# =============================================================================
# INVESTOR MODEL (GENERIC)
# =============================================================================

class Investor(Base):
    """
    Generic Investor/Institution model.
    
    Designed to support ANY notable investor or institution by abstracting
    over different public disclosure mechanisms.
    """
    __tablename__ = "investors"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Basic identification
    name = Column(String(255), nullable=False)
    slug = Column(String(255), unique=True, nullable=False)
    short_name = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    
    # Investor classification
    investor_type = Column(SQLEnum(InvestorType), nullable=False, default=InvestorType.OTHER)
    
    # Expected update frequency (overall, based on primary disclosure)
    expected_update_frequency = Column(SQLEnum(DataGranularity), nullable=False, default=DataGranularity.QUARTERLY)
    
    # Typical reporting delay in days (helps set user expectations)
    typical_reporting_delay_days = Column(Integer, nullable=True, default=0)
    
    # Supported features (JSON array of feature names)
    supported_features = Column(JSONB, nullable=False, default=list)
    
    # Supported alert frequencies (JSON array)
    supported_alert_frequencies = Column(JSONB, nullable=False, default=list)
    
    # =========================================================================
    # TRANSPARENCY INDICATOR FIELDS
    # =========================================================================
    # IMPORTANT: Transparency reflects disclosure characteristics, NOT performance
    # or investment quality. Do NOT use for ranking investors.
    
    # Source reliability: How official/verified is the data source?
    source_reliability = Column(
        SQLEnum(SourceReliabilityLevel),
        nullable=True,
        default=SourceReliabilityLevel.OFFICIAL_REGULATORY
    )
    
    # Data granularity level: How detailed is the disclosed data?
    data_granularity_level = Column(
        SQLEnum(DataGranularityLevel),
        nullable=True,
        default=DataGranularityLevel.POSITION_LEVEL
    )
    
    # Transparency Score (0-100) - Computed from four components
    # Each component contributes 0-25 points:
    # 1. Disclosure Frequency (from expected_update_frequency)
    # 2. Reporting Delay (from typical_reporting_delay_days)
    # 3. Data Granularity (from data_granularity_level)
    # 4. Source Reliability (from source_reliability)
    transparency_score = Column(Integer, nullable=True, default=50)
    
    # Transparency Label: High / Medium / Low (derived from score)
    transparency_label = Column(
        SQLEnum(TransparencyLabel),
        nullable=True,
        default=TransparencyLabel.MEDIUM
    )
    
    # Human-readable explanation of the transparency score
    transparency_explanation = Column(Text, nullable=True)
    
    # =========================================================================
    # METADATA
    # =========================================================================
    
    logo_url = Column(String(500), nullable=True)
    website_url = Column(String(500), nullable=True)
    aum_billions = Column(String(50), nullable=True)
    headquarters_country = Column(String(100), nullable=True)
    founded_year = Column(Integer, nullable=True)
    
    # Status tracking
    is_active = Column(Boolean, default=True)
    is_featured = Column(Boolean, default=False)  # Show in featured section
    last_data_fetch = Column(DateTime, nullable=True)
    last_change_detected = Column(DateTime, nullable=True)
    
    # Data confidence indicator (0-100) - DEPRECATED, use transparency_score
    data_confidence_score = Column(Integer, nullable=True, default=50)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    disclosure_sources = relationship("DisclosureSource", back_populates="investor", cascade="all, delete-orphan")
    holdings_snapshots = relationship("HoldingsSnapshot", back_populates="investor", cascade="all, delete-orphan")
    strategy_notes = relationship("StrategyNote", back_populates="investor", cascade="all, delete-orphan")
    actions = relationship("InvestorAction", back_populates="investor", cascade="all, delete-orphan")
    
    def get_supported_features(self) -> list[str]:
        """Get list of supported feature names."""
        return self.supported_features or []
    
    def supports_feature(self, feature: SupportedFeature) -> bool:
        """Check if investor supports a specific feature."""
        return feature.value in self.get_supported_features()
    
    def get_primary_disclosure(self) -> "DisclosureSource | None":
        """Get the primary disclosure source."""
        for source in self.disclosure_sources:
            if source.is_primary:
                return source
        return self.disclosure_sources[0] if self.disclosure_sources else None


# =============================================================================
# DISCLOSURE SOURCE MODEL
# =============================================================================

class DisclosureSource(Base):
    """
    Disclosure source configuration for an investor.
    
    An investor may have MULTIPLE disclosure sources (e.g., 13F + annual letters).
    Each source has its own configuration, limitations, and ingestion logic.
    """
    __tablename__ = "disclosure_sources"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    # Source type and configuration
    source_type = Column(SQLEnum(DisclosureSourceType), nullable=False)
    source_name = Column(String(255), nullable=False)  # Human-readable name
    
    # Is this the primary disclosure source?
    is_primary = Column(Boolean, default=False)
    
    # Data characteristics
    data_granularity = Column(SQLEnum(DataGranularity), nullable=False)
    
    # Typical delay from data date to availability
    reporting_delay_days = Column(Integer, nullable=True, default=0)
    
    # Source-specific configuration (flexible JSON)
    # Examples:
    # - ETF: {"csv_url": "...", "fund_ticker": "ARKK"}
    # - 13F: {"cik": "0001234567", "filer_name": "..."}
    # - Letter: {"url_pattern": "...", "parse_format": "..."}
    source_config = Column(JSONB, nullable=True, default=dict)
    
    # Available data fields (JSON array)
    # e.g., ["shares", "value", "weight", "trade_date"]
    available_fields = Column(JSONB, nullable=False, default=list)
    
    # Known limitations (displayed in UI)
    # e.g., ["No execution prices", "45-day reporting delay"]
    known_limitations = Column(JSONB, nullable=False, default=list)
    
    # Ingestion status
    is_active = Column(Boolean, default=True)
    last_fetch_at = Column(DateTime, nullable=True)
    last_fetch_success = Column(Boolean, nullable=True)
    last_fetch_error = Column(Text, nullable=True)
    
    # Schedule configuration
    # e.g., {"cron": "0 23 * * *"} for daily at 11pm
    fetch_schedule = Column(JSONB, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    investor = relationship("Investor", back_populates="disclosure_sources")
    
    def get_limitation_text(self) -> str:
        """Get formatted limitation text for UI."""
        limitations = self.known_limitations or []
        if not limitations:
            return "Standard disclosure"
        return "; ".join(limitations)


# =============================================================================
# STRATEGY NOTE MODEL
# =============================================================================

class StrategyNote(Base):
    """
    Curated strategy notes for investors (used for AI rationale grounding).
    
    These are manually curated text snippets from public sources that describe
    an investor's stated strategy, philosophy, or focus areas.
    """
    __tablename__ = "strategy_notes"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    investor_id = Column(UUID(as_uuid=True), ForeignKey("investors.id", ondelete="CASCADE"), nullable=False)
    
    snippet_id = Column(String(100), nullable=False)  # Unique identifier for citation
    text = Column(Text, nullable=False)
    source_title = Column(String(500), nullable=True)
    source_url = Column(String(500), nullable=True)
    source_date = Column(DateTime, nullable=True)
    
    # Categorization
    topic = Column(String(100), nullable=True)  # e.g., "innovation", "valuation", "sector_focus"
    
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    investor = relationship("Investor", back_populates="strategy_notes")


# =============================================================================
# TRANSPARENCY SCORING SYSTEM
# =============================================================================

class TransparencyScorer:
    """
    Deterministic transparency scoring system.
    
    IMPORTANT DISCLAIMER:
    Transparency reflects disclosure characteristics, NOT performance or quality.
    This score should NOT be used to rank investors or imply investment quality.
    
    The score is computed from four components, each worth 0-25 points:
    1. Disclosure Frequency (0-25)
    2. Reporting Delay (0-25)
    3. Data Granularity (0-25)
    4. Source Reliability (0-25)
    
    Total: 0-100 points
    """
    
    # Frequency scores (0-25)
    FREQUENCY_SCORES = {
        DataGranularity.REAL_TIME: 25,
        DataGranularity.DAILY: 23,
        DataGranularity.WEEKLY: 18,
        DataGranularity.MONTHLY: 14,
        DataGranularity.QUARTERLY: 10,
        DataGranularity.SEMI_ANNUAL: 6,
        DataGranularity.ANNUAL: 3,
        DataGranularity.IRREGULAR: 1,
    }
    
    # Source reliability scores (0-25)
    RELIABILITY_SCORES = {
        SourceReliabilityLevel.OFFICIAL_REGULATORY: 25,
        SourceReliabilityLevel.OFFICIAL_VOLUNTARY: 20,
        SourceReliabilityLevel.THIRD_PARTY_VERIFIED: 15,
        SourceReliabilityLevel.SELF_REPORTED: 8,
        SourceReliabilityLevel.INFORMAL: 3,
    }
    
    # Data granularity level scores (0-25)
    GRANULARITY_LEVEL_SCORES = {
        DataGranularityLevel.POSITION_LEVEL: 25,
        DataGranularityLevel.PARTIAL: 18,
        DataGranularityLevel.AGGREGATE_ONLY: 10,
        DataGranularityLevel.NARRATIVE_ONLY: 3,
    }
    
    @classmethod
    def compute_delay_score(cls, delay_days: int | None) -> int:
        """
        Compute delay score (0-25) based on typical reporting delay.
        
        Lower delay = higher score.
        """
        if delay_days is None:
            return 12  # Unknown, assume medium
        
        if delay_days <= 1:
            return 25  # Same day or next day
        elif delay_days <= 3:
            return 22
        elif delay_days <= 7:
            return 18
        elif delay_days <= 14:
            return 15
        elif delay_days <= 30:
            return 12
        elif delay_days <= 45:
            return 8  # 13F delay
        elif delay_days <= 60:
            return 5
        elif delay_days <= 90:
            return 3
        else:
            return 1  # More than 90 days
    
    @classmethod
    def compute_score(
        cls,
        frequency: DataGranularity,
        delay_days: int | None,
        granularity_level: DataGranularityLevel | None,
        source_reliability: SourceReliabilityLevel | None,
    ) -> tuple[int, str, TransparencyLabel]:
        """
        Compute the full transparency score.
        
        Returns:
            tuple of (score, explanation, label)
        """
        # Component scores
        frequency_score = cls.FREQUENCY_SCORES.get(frequency, 5)
        delay_score = cls.compute_delay_score(delay_days)
        granularity_score = cls.GRANULARITY_LEVEL_SCORES.get(
            granularity_level or DataGranularityLevel.POSITION_LEVEL,
            15
        )
        reliability_score = cls.RELIABILITY_SCORES.get(
            source_reliability or SourceReliabilityLevel.OFFICIAL_REGULATORY,
            15
        )
        
        # Total score
        total_score = frequency_score + delay_score + granularity_score + reliability_score
        
        # Determine label
        if total_score >= 70:
            label = TransparencyLabel.HIGH
        elif total_score >= 40:
            label = TransparencyLabel.MEDIUM
        else:
            label = TransparencyLabel.LOW
        
        # Build explanation
        explanation_parts = []
        
        # Frequency explanation
        if frequency in [DataGranularity.REAL_TIME, DataGranularity.DAILY]:
            explanation_parts.append(f"Frequent disclosures ({frequency.value})")
        elif frequency in [DataGranularity.WEEKLY, DataGranularity.MONTHLY]:
            explanation_parts.append(f"Periodic disclosures ({frequency.value})")
        else:
            explanation_parts.append(f"Infrequent disclosures ({frequency.value})")
        
        # Delay explanation
        if delay_days is not None:
            if delay_days <= 1:
                explanation_parts.append("minimal reporting delay")
            elif delay_days <= 7:
                explanation_parts.append(f"{delay_days}-day reporting delay")
            elif delay_days <= 45:
                explanation_parts.append(f"{delay_days}-day reporting delay (typical for regulatory filings)")
            else:
                explanation_parts.append(f"significant reporting delay ({delay_days} days)")
        
        # Granularity explanation
        if granularity_level == DataGranularityLevel.POSITION_LEVEL:
            explanation_parts.append("detailed position-level data")
        elif granularity_level == DataGranularityLevel.PARTIAL:
            explanation_parts.append("partially detailed data")
        elif granularity_level == DataGranularityLevel.AGGREGATE_ONLY:
            explanation_parts.append("aggregate data only")
        else:
            explanation_parts.append("narrative disclosures")
        
        # Reliability explanation
        if source_reliability == SourceReliabilityLevel.OFFICIAL_REGULATORY:
            explanation_parts.append("official regulatory source")
        elif source_reliability == SourceReliabilityLevel.OFFICIAL_VOLUNTARY:
            explanation_parts.append("official voluntary disclosure")
        else:
            explanation_parts.append("third-party or informal sources")
        
        explanation = "; ".join(explanation_parts) + "."
        
        return total_score, explanation, label
    
    @classmethod
    def compute_for_investor(cls, investor: Investor) -> tuple[int, str, TransparencyLabel]:
        """
        Compute transparency score for an investor based on their attributes.
        """
        return cls.compute_score(
            frequency=investor.expected_update_frequency,
            delay_days=investor.typical_reporting_delay_days,
            granularity_level=investor.data_granularity_level,
            source_reliability=investor.source_reliability,
        )
    
    @classmethod
    def get_label_description(cls, label: TransparencyLabel) -> str:
        """Get description for a transparency label."""
        descriptions = {
            TransparencyLabel.HIGH: (
                "High transparency: Frequent, timely, and detailed disclosures "
                "from official sources."
            ),
            TransparencyLabel.MEDIUM: (
                "Medium transparency: Periodic disclosures with moderate delay "
                "and detail level."
            ),
            TransparencyLabel.LOW: (
                "Low transparency: Infrequent, delayed, or limited disclosures. "
                "Interpretations should be treated with extra caution."
            ),
        }
        return descriptions.get(label, "Unknown transparency level.")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_default_features_for_disclosure(source_type: DisclosureSourceType) -> list[str]:
    """Get default supported features based on disclosure type."""
    features_map = {
        DisclosureSourceType.ETF_HOLDINGS: [
            SupportedFeature.HOLDINGS_DIFF.value,
            SupportedFeature.TRADE_HISTORY.value,
            SupportedFeature.AI_SUMMARY.value,
            SupportedFeature.AI_RATIONALE.value,
            SupportedFeature.INSTANT_ALERTS.value,
            SupportedFeature.WEIGHT_TRACKING.value,
        ],
        DisclosureSourceType.SEC_13F: [
            SupportedFeature.HOLDINGS_DIFF.value,
            SupportedFeature.AI_SUMMARY.value,
            SupportedFeature.AI_RATIONALE.value,
            SupportedFeature.VALUE_TRACKING.value,
        ],
        DisclosureSourceType.ANNUAL_LETTER: [
            SupportedFeature.AI_SUMMARY.value,
        ],
        DisclosureSourceType.FUND_REPORT: [
            SupportedFeature.HOLDINGS_DIFF.value,
            SupportedFeature.AI_SUMMARY.value,
        ],
    }
    return features_map.get(source_type, [SupportedFeature.AI_SUMMARY.value])


def get_default_alert_frequencies(granularity: DataGranularity) -> list[str]:
    """Get default alert frequencies based on data granularity."""
    frequency_map = {
        DataGranularity.REAL_TIME: [AlertFrequency.INSTANT.value, AlertFrequency.DAILY_DIGEST.value],
        DataGranularity.DAILY: [AlertFrequency.INSTANT.value, AlertFrequency.DAILY_DIGEST.value, AlertFrequency.WEEKLY_DIGEST.value],
        DataGranularity.WEEKLY: [AlertFrequency.DAILY_DIGEST.value, AlertFrequency.WEEKLY_DIGEST.value],
        DataGranularity.MONTHLY: [AlertFrequency.WEEKLY_DIGEST.value, AlertFrequency.ON_DISCLOSURE.value],
        DataGranularity.QUARTERLY: [AlertFrequency.WEEKLY_DIGEST.value, AlertFrequency.ON_DISCLOSURE.value],
        DataGranularity.SEMI_ANNUAL: [AlertFrequency.ON_DISCLOSURE.value],
        DataGranularity.ANNUAL: [AlertFrequency.ON_DISCLOSURE.value],
        DataGranularity.IRREGULAR: [AlertFrequency.ON_DISCLOSURE.value],
    }
    return frequency_map.get(granularity, [AlertFrequency.ON_DISCLOSURE.value])


def update_investor_transparency(investor: Investor) -> None:
    """
    Update an investor's transparency score and related fields.
    
    Call this whenever transparency-related fields change.
    """
    score, explanation, label = TransparencyScorer.compute_for_investor(investor)
    investor.transparency_score = score
    investor.transparency_explanation = explanation
    investor.transparency_label = label
    # Keep data_confidence_score in sync for backward compatibility
    investor.data_confidence_score = score
