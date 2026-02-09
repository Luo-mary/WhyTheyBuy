"""
Enhanced AI Analysis with Evidence-Based Reasoning Framework

This module provides structured, evidence-focused AI analysis that:
1. Prioritizes actionable insights over generic statements
2. Shows clear evidence trails (source, signal type, confidence)
3. Filters out irrelevant boilerplate information
4. Provides multi-perspective reasoning when available
"""

from enum import Enum
from pydantic import BaseModel
from typing import Optional, List
from decimal import Decimal
from datetime import datetime


class SignalType(str, Enum):
    """Types of evidence signals available for analysis"""
    HOLDINGS_DATA = "holdings_data"  # SEC 13F or ETF holdings
    HOLDINGS_CHANGE = "holdings_change"  # Position delta detected
    DISCLOSURE_TRANSPARENCY = "disclosure_transparency"  # Filing quality/timeliness
    STRATEGY_NOTE = "strategy_note"  # Investor's stated strategy
    SECTOR_CONCENTRATION = "sector_concentration"  # Portfolio composition
    POSITION_SIZE = "position_size"  # Relative weight analysis


class ConfidenceLevel(str, Enum):
    """Confidence levels for AI reasoning"""
    HIGH = "high"  # Multiple confirming signals
    MEDIUM = "medium"  # Single strong signal
    LOW = "low"  # Speculative, limited evidence


class ReasoningPillar(BaseModel):
    """Individual pillar of investment reasoning"""
    name: str  # e.g., "Sector Rotation", "Capital Deployment", "Position Building"
    description: str  # What this pillar shows
    evidence_signals: List[dict]  # List of supporting signals
    confidence: ConfidenceLevel
    key_observation: str  # 1-2 sentence key takeaway


class HoldingsChangeAnalysis(BaseModel):
    """Structured analysis of a specific holding change"""
    ticker: str
    company_name: str
    change_type: str  # "new", "added", "reduced", "sold_out"
    shares_before: Optional[Decimal]
    shares_after: Optional[Decimal]
    shares_delta: Optional[Decimal]
    weight_before: Optional[float]
    weight_after: Optional[float]
    weight_delta: Optional[float]
    value_delta: Optional[Decimal]
    from_date: str
    to_date: str
    
    # Evidence-based reasoning
    reasoning_pillars: List[ReasoningPillar]
    
    # What we don't know (transparency)
    unknowns: List[str]


class EvidenceSignal(BaseModel):
    """A single piece of evidence supporting the analysis"""
    signal_type: SignalType
    source: str  # e.g., "SEC Form 13F", "ARK Daily Holdings", "Investor Strategy Note"
    reporting_date: Optional[str]
    reporting_delay_days: Optional[int]
    data_point: str  # e.g., "BAC: +23.2M shares (5.0% → 5.02%)"
    inference: str  # What this signal suggests


class EvidencePanel(BaseModel):
    """Aggregated evidence for investment analysis"""
    investor_name: str
    disclosure_sources: List[dict]  # Available data sources
    data_availability: dict  # Which data is available for this investor
    signals_used: List[EvidenceSignal]  # All signals used in analysis
    data_completeness_score: float  # 0-100, how much of the picture we see
    what_we_dont_know: List[str]  # Explicitly listed unknowns


class EnhancedAIAnalysis(BaseModel):
    """Complete enhanced AI analysis with evidence tracking"""
    ticker: str
    company_name: str
    sector: str
    
    # Current snapshot
    current_weight: float
    position_status: str  # "core_holding", "emerging", "exit_candidate", "new_position"
    holding_date: str
    
    # Evidence-based reasoning (multiple pillars)
    reasoning_pillars: List[ReasoningPillar]
    
    # Risk factors specific to position
    risk_factors: List[str]
    
    # Evidence panel
    evidence: EvidencePanel
    
    # Confidence and caveats
    overall_confidence: ConfidenceLevel
    key_insight: str  # 1-2 sentence summary of why this matters
    
    # Compliance
    disclaimers: List[str]


# Example reasoning framework for a holding change
REASONING_FRAMEWORK = {
    "holding_analysis": [
        {
            "pillar_name": "Capital Deployment",
            "description": "How investor is deploying capital",
            "signals_needed": [
                SignalType.HOLDINGS_CHANGE,
                SignalType.POSITION_SIZE,
            ],
        },
        {
            "pillar_name": "Sector Allocation",
            "description": "Portfolio sector concentration and shifts",
            "signals_needed": [
                SignalType.SECTOR_CONCENTRATION,
            ],
        },
        {
            "pillar_name": "Position Building",
            "description": "Pattern of building or exiting positions",
            "signals_needed": [
                SignalType.HOLDINGS_DATA,
                SignalType.HOLDINGS_CHANGE,
            ],
        },
    ]
}


# Evidence filtering rules - what to include vs exclude
EVIDENCE_RULES = {
    "include": [
        "Actual position changes (shares, value, weight %)",
        "Date of change and time period",
        "Comparison to stated investor strategy",
        "Sector allocation relative to portfolio",
        "Position size relative to portfolio total",
        "New position entry or complete exit",
    ],
    "exclude": [
        "Generic company descriptions (available elsewhere)",
        "General sector information unrelated to position",
        "Templated statements about company competitive advantages",
        "Boilerplate risk disclaimers",
        "Information not specific to this investor's position",
    ],
}
