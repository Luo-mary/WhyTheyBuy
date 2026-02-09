"""
Generic Investor schemas supporting any investor type and disclosure mechanism.
"""
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field

from app.models.investor import (
    InvestorType,
    DisclosureSourceType,
    DataGranularity,
    AlertFrequency,
    SupportedFeature,
    TransparencyLabel,
    SourceReliabilityLevel,
    DataGranularityLevel,
)


# =============================================================================
# TRANSPARENCY SCHEMAS
# =============================================================================

TRANSPARENCY_DISCLAIMER = (
    "Transparency reflects disclosure characteristics, not performance or quality. "
    "This score should NOT be used to rank investors or imply investment quality."
)


class TransparencyScoreBreakdown(BaseModel):
    """
    Detailed breakdown of transparency score components.
    
    Each component is scored 0-25, for a total of 0-100.
    
    IMPORTANT: This is NOT a performance score.
    """
    # Component scores (0-25 each)
    frequency_score: int = Field(..., ge=0, le=25, description="Score for disclosure frequency")
    delay_score: int = Field(..., ge=0, le=25, description="Score for reporting delay")
    granularity_score: int = Field(..., ge=0, le=25, description="Score for data granularity")
    reliability_score: int = Field(..., ge=0, le=25, description="Score for source reliability")
    
    # Total score (0-100)
    total_score: int = Field(..., ge=0, le=100)
    
    # Human-readable explanations
    frequency_explanation: str
    delay_explanation: str
    granularity_explanation: str
    reliability_explanation: str


class TransparencyInfo(BaseModel):
    """
    Transparency information for an investor.
    
    IMPORTANT DISCLAIMER:
    Transparency reflects disclosure characteristics, NOT performance or quality.
    This score should NOT be used to rank investors or imply investment quality.
    """
    # Score and label
    score: int = Field(..., ge=0, le=100, description="Transparency score (0-100)")
    label: TransparencyLabel = Field(..., description="Simplified label: High/Medium/Low")
    label_description: str = Field(..., description="Description of what the label means")
    
    # Human-readable explanation
    explanation: str = Field(..., description="Plain English explanation of the score")
    
    # Score breakdown (optional, for detailed view)
    breakdown: TransparencyScoreBreakdown | None = None
    
    # Disclaimer (always include)
    disclaimer: str = TRANSPARENCY_DISCLAIMER
    
    class Config:
        from_attributes = True


class TransparencyTooltipInfo(BaseModel):
    """Compact transparency info for tooltips."""
    score: int
    label: str
    summary: str
    disclaimer: str = TRANSPARENCY_DISCLAIMER


# =============================================================================
# DISCLOSURE SOURCE SCHEMAS
# =============================================================================

class DisclosureSourceResponse(BaseModel):
    """Disclosure source response schema."""
    id: UUID
    source_type: DisclosureSourceType
    source_name: str
    is_primary: bool
    data_granularity: DataGranularity
    reporting_delay_days: int | None
    available_fields: list[str]
    known_limitations: list[str]
    is_active: bool
    last_fetch_at: datetime | None
    last_fetch_success: bool | None
    
    class Config:
        from_attributes = True


class DisclosureSourceSummary(BaseModel):
    """Compact disclosure source info for listings."""
    source_type: DisclosureSourceType
    source_name: str
    data_granularity: DataGranularity
    known_limitations: list[str] = Field(default_factory=list)


# =============================================================================
# INVESTOR SCHEMAS
# =============================================================================

class InvestorResponse(BaseModel):
    """
    Generic investor response schema.
    
    Supports ANY investor type, not limited to ARK or 13F filers.
    """
    id: UUID
    name: str
    slug: str
    short_name: str | None
    description: str | None
    
    # Classification
    investor_type: InvestorType
    expected_update_frequency: DataGranularity
    typical_reporting_delay_days: int | None
    
    # Capabilities
    supported_features: list[str]
    supported_alert_frequencies: list[str]
    
    # Metadata
    logo_url: str | None
    website_url: str | None
    aum_billions: str | None
    
    # Status
    is_active: bool
    is_featured: bool
    last_data_fetch: datetime | None
    last_change_detected: datetime | None
    
    # Transparency (NOT a performance indicator)
    transparency_score: int | None = Field(
        None,
        description="Transparency score (0-100). NOT a performance indicator."
    )
    transparency_label: TransparencyLabel | None = Field(
        None,
        description="Simplified transparency label: High/Medium/Low"
    )
    
    # Deprecated: use transparency_score instead
    data_confidence_score: int | None = None
    
    class Config:
        from_attributes = True


class InvestorListResponse(BaseModel):
    """Investor list response schema."""
    investors: list[InvestorResponse]
    total: int
    
    # Include transparency disclaimer in list responses
    transparency_disclaimer: str = TRANSPARENCY_DISCLAIMER
    
    class Config:
        from_attributes = True


class InvestorDetailResponse(InvestorResponse):
    """
    Detailed investor response with disclosure sources and metadata.
    
    This schema provides full transparency about:
    - What disclosure sources are available
    - How often updates are expected
    - What kind of insights can be generated
    - Known limitations of the data
    """
    # Disclosure sources
    disclosure_sources: list[DisclosureSourceResponse] = Field(default_factory=list)
    
    # Computed statistics
    total_holdings: int | None = None
    latest_snapshot_date: str | None = None
    changes_count_30d: int | None = None

    # For quarterly filers: latest filing date range and changes count
    latest_filing_from: str | None = None  # Start of the latest 13F filing period
    latest_filing_to: str | None = None    # End of the latest 13F filing period
    latest_filing_changes_count: int | None = None  # Changes in the latest 13F filing

    # Data transparency
    primary_disclosure_type: DisclosureSourceType | None = None
    data_limitations_summary: str | None = None
    
    # Transparency details
    transparency_info: TransparencyInfo | None = None
    transparency_explanation: str | None = None
    source_reliability: SourceReliabilityLevel | None = None
    data_granularity_level: DataGranularityLevel | None = None
    
    class Config:
        from_attributes = True


class InvestorCardResponse(BaseModel):
    """
    Compact investor card for listings.
    
    Includes key info for users to understand data availability.
    """
    id: UUID
    name: str
    slug: str
    short_name: str | None
    investor_type: InvestorType
    
    # Quick disclosure info
    update_frequency: DataGranularity
    
    # Transparency (simplified for cards)
    transparency_score: int | None = None
    transparency_label: TransparencyLabel | None = None
    
    # Deprecated
    data_confidence_score: int | None = None
    
    # Primary disclosure summary
    primary_disclosure: DisclosureSourceSummary | None = None
    
    # Status
    logo_url: str | None
    is_featured: bool
    last_change_detected: datetime | None
    
    class Config:
        from_attributes = True


# =============================================================================
# STRATEGY NOTE SCHEMAS
# =============================================================================

class StrategyNoteResponse(BaseModel):
    """Strategy note response schema."""
    id: UUID
    snippet_id: str
    text: str
    source_title: str | None
    source_url: str | None
    source_date: datetime | None
    topic: str | None
    
    class Config:
        from_attributes = True


# =============================================================================
# INVESTOR FILTERING/SEARCH
# =============================================================================

class InvestorFilterParams(BaseModel):
    """Filter parameters for investor search."""
    investor_types: list[InvestorType] | None = None
    disclosure_types: list[DisclosureSourceType] | None = None
    update_frequencies: list[DataGranularity] | None = None
    min_transparency_score: int | None = Field(None, ge=0, le=100)
    transparency_labels: list[TransparencyLabel] | None = None
    featured_only: bool = False
    search_query: str | None = None
    
    # Deprecated
    min_data_confidence: int | None = None


class InvestorTypeInfo(BaseModel):
    """Information about an investor type for UI display."""
    type_value: str
    display_name: str
    description: str
    typical_disclosure_types: list[str]
    example_investors: list[str]


class DisclosureTypeInfo(BaseModel):
    """Information about a disclosure type for UI display."""
    type_value: str
    display_name: str
    description: str
    typical_granularity: str
    typical_delay: str
    typical_limitations: list[str]


class TransparencyLabelInfo(BaseModel):
    """Information about transparency labels for UI display."""
    label_value: str
    display_name: str
    score_range: str
    description: str


# =============================================================================
# METADATA RESPONSES
# =============================================================================

class InvestorTypesResponse(BaseModel):
    """Response containing all investor type information."""
    types: list[InvestorTypeInfo]


class DisclosureTypesResponse(BaseModel):
    """Response containing all disclosure type information."""
    types: list[DisclosureTypeInfo]


class TransparencyLabelsResponse(BaseModel):
    """Response containing transparency label information."""
    labels: list[TransparencyLabelInfo]
    disclaimer: str = TRANSPARENCY_DISCLAIMER
    explanation: str = (
        "Transparency score reflects how frequently, timely, detailed, and officially "
        "an investor discloses their holdings. It is computed from four components: "
        "Disclosure Frequency (0-25), Reporting Delay (0-25), Data Granularity (0-25), "
        "and Source Reliability (0-25). This is NOT a performance or quality indicator."
    )


def get_investor_type_info() -> list[InvestorTypeInfo]:
    """Get information about all investor types."""
    return [
        InvestorTypeInfo(
            type_value=InvestorType.ETF_MANAGER.value,
            display_name="ETF Manager",
            description="Manages publicly traded ETFs with regular holdings disclosure",
            typical_disclosure_types=["ETF Holdings (daily/periodic)"],
            example_investors=["ARK Invest", "Invesco", "State Street"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.MUTUAL_FUND.value,
            display_name="Mutual Fund",
            description="Traditional mutual fund with periodic disclosure",
            typical_disclosure_types=["N-PORT (quarterly)", "Fund Reports"],
            example_investors=["Fidelity Contrafund", "T. Rowe Price"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.HEDGE_FUND.value,
            display_name="Hedge Fund",
            description="Hedge fund with 13F and occasional letter disclosure",
            typical_disclosure_types=["13F (quarterly)", "Letters"],
            example_investors=["Bridgewater", "Renaissance Technologies"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.PUBLIC_INSTITUTION.value,
            display_name="Public Institution",
            description="Large public institution like pension funds",
            typical_disclosure_types=["13F (quarterly)", "Annual Reports"],
            example_investors=["CalPERS", "Ontario Teachers' Pension Plan"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.INDIVIDUAL_INVESTOR.value,
            display_name="Notable Individual",
            description="Individual investor with public disclosures",
            typical_disclosure_types=["13F", "Form 4", "Letters"],
            example_investors=["Warren Buffett", "Carl Icahn"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.FAMILY_OFFICE.value,
            display_name="Family Office",
            description="Family office with 13F disclosure",
            typical_disclosure_types=["13F (quarterly)"],
            example_investors=["Soros Fund Management", "Duquesne"],
        ),
        InvestorTypeInfo(
            type_value=InvestorType.SOVEREIGN_WEALTH.value,
            display_name="Sovereign Wealth Fund",
            description="Government-owned investment fund",
            typical_disclosure_types=["13F", "Regulatory Filings"],
            example_investors=["Norway Government Pension Fund"],
        ),
    ]


def get_disclosure_type_info() -> list[DisclosureTypeInfo]:
    """Get information about all disclosure types."""
    return [
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.ETF_HOLDINGS.value,
            display_name="ETF Holdings",
            description="Daily or periodic ETF holdings disclosure",
            typical_granularity="Daily",
            typical_delay="Same day or next day",
            typical_limitations=["Exact execution prices usually unknown"],
        ),
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.SEC_13F.value,
            display_name="SEC Form 13F",
            description="Quarterly holdings report for institutional managers",
            typical_granularity="Quarterly",
            typical_delay="Up to 45 days after quarter end",
            typical_limitations=[
                "No exact trade dates",
                "No execution prices",
                "45-day reporting delay",
                "Only US securities over $100M",
            ],
        ),
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.SEC_13D_G.value,
            display_name="SEC Form 13D/13G",
            description="Beneficial ownership disclosure for >5% stakes",
            typical_granularity="Event-driven",
            typical_delay="10 days (13D) or 45 days (13G)",
            typical_limitations=["Only for stakes >5%", "Irregular timing"],
        ),
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.FUND_REPORT.value,
            display_name="Fund Report",
            description="Semi-annual or annual fund reports",
            typical_granularity="Semi-annual or Annual",
            typical_delay="60-90 days after period end",
            typical_limitations=["Significant delay", "Point-in-time snapshot"],
        ),
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.ANNUAL_LETTER.value,
            display_name="Annual Letter",
            description="Shareholder letters with commentary",
            typical_granularity="Annual",
            typical_delay="Varies",
            typical_limitations=["Narrative only", "Selective disclosure"],
        ),
        DisclosureTypeInfo(
            type_value=DisclosureSourceType.NPORT.value,
            display_name="SEC Form N-PORT",
            description="Monthly portfolio holdings for registered funds",
            typical_granularity="Monthly (public quarterly)",
            typical_delay="60 days",
            typical_limitations=["Only for registered funds", "Delayed publication"],
        ),
    ]


def get_transparency_label_info() -> list[TransparencyLabelInfo]:
    """Get information about transparency labels."""
    return [
        TransparencyLabelInfo(
            label_value=TransparencyLabel.HIGH.value,
            display_name="High Transparency",
            score_range="70-100",
            description=(
                "Frequent, timely, and detailed disclosures from official sources. "
                "Examples: Daily ETF holdings with position-level detail."
            ),
        ),
        TransparencyLabelInfo(
            label_value=TransparencyLabel.MEDIUM.value,
            display_name="Medium Transparency",
            score_range="40-69",
            description=(
                "Periodic disclosures with moderate delay and detail level. "
                "Examples: Quarterly 13F filings with full position data."
            ),
        ),
        TransparencyLabelInfo(
            label_value=TransparencyLabel.LOW.value,
            display_name="Low Transparency",
            score_range="0-39",
            description=(
                "Infrequent, significantly delayed, or limited disclosures. "
                "Interpretations should be treated with extra caution."
            ),
        ),
    ]
