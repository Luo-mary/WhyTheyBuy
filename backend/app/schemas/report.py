"""
Report schemas - Evidence-based AI analysis with explainability.

DESIGN PRINCIPLES:
- Honest: Show exactly what evidence was used
- Cautious: Always list what is unknown
- Institutional-grade: Rigorous evidence tracking
- Non-advisory: Descriptive only, no recommendations
"""
from datetime import datetime, date
from typing import Literal
from uuid import UUID
from pydantic import BaseModel, Field, field_validator, model_validator
import enum


# =============================================================================
# EVIDENCE TRACKING SYSTEM
# =============================================================================

class SignalCategory(str, enum.Enum):
    """Categories of signals that AI can use."""
    HOLDINGS_DATA = "holdings_data"           # Position data from disclosures
    PRICE_DATA = "price_data"                 # Market price information
    COMPANY_PROFILE = "company_profile"       # Company fundamentals
    INVESTOR_STRATEGY = "investor_strategy"   # Strategy notes/letters
    DISCLOSURE_METADATA = "disclosure_metadata"  # Filing dates, disclosure type
    HISTORICAL_PATTERN = "historical_pattern"  # Past behavior patterns
    WEB_SEARCH = "web_search"                   # Google Search grounding results


class EvidenceSignal(BaseModel):
    """
    A specific piece of evidence used in AI analysis.
    
    Each signal must be traceable to system-provided data.
    """
    signal_id: str = Field(description="Unique identifier for this signal")
    category: SignalCategory = Field(description="Category of the signal")
    description: str = Field(description="Human-readable description of the evidence")
    source: str = Field(description="Where this data came from (e.g., '13F filing Q3 2024')")
    value: str | None = Field(default=None, description="The actual value if applicable")
    
    class Config:
        use_enum_values = True


class StandardUnknown(str, enum.Enum):
    """
    Standard unknowns that MUST always be included.
    
    These are fundamental limitations that apply to all analyses.
    """
    EXECUTION_PRICE = "execution_price"
    EXECUTION_TIMING = "execution_timing"
    INVESTOR_REASONING = "investor_reasoning"
    FUTURE_INTENTIONS = "future_intentions"
    POSITION_SIZE_INTENT = "position_size_intent"
    FULL_PORTFOLIO_CONTEXT = "full_portfolio_context"


STANDARD_UNKNOWNS_TEXT = {
    StandardUnknown.EXECUTION_PRICE: "The exact price(s) at which trades were executed",
    StandardUnknown.EXECUTION_TIMING: "The specific dates and times of trade execution",
    StandardUnknown.INVESTOR_REASONING: "The investor's private reasoning and decision process",
    StandardUnknown.FUTURE_INTENTIONS: "Whether this represents a long-term view or short-term adjustment",
    StandardUnknown.POSITION_SIZE_INTENT: "Whether the position size reflects conviction level",
    StandardUnknown.FULL_PORTFOLIO_CONTEXT: "The investor's complete portfolio and hedging strategies",
}


class UnknownFactor(BaseModel):
    """A factor that is explicitly unknown or unavailable."""
    unknown_id: str = Field(description="Identifier for the unknown")
    description: str = Field(description="What we don't know")
    is_standard: bool = Field(default=False, description="Is this a standard unknown that always applies?")
    impact: str | None = Field(default=None, description="How this unknown affects interpretation")


class EvidencePanel(BaseModel):
    """
    Complete evidence panel for AI analysis explainability.
    
    PURPOSE:
    - Show what information the AI used
    - Show what information is unknown
    - Prevent over-interpretation
    - Increase trust and legal safety
    """
    # Evidence that WAS used
    signals_used: list[EvidenceSignal] = Field(
        default_factory=list,
        description="All signals/evidence used in this analysis"
    )
    
    # What we DON'T know
    unknowns: list[UnknownFactor] = Field(
        default_factory=list,
        description="Factors that are unknown or unavailable"
    )
    
    # Evidence quality assessment
    evidence_completeness: Literal["sufficient", "limited", "insufficient"] = Field(
        default="limited",
        description="Overall assessment of evidence quality"
    )
    
    evidence_completeness_note: str = Field(
        default="",
        description="Explanation of evidence completeness"
    )
    
    # Signals that were requested but not available
    signals_unavailable: list[str] = Field(
        default_factory=list,
        description="Signals that would be helpful but were not available"
    )
    
    # Transparency score context
    transparency_context: str | None = Field(
        default=None,
        description="Context about the investor's disclosure transparency"
    )
    
    # Auto-expand flag for UI
    should_auto_expand: bool = Field(
        default=False,
        description="Whether the evidence panel should auto-expand (true when transparency is low)"
    )
    
    @classmethod
    def create_with_standard_unknowns(
        cls,
        signals_used: list[EvidenceSignal],
        additional_unknowns: list[UnknownFactor] | None = None,
        transparency_score: int | None = None,
    ) -> "EvidencePanel":
        """
        Factory method to create evidence panel with standard unknowns included.
        """
        # Always include standard unknowns
        unknowns = [
            UnknownFactor(
                unknown_id=unknown.value,
                description=STANDARD_UNKNOWNS_TEXT[unknown],
                is_standard=True,
            )
            for unknown in StandardUnknown
        ]
        
        # Add any additional unknowns
        if additional_unknowns:
            unknowns.extend(additional_unknowns)
        
        # Assess evidence completeness
        signal_count = len(signals_used)
        if signal_count >= 5:
            completeness = "sufficient"
            note = "Multiple data points available for analysis"
        elif signal_count >= 2:
            completeness = "limited"
            note = "Some evidence available, but interpretation should be cautious"
        else:
            completeness = "insufficient"
            note = "Very limited evidence - any interpretation is highly speculative"
        
        # Determine if should auto-expand
        should_expand = (
            transparency_score is not None and transparency_score < 40
        ) or completeness == "insufficient"
        
        # Build transparency context
        transparency_context = None
        if transparency_score is not None:
            if transparency_score >= 70:
                transparency_context = "High disclosure transparency - frequent, timely data"
            elif transparency_score >= 40:
                transparency_context = "Medium disclosure transparency - periodic updates with some delay"
            else:
                transparency_context = "Low disclosure transparency - interpretations should be treated with extra caution"
        
        return cls(
            signals_used=signals_used,
            unknowns=unknowns,
            evidence_completeness=completeness,
            evidence_completeness_note=note,
            should_auto_expand=should_expand,
            transparency_context=transparency_context,
        )


# =============================================================================
# AI ANALYSIS SCHEMAS WITH EVIDENCE
# =============================================================================

class TopBuySell(BaseModel):
    """Top buy/sell item in AI summary."""
    ticker: str
    name: str
    change: str  # e.g., "+500 shares", "New position"
    note: str | None = None


class InterpretationNote(BaseModel):
    """
    Interpretation note with confidence level and evidence.
    
    NEVER high confidence - we cannot know investor intent.
    """
    note: str
    confidence: Literal["low", "medium"] = Field(
        description="Confidence level - only 'low' or 'medium' allowed, never 'high'"
    )
    evidence_ids: list[str] = Field(
        default_factory=list,
        description="IDs of evidence signals supporting this interpretation"
    )
    
    @field_validator("confidence")
    @classmethod
    def validate_confidence(cls, v: str) -> str:
        """Enforce no high confidence claims."""
        if v.lower() == "high":
            raise ValueError("High confidence is not allowed - we cannot know investor intent")
        return v.lower()


class AISummaryResponse(BaseModel):
    """
    AI-generated investor summary response with evidence panel.
    
    COMPLIANCE: This describes historical, publicly disclosed holdings changes.
    It does NOT provide investment advice or predictions.
    """
    headline: str = Field(description="One-line headline summarizing key activity")
    what_changed: list[str] = Field(description="3-5 bullet points describing main changes")
    top_buys: list[TopBuySell] = Field(default_factory=list)
    top_sells: list[TopBuySell] = Field(default_factory=list)
    observations: list[str] = Field(
        default_factory=list,
        description="Observable patterns in the data (not interpretations)"
    )
    interpretation_notes: list[InterpretationNote] = Field(
        default_factory=list,
        description="Cautious interpretations with explicit confidence levels"
    )
    
    # Evidence panel for explainability
    evidence_panel: EvidencePanel | None = Field(
        default=None,
        description="Evidence used and unknowns for this analysis"
    )
    
    limitations: str = Field(
        default="We do not know the investor's actual reasoning or exact execution prices.",
        description="Clear statement of what we don't know"
    )
    disclaimer: str = Field(
        default="This is not investment advice.",
        description="Required legal disclaimer"
    )


class PossibleRationale(BaseModel):
    """
    Possible rationale for an investor action with evidence tracking.
    
    COMPLIANCE: All rationales are hypotheses. We do NOT know actual intent.
    """
    hypothesis: str = Field(description="A plausible explanation (framed as hypothesis)")
    supporting_signals: list[str] = Field(
        min_length=1,
        description="Specific data points from provided information that support this hypothesis"
    )
    evidence_ids: list[str] = Field(
        default_factory=list,
        description="IDs of evidence signals used for this rationale"
    )
    confidence: Literal["low", "medium"] = Field(
        default="low",
        description="Only 'low' or 'medium' - never claim high confidence"
    )
    
    @field_validator("confidence")
    @classmethod
    def validate_confidence(cls, v: str) -> str:
        """Enforce no high confidence claims."""
        if v.lower() == "high":
            raise ValueError("High confidence is not allowed - we cannot know investor intent")
        return v.lower()


class AICompanyRationaleResponse(BaseModel):
    """
    AI-generated company rationale response with evidence panel.
    
    COMPLIANCE: This is descriptive analysis of publicly disclosed activity.
    It does NOT provide investment advice, predictions, or assume investor intent.
    """
    company_overview: str = Field(description="Brief factual description of the company")
    investor_activity_summary: str = Field(
        description="Factual summary of what the investor did (bought/sold, when, approximate size)"
    )
    possible_rationales: list[PossibleRationale] = Field(
        default_factory=list,
        description="Plausible explanations framed as hypotheses"
    )
    patterns_vs_history: str = Field(
        default="",
        description="How this activity compares to the investor's historical behavior"
    )
    
    # Evidence panel for explainability
    evidence_panel: EvidencePanel | None = Field(
        default=None,
        description="Evidence used and unknowns for this analysis"
    )
    
    what_is_unknown: str = Field(
        default="We do not know the exact execution prices, the investor's private reasoning, or their future intentions.",
        description="Explicit statement of unknown factors"
    )
    disclaimer: str = Field(
        default="Informational only, not investment advice.",
        description="Required legal disclaimer"
    )


# =============================================================================
# REPORT SCHEMAS
# =============================================================================

class ReportResponse(BaseModel):
    """Report response schema."""
    id: UUID
    user_id: UUID
    investor_id: UUID | None
    report_type: str
    report_date: date
    title: str
    summary_json: AISummaryResponse | None = None
    email_sent: bool
    email_sent_at: datetime | None
    is_read: bool
    read_at: datetime | None
    created_at: datetime
    
    class Config:
        from_attributes = True


class ReportListResponse(BaseModel):
    """Report list response."""
    reports: list[ReportResponse]
    total: int


class AICompanyRationaleRequest(BaseModel):
    """Request for AI company rationale."""
    investor_id: str  # UUID or slug
    ticker: str


# =============================================================================
# AI OUTPUT VALIDATION
# =============================================================================

class AIOutputValidator:
    """
    Validator for AI-generated outputs to ensure compliance and evidence integrity.
    
    KEY PRINCIPLES:
    - Reject outputs referencing non-provided data
    - Enforce schema validation
    - Auto-inject disclaimers
    """
    
    FORBIDDEN_PHRASES = [
        "you should buy",
        "you should sell",
        "i recommend",
        "we recommend",
        "buy now",
        "sell now",
        "will increase",
        "will decrease",
        "guaranteed",
        "certain to",
        "definitely will",
        "price target",
        "expected return",
        "insider information",
        "confidential sources",
    ]
    
    REQUIRED_DISCLAIMER_KEYWORDS = ["not", "advice"]
    
    @classmethod
    def validate_no_advisory_language(cls, text: str) -> tuple[bool, list[str]]:
        """Check that text contains no advisory/predictive language."""
        violations = []
        text_lower = text.lower()
        
        for phrase in cls.FORBIDDEN_PHRASES:
            if phrase in text_lower:
                violations.append(f"Contains forbidden phrase: '{phrase}'")
        
        return len(violations) == 0, violations
    
    @classmethod
    def validate_disclaimer_present(cls, disclaimer: str) -> bool:
        """Check that disclaimer contains required keywords."""
        disclaimer_lower = disclaimer.lower()
        return all(kw in disclaimer_lower for kw in cls.REQUIRED_DISCLAIMER_KEYWORDS)
    
    @classmethod
    def validate_evidence_references(
        cls,
        response: AISummaryResponse | AICompanyRationaleResponse,
        provided_signal_ids: set[str],
    ) -> tuple[bool, list[str]]:
        """
        Validate that all evidence references point to provided signals.
        
        CRITICAL: Reject any reference to non-provided data.
        """
        errors = []
        
        if response.evidence_panel:
            # Check that all signals_used have valid categories
            for signal in response.evidence_panel.signals_used:
                if signal.signal_id not in provided_signal_ids:
                    errors.append(f"References non-provided signal: {signal.signal_id}")
        
        # Check interpretation notes
        if isinstance(response, AISummaryResponse):
            for note in response.interpretation_notes:
                for eid in note.evidence_ids:
                    if eid not in provided_signal_ids:
                        errors.append(f"Interpretation references non-provided signal: {eid}")
        
        # Check rationales
        if isinstance(response, AICompanyRationaleResponse):
            for rationale in response.possible_rationales:
                for eid in rationale.evidence_ids:
                    if eid not in provided_signal_ids:
                        errors.append(f"Rationale references non-provided signal: {eid}")
        
        return len(errors) == 0, errors
    
    @classmethod
    def validate_has_standard_unknowns(
        cls,
        evidence_panel: EvidencePanel | None,
    ) -> tuple[bool, list[str]]:
        """
        Validate that standard unknowns are present.
        """
        if not evidence_panel:
            return False, ["Evidence panel is missing"]
        
        errors = []
        standard_unknown_ids = {u.value for u in StandardUnknown}
        present_unknown_ids = {u.unknown_id for u in evidence_panel.unknowns if u.is_standard}
        
        missing = standard_unknown_ids - present_unknown_ids
        if missing:
            errors.append(f"Missing standard unknowns: {missing}")
        
        return len(errors) == 0, errors
    
    @classmethod
    def validate_confidence_matches_evidence(
        cls,
        response: AISummaryResponse | AICompanyRationaleResponse,
    ) -> tuple[bool, list[str]]:
        """
        Validate that confidence levels are appropriate for evidence.
        
        Rule: If evidence is "insufficient", only "low" confidence allowed.
        """
        errors = []
        
        if response.evidence_panel:
            if response.evidence_panel.evidence_completeness == "insufficient":
                # Check all confidence levels
                if isinstance(response, AISummaryResponse):
                    for note in response.interpretation_notes:
                        if note.confidence != "low":
                            errors.append(
                                f"Insufficient evidence but interpretation has '{note.confidence}' confidence"
                            )
                
                if isinstance(response, AICompanyRationaleResponse):
                    for rationale in response.possible_rationales:
                        if rationale.confidence != "low":
                            errors.append(
                                f"Insufficient evidence but rationale has '{rationale.confidence}' confidence"
                            )
        
        return len(errors) == 0, errors
    
    @classmethod
    def validate_summary_response(
        cls,
        response: AISummaryResponse,
        provided_signal_ids: set[str] | None = None,
    ) -> tuple[bool, list[str]]:
        """Validate an AI summary response for compliance."""
        errors = []
        
        # Check disclaimer
        if not cls.validate_disclaimer_present(response.disclaimer):
            errors.append("Disclaimer must mention 'not advice'")
        
        # Check all text fields for advisory language
        all_text = " ".join([
            response.headline,
            " ".join(response.what_changed),
            " ".join(response.observations),
            " ".join(n.note for n in response.interpretation_notes),
        ])
        
        is_valid, violations = cls.validate_no_advisory_language(all_text)
        if not is_valid:
            errors.extend(violations)
        
        # Validate evidence if provided
        if provided_signal_ids:
            is_valid, evidence_errors = cls.validate_evidence_references(
                response, provided_signal_ids
            )
            errors.extend(evidence_errors)
        
        # Validate standard unknowns
        is_valid, unknown_errors = cls.validate_has_standard_unknowns(response.evidence_panel)
        errors.extend(unknown_errors)
        
        # Validate confidence matches evidence
        is_valid, confidence_errors = cls.validate_confidence_matches_evidence(response)
        errors.extend(confidence_errors)
        
        return len(errors) == 0, errors
    
    @classmethod
    def validate_rationale_response(
        cls,
        response: AICompanyRationaleResponse,
        provided_signal_ids: set[str] | None = None,
    ) -> tuple[bool, list[str]]:
        """Validate an AI rationale response for compliance."""
        errors = []
        
        # Check disclaimer
        if not cls.validate_disclaimer_present(response.disclaimer):
            errors.append("Disclaimer must mention 'not advice'")
        
        # Check all text fields
        all_text = " ".join([
            response.company_overview,
            response.investor_activity_summary,
            " ".join(r.hypothesis for r in response.possible_rationales),
            response.patterns_vs_history,
        ])
        
        is_valid, violations = cls.validate_no_advisory_language(all_text)
        if not is_valid:
            errors.extend(violations)
        
        # Ensure we have limitations stated
        if not response.what_is_unknown or len(response.what_is_unknown) < 20:
            errors.append("Must include substantial 'what_is_unknown' statement")
        
        # Validate evidence if provided
        if provided_signal_ids:
            is_valid, evidence_errors = cls.validate_evidence_references(
                response, provided_signal_ids
            )
            errors.extend(evidence_errors)
        
        # Validate standard unknowns
        is_valid, unknown_errors = cls.validate_has_standard_unknowns(response.evidence_panel)
        errors.extend(unknown_errors)
        
        # Validate confidence matches evidence
        is_valid, confidence_errors = cls.validate_confidence_matches_evidence(response)
        errors.extend(confidence_errors)
        
        return len(errors) == 0, errors


# =============================================================================
# EVIDENCE BUILDER HELPER
# =============================================================================

class EvidenceBuilder:
    """
    Helper class to build evidence panels from system data.
    
    This ensures AI only receives and can reference system-provided signals.
    """
    
    def __init__(self):
        self.signals: list[EvidenceSignal] = []
        self._signal_ids: set[str] = set()
    
    def add_holdings_signal(
        self,
        signal_id: str,
        description: str,
        source: str,
        value: str | None = None,
    ) -> str:
        """Add a holdings-related signal."""
        signal = EvidenceSignal(
            signal_id=signal_id,
            category=SignalCategory.HOLDINGS_DATA,
            description=description,
            source=source,
            value=value,
        )
        self.signals.append(signal)
        self._signal_ids.add(signal_id)
        return signal_id
    
    def add_price_signal(
        self,
        signal_id: str,
        description: str,
        source: str,
        value: str | None = None,
    ) -> str:
        """Add a price-related signal."""
        signal = EvidenceSignal(
            signal_id=signal_id,
            category=SignalCategory.PRICE_DATA,
            description=description,
            source=source,
            value=value,
        )
        self.signals.append(signal)
        self._signal_ids.add(signal_id)
        return signal_id
    
    def add_company_signal(
        self,
        signal_id: str,
        description: str,
        source: str,
        value: str | None = None,
    ) -> str:
        """Add a company profile signal."""
        signal = EvidenceSignal(
            signal_id=signal_id,
            category=SignalCategory.COMPANY_PROFILE,
            description=description,
            source=source,
            value=value,
        )
        self.signals.append(signal)
        self._signal_ids.add(signal_id)
        return signal_id
    
    def add_strategy_signal(
        self,
        signal_id: str,
        description: str,
        source: str,
        value: str | None = None,
    ) -> str:
        """Add an investor strategy signal."""
        signal = EvidenceSignal(
            signal_id=signal_id,
            category=SignalCategory.INVESTOR_STRATEGY,
            description=description,
            source=source,
            value=value,
        )
        self.signals.append(signal)
        self._signal_ids.add(signal_id)
        return signal_id
    
    def add_disclosure_signal(
        self,
        signal_id: str,
        description: str,
        source: str,
        value: str | None = None,
    ) -> str:
        """Add a disclosure metadata signal."""
        signal = EvidenceSignal(
            signal_id=signal_id,
            category=SignalCategory.DISCLOSURE_METADATA,
            description=description,
            source=source,
            value=value,
        )
        self.signals.append(signal)
        self._signal_ids.add(signal_id)
        return signal_id
    
    def get_signal_ids(self) -> set[str]:
        """Get all signal IDs for validation."""
        return self._signal_ids.copy()
    
    def build_panel(
        self,
        transparency_score: int | None = None,
        additional_unknowns: list[UnknownFactor] | None = None,
        unavailable_signals: list[str] | None = None,
    ) -> EvidencePanel:
        """Build the evidence panel with standard unknowns."""
        panel = EvidencePanel.create_with_standard_unknowns(
            signals_used=self.signals,
            additional_unknowns=additional_unknowns,
            transparency_score=transparency_score,
        )
        
        if unavailable_signals:
            panel.signals_unavailable = unavailable_signals
        
        return panel
    
    def get_signals_for_prompt(self) -> str:
        """
        Format signals for AI prompt.
        
        This is the ONLY data the AI should reference.
        """
        if not self.signals:
            return "No signals available."
        
        lines = ["AVAILABLE SIGNALS (reference ONLY these in your analysis):"]
        for signal in self.signals:
            value_str = f" = {signal.value}" if signal.value else ""
            lines.append(
                f"- [{signal.signal_id}] ({signal.category}) {signal.description}{value_str} "
                f"(Source: {signal.source})"
            )
        
        lines.append("")
        lines.append("IMPORTANT: You may ONLY reference the signals listed above.")
        lines.append("Do NOT reference any data not provided in this list.")
        
        return "\n".join(lines)
