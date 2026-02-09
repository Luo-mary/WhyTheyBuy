"""
AI service for generating summaries and rationales with evidence tracking.

COMPLIANCE CRITICAL:
- All outputs are DESCRIPTIVE, HISTORICAL, and HYPOTHETICAL
- NO predictive or advisory language
- NO assumption of investor intent
- Always include disclaimers and limitations

EVIDENCE PANEL SYSTEM:
- Track all signals provided to AI
- Validate AI output only references provided signals
- Include standard unknowns in every response
- Auto-inject disclaimers

GENERIC INVESTOR SUPPORT:
- Adapts analysis based on investor type and disclosure mechanism
- Clearly references the disclosure source in outputs
- Adjusts confidence levels based on transparency

LOCALIZATION:
- Supports multiple languages for AI responses
- Language is passed from frontend via Accept-Language header
- AI generates responses in the user's preferred language
"""
import json
import logging
import base64
import os
from typing import Optional
import openai
from anthropic import Anthropic
import google.generativeai as genai
from app.config import settings
from app.services.language import (
    get_language_instruction,
    get_localized_disclaimer,
    normalize_language_code,
    DEFAULT_LANGUAGE,
)
from app.models.investor import (
    Investor,
    StrategyNote,
    InvestorType,
    DataGranularity,
    DisclosureSourceType,
    TransparencyLabel,
    TransparencyScorer,
)
from app.models.holdings import HoldingsChange, InvestorAction
from app.models.company import Company, MarketPrice
from app.schemas.report import (
    AISummaryResponse,
    TopBuySell,
    InterpretationNote,
    AICompanyRationaleResponse,
    PossibleRationale,
    AIOutputValidator,
    EvidencePanel,
    EvidenceBuilder,
    UnknownFactor,
    SignalCategory,
)

logger = logging.getLogger(__name__)

# Initialize clients
if settings.openai_api_key:
    openai_client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
else:
    openai_client = None

if settings.anthropic_api_key:
    anthropic_client = Anthropic(api_key=settings.anthropic_api_key)
else:
    anthropic_client = None

# Initialize Gemini 3 client
if settings.gemini_api_key:
    genai.configure(api_key=settings.gemini_api_key)
    gemini_model = genai.GenerativeModel(
        model_name=settings.gemini_model,
        system_instruction=None,  # Set per-request for flexibility
        generation_config=genai.GenerationConfig(
            temperature=0.2,
            max_output_tokens=2000,
        ),
    )
else:
    gemini_model = None


# =============================================================================
# PROMPT LOADING UTILITY
# =============================================================================

def _load_prompt(filename: str) -> str:
    """Load a prompt from the prompts folder."""
    prompt_path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "prompts",
        filename
    )
    try:
        with open(prompt_path, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        logger.warning(f"Prompt file not found: {filename}")
        return ""


# =============================================================================
# GLOBAL AI SYSTEM PROMPT (Evidence-Aware)
# =============================================================================

AI_SYSTEM_PROMPT = _load_prompt("system_prompt.txt")

# =============================================================================
# DISCLOSURE-AWARE CONTEXT BUILDERS
# =============================================================================

def get_disclosure_context(investor: Investor) -> dict:
    """
    Build disclosure context for AI prompts.
    
    This helps the AI understand:
    - What kind of data is available
    - Known limitations
    - Appropriate confidence levels based on transparency
    """
    primary_disclosure = investor.get_primary_disclosure()
    
    # Get transparency info
    transparency_score = investor.transparency_score or 50
    transparency_label = investor.transparency_label or TransparencyLabel.MEDIUM
    transparency_explanation = investor.transparency_explanation or ""

    # Safely get .value from enums that might already be strings
    def _enum_val(v):
        return v.value if hasattr(v, 'value') else str(v)

    context = {
        "investor_type": _enum_val(investor.investor_type),
        "investor_type_label": _get_investor_type_label(investor.investor_type),
        "update_frequency": _enum_val(investor.expected_update_frequency),
        "typical_delay_days": investor.typical_reporting_delay_days or 0,
        # Transparency info (NOT performance indicator)
        "transparency_score": transparency_score,
        "transparency_label": _enum_val(transparency_label),
        "transparency_explanation": transparency_explanation,
        # Deprecated field kept for compatibility
        "data_confidence_score": transparency_score,
    }
    
    if primary_disclosure:
        context.update({
            "disclosure_type": _enum_val(primary_disclosure.source_type),
            "disclosure_type_label": _get_disclosure_type_label(primary_disclosure.source_type),
            "data_granularity": _enum_val(primary_disclosure.data_granularity),
            "available_fields": primary_disclosure.available_fields or [],
            "known_limitations": primary_disclosure.known_limitations or [],
        })
    else:
        context.update({
            "disclosure_type": "unknown",
            "disclosure_type_label": "Unknown Disclosure Type",
            "data_granularity": "irregular",
            "available_fields": [],
            "known_limitations": ["Limited data available"],
        })
    
    return context


def _get_investor_type_label(investor_type: InvestorType) -> str:
    """Get human-readable label for investor type."""
    labels = {
        InvestorType.ETF_MANAGER: "ETF Manager",
        InvestorType.MUTUAL_FUND: "Mutual Fund",
        InvestorType.HEDGE_FUND: "Hedge Fund",
        InvestorType.PUBLIC_INSTITUTION: "Public Institution",
        InvestorType.INDIVIDUAL_INVESTOR: "Individual Investor",
        InvestorType.VENTURE_PE: "Venture Capital / Private Equity",
        InvestorType.SOVEREIGN_WEALTH: "Sovereign Wealth Fund",
        InvestorType.FAMILY_OFFICE: "Family Office",
        InvestorType.OTHER: "Other Investor",
    }
    return labels.get(investor_type, "Investor")


def _get_disclosure_type_label(disclosure_type: DisclosureSourceType) -> str:
    """Get human-readable label for disclosure type."""
    labels = {
        DisclosureSourceType.ETF_HOLDINGS: "ETF Holdings Disclosure",
        DisclosureSourceType.SEC_13F: "SEC Form 13F",
        DisclosureSourceType.SEC_13D_G: "SEC Form 13D/13G",
        DisclosureSourceType.FUND_REPORT: "Fund Report",
        DisclosureSourceType.ANNUAL_LETTER: "Annual Letter",
        DisclosureSourceType.REGULATORY_FILING: "Regulatory Filing",
        DisclosureSourceType.PUBLIC_STATEMENT: "Public Statement",
        DisclosureSourceType.FORM_4: "SEC Form 4",
        DisclosureSourceType.NPORT: "SEC Form N-PORT",
        DisclosureSourceType.CUSTOM: "Custom Disclosure",
    }
    return labels.get(disclosure_type, "Public Disclosure")


def get_confidence_guidance(disclosure_context: dict) -> str:
    """
    Get confidence guidance based on transparency level.
    
    IMPORTANT: Transparency reflects disclosure characteristics, NOT performance.
    """
    return "Provide analysis with appropriate confidence levels based on available evidence."


def get_limitations_for_disclosure(disclosure_context: dict) -> str:
    """Build limitations statement based on disclosure type and transparency."""
    return "Analysis is based on publicly disclosed information and subject to standard limitations of such data."


# =============================================================================
# EVIDENCE-AWARE PROMPT TEMPLATES
# =============================================================================

# =============================================================================
# EVIDENCE-AWARE PROMPT TEMPLATES (Loaded from prompts folder)
# =============================================================================

INVESTOR_SUMMARY_PROMPT_WITH_EVIDENCE = _load_prompt("investor_summary_prompt.txt")

COMPANY_RATIONALE_PROMPT_WITH_EVIDENCE = _load_prompt("company_rationale_prompt.txt")


# =============================================================================
# EVIDENCE COLLECTION FUNCTIONS
# =============================================================================

def build_evidence_for_summary(
    investor: Investor,
    changes: list[HoldingsChange],
    disclosure_context: dict,
) -> EvidenceBuilder:
    """
    Build evidence signals for investor summary.
    
    All data the AI can reference must be registered here.
    """
    builder = EvidenceBuilder()
    disclosure_label = disclosure_context.get("disclosure_type_label", "disclosure")
    
    # Add disclosure metadata signal
    builder.add_disclosure_signal(
        signal_id="DISC_META_001",
        description=f"Disclosure type: {disclosure_label}",
        source=f"{investor.name} public filings",
        value=disclosure_context.get("data_granularity", "irregular"),
    )
    
    # Add transparency signal
    builder.add_disclosure_signal(
        signal_id="TRANS_001",
        description=f"Disclosure transparency: {disclosure_context.get('transparency_label', 'medium')}",
        source="Computed transparency score",
        value=str(disclosure_context.get("transparency_score", 50)),
    )
    
    # Add holdings change signals
    for i, change in enumerate(changes[:50]):  # Limit to 50 to avoid token overflow
        signal_id = f"CHG_{i+1:03d}"
        
        change_desc = f"{change.change_type.value}: {change.ticker}"
        if change.shares_delta:
            change_desc += f" ({change.shares_delta:+,} shares)"
        if change.weight_delta:
            change_desc += f" ({change.weight_delta:+.2f}% weight)"
        
        builder.add_holdings_signal(
            signal_id=signal_id,
            description=change_desc,
            source=f"{disclosure_label}, {change.to_date}",
            value=f"{change.ticker}: {change.change_type.value}",
        )
        
        # Add price signal if available
        if change.price_range_low and change.price_range_high:
            builder.add_price_signal(
                signal_id=f"PRC_{i+1:03d}",
                description=f"Market price range for {change.ticker} (NOT execution price)",
                source=f"Market data, {change.to_date}",
                value=f"${change.price_range_low:.2f} - ${change.price_range_high:.2f}",
            )
    
    return builder


def build_evidence_for_rationale(
    investor: Investor,
    company: Company | None,
    actions: list[InvestorAction],
    changes: list[HoldingsChange],
    strategy_notes: list[StrategyNote],
    price_data: list[MarketPrice],
    disclosure_context: dict,
    resolved_ticker: str = "",
    resolved_name: str = "",
) -> EvidenceBuilder:
    """
    Build evidence signals for company rationale.
    
    All data the AI can reference must be registered here.
    """
    builder = EvidenceBuilder()
    disclosure_label = disclosure_context.get("disclosure_type_label", "disclosure")
    
    # Add disclosure metadata
    builder.add_disclosure_signal(
        signal_id="DISC_META_001",
        description=f"Disclosure type: {disclosure_label}",
        source=f"{investor.name} public filings",
        value=disclosure_context.get("data_granularity", "irregular"),
    )
    
    # Add transparency signal
    builder.add_disclosure_signal(
        signal_id="TRANS_001",
        description=f"Disclosure transparency: {disclosure_context.get('transparency_label', 'medium')}",
        source="Computed transparency score",
        value=str(disclosure_context.get("transparency_score", 50)),
    )
    
    # Add company profile signals
    comp_name = company.name if company else resolved_name
    comp_ticker = company.ticker if company else resolved_ticker
    builder.add_company_signal(
        signal_id="COMP_001",
        description="Company name and ticker",
        source="Company profile database" if company else "Holdings change data",
        value=f"{comp_name} ({comp_ticker})",
    )

    if company:
        if company.sector:
            builder.add_company_signal(
                signal_id="COMP_002",
                description="Sector",
                source="Company profile database",
                value=company.sector,
            )

        if company.industry:
            builder.add_company_signal(
                signal_id="COMP_003",
                description="Industry",
                source="Company profile database",
                value=company.industry,
            )

        if company.description:
            builder.add_company_signal(
                signal_id="COMP_004",
                description="Business description",
                source="Company profile database",
                value=company.description[:200],
            )
    
    # Add action signals (trades)
    for i, action in enumerate(actions[:20]):
        signal_id = f"ACT_{i+1:03d}"
        action_desc = f"{action.action_type.value} on {action.trade_date}"
        if action.shares:
            action_desc += f": {action.shares:,} shares"
        if action.estimated_value:
            action_desc += f" (~${action.estimated_value:,.0f})"
        
        builder.add_holdings_signal(
            signal_id=signal_id,
            description=action_desc,
            source=disclosure_label,
            value=f"{action.action_type.value}: {action.shares or 'unknown'} shares",
        )
        
        # Add price range for action
        if action.price_range_low and action.price_range_high:
            builder.add_price_signal(
                signal_id=f"ACT_PRC_{i+1:03d}",
                description=f"Market price range on {action.trade_date} (NOT execution price)",
                source="Market data",
                value=f"${action.price_range_low:.2f} - ${action.price_range_high:.2f}",
            )
    
    # Add position change signals
    for i, change in enumerate(changes[:20]):
        signal_id = f"CHG_{i+1:03d}"
        change_desc = f"{change.change_type.value}: {change.ticker}"
        if change.shares_delta:
            change_desc += f" ({change.shares_delta:+,} shares)"
        if change.weight_delta:
            change_desc += f" ({change.weight_delta:+.2f}% weight)"
        
        builder.add_holdings_signal(
            signal_id=signal_id,
            description=change_desc,
            source=f"{disclosure_label}, {change.from_date} to {change.to_date}",
            value=f"{change.change_type.value}",
        )
    
    # Add strategy notes signals
    for i, note in enumerate(strategy_notes[:5]):
        builder.add_strategy_signal(
            signal_id=f"STRAT_{note.snippet_id}",
            description=f"Strategy note: {note.text[:100]}...",
            source=note.source_title or "Investor public statement",
            value=note.text,
        )
    
    # Add price data signals
    if price_data:
        prices = sorted(price_data, key=lambda p: p.price_date)
        builder.add_price_signal(
            signal_id="PRICE_RANGE_001",
            description="Market price range for period (NOT execution prices)",
            source=f"Market data, {prices[0].price_date} to {prices[-1].price_date}",
            value=f"High: ${max(p.high_price for p in prices if p.high_price):.2f}, "
                  f"Low: ${min(p.low_price for p in prices if p.low_price):.2f}",
        )
        
        if prices[-1].close_price:
            builder.add_price_signal(
                signal_id="PRICE_LATEST_001",
                description="Latest closing price",
                source=f"Market data, {prices[-1].price_date}",
                value=f"${prices[-1].close_price:.2f}",
            )
    
    return builder


# =============================================================================
# AI GENERATION FUNCTIONS WITH EVIDENCE TRACKING
# =============================================================================

async def generate_investor_summary(
    investor: Investor,
    changes: list[HoldingsChange],
    language: str = DEFAULT_LANGUAGE,
) -> AISummaryResponse:
    """
    Generate AI summary for investor's holdings changes with evidence tracking.

    Adapts analysis based on:
    - Investor type (ETF, Hedge Fund, etc.)
    - Disclosure mechanism (daily ETF, quarterly 13F, etc.)
    - Data frequency and completeness

    Args:
        investor: Investor model instance
        changes: List of holdings changes to summarize
        language: ISO 639-1 language code for response language (e.g., "en", "zh")
    """
    # Get disclosure context
    disclosure_context = get_disclosure_context(investor)
    confidence_guidance = get_confidence_guidance(disclosure_context)
    limitations = get_limitations_for_disclosure(disclosure_context)
    transparency_score = disclosure_context.get("transparency_score", 50)
    
    # Build evidence
    evidence_builder = build_evidence_for_summary(
        investor, changes, disclosure_context
    )
    
    # Determine unavailable signals
    unavailable = []
    if not any(c.price_range_low for c in changes):
        unavailable.append("Market price data not available")
    if disclosure_context.get("data_granularity") in ["quarterly", "irregular"]:
        unavailable.append("Exact trade dates within period")
    
    # Build evidence panel
    evidence_panel = evidence_builder.build_panel(
        transparency_score=transparency_score,
        unavailable_signals=unavailable,
    )
    
    # Get date range
    dates = [c.to_date for c in changes]
    from_date = min(dates) if dates else None
    to_date = max(dates) if dates else None
    
    prompt = INVESTOR_SUMMARY_PROMPT_WITH_EVIDENCE.format(
        investor_name=investor.name,
        investor_type_label=disclosure_context.get("investor_type_label", "Investor"),
        disclosure_type_label=disclosure_context.get("disclosure_type_label", "Public Disclosure"),
        data_granularity=disclosure_context.get("data_granularity", "irregular"),
        delay_days=disclosure_context.get("typical_delay_days", 0),
        transparency_score=transparency_score,
        transparency_label=disclosure_context.get("transparency_label", "medium").upper(),
        confidence_guidance=confidence_guidance,
        available_signals=evidence_builder.get_signals_for_prompt(),
        from_date=str(from_date),
        to_date=str(to_date),
        limitations=limitations,
    )
    
    # Call AI with language support
    response_text = await call_ai(prompt, language=language)

    # Get localized disclaimer
    localized_disclaimer = get_localized_disclaimer(language)

    # Parse and validate response
    try:
        data = json.loads(response_text)

        # Build response object
        response = AISummaryResponse(
            headline=data.get("headline", "Holdings Update"),
            what_changed=data.get("what_changed", []),
            top_buys=[TopBuySell(**b) for b in data.get("top_buys", [])],
            top_sells=[TopBuySell(**s) for s in data.get("top_sells", [])],
            observations=data.get("observations", []),
            interpretation_notes=[
                InterpretationNote(**n) for n in data.get("interpretation_notes", [])
            ],
            evidence_panel=evidence_panel,
            limitations=data.get("limitations", limitations),
            disclaimer=data.get("disclaimer", localized_disclaimer),
        )

        # Validate for compliance
        provided_signal_ids = evidence_builder.get_signal_ids()
        is_valid, errors = AIOutputValidator.validate_summary_response(
            response, provided_signal_ids
        )
        if not is_valid:
            logger.warning(f"AI summary validation warnings: {errors}")
            # Auto-fix disclaimer if needed
            if any("disclaimer" in e.lower() for e in errors):
                response.disclaimer = localized_disclaimer

        return response

    except (json.JSONDecodeError, KeyError, ValueError) as e:
        logger.error(f"AI response parsing error: {e}")
        return AISummaryResponse(
            headline=f"{investor.name} Holdings Update",
            what_changed=[f"Detected {len(changes)} position changes"],
            top_buys=[],
            top_sells=[],
            observations=["Unable to generate detailed summary"],
            interpretation_notes=[],
            evidence_panel=evidence_panel,
            limitations=limitations,
            disclaimer=localized_disclaimer,
        )


async def generate_company_rationale(
    investor: Investor,
    company: Company | None,
    actions: list[InvestorAction],
    changes: list[HoldingsChange],
    strategy_notes: list[StrategyNote],
    price_data: list[MarketPrice],
    ticker: str | None = None,
    language: str = DEFAULT_LANGUAGE,
) -> AICompanyRationaleResponse:
    """
    Generate AI rationale for investor's activity on a company with evidence tracking.

    Adapts analysis based on disclosure type and available data.
    All rationales are hypotheses. We do NOT know actual intent.

    Args:
        investor: Investor model instance
        company: Company model instance (optional)
        actions: List of investor actions
        changes: List of holdings changes
        strategy_notes: List of strategy notes
        price_data: List of market price data
        ticker: Stock ticker symbol
        language: ISO 639-1 language code for response language (e.g., "en", "zh")
    """
    # Get disclosure context
    disclosure_context = get_disclosure_context(investor)
    confidence_guidance = get_confidence_guidance(disclosure_context)
    transparency_score = disclosure_context.get("transparency_score", 50)
    
    # Build what_is_unknown based on disclosure type
    what_is_unknown_parts = [
        "We do not know the exact execution prices",
        "the investor's private reasoning",
        "their future intentions",
        "whether this reflects conviction or rebalancing",
    ]
    
    if disclosure_context.get("data_granularity") in ["quarterly", "semi_annual", "annual"]:
        what_is_unknown_parts.append("exact trade dates within the period")
    
    what_is_unknown = ", ".join(what_is_unknown_parts) + "."
    
    # Resolve company name / ticker when Company record is missing
    resolved_ticker = (company.ticker if company else None) or ticker or (
        changes[0].ticker if changes else (actions[0].ticker if actions else "UNKNOWN")
    )
    resolved_name = (company.name if company else None) or (
        changes[0].company_name if changes else (actions[0].company_name if actions else resolved_ticker)
    )

    # Build evidence
    evidence_builder = build_evidence_for_rationale(
        investor, company, actions, changes, strategy_notes, price_data, disclosure_context,
        resolved_ticker=resolved_ticker, resolved_name=resolved_name,
    )
    
    # Determine unavailable signals
    unavailable = []
    if not price_data:
        unavailable.append("Historical price data")
    if not strategy_notes:
        unavailable.append("Investor strategy notes")
    if not actions:
        unavailable.append("Detailed trade data")
    
    # Add additional unknowns based on context
    additional_unknowns = []
    if not strategy_notes:
        additional_unknowns.append(UnknownFactor(
            unknown_id="no_strategy_notes",
            description="Investor's stated strategy or thesis for this position",
            is_standard=False,
            impact="Cannot assess alignment with investor's known approach",
        ))
    
    # Build evidence panel
    evidence_panel = evidence_builder.build_panel(
        transparency_score=transparency_score,
        additional_unknowns=additional_unknowns,
        unavailable_signals=unavailable,
    )
    
    prompt = COMPANY_RATIONALE_PROMPT_WITH_EVIDENCE.format(
        investor_name=investor.name,
        investor_type_label=disclosure_context.get("investor_type_label", "Investor"),
        disclosure_type_label=disclosure_context.get("disclosure_type_label", "Public Disclosure"),
        data_granularity=disclosure_context.get("data_granularity", "irregular"),
        transparency_score=transparency_score,
        transparency_label=disclosure_context.get("transparency_label", "medium").upper(),
        confidence_guidance=confidence_guidance,
        company_name=resolved_name,
        ticker=resolved_ticker,
        available_signals=evidence_builder.get_signals_for_prompt(),
        what_is_unknown=what_is_unknown,
    )

    # Call AI with language support
    response_text = await call_ai(prompt, language=language)

    # Get localized disclaimer
    localized_disclaimer = get_localized_disclaimer(language)

    # Parse and validate response
    try:
        data = json.loads(response_text)

        response = AICompanyRationaleResponse(
            company_overview=data.get("company_overview", (company.description if company else "") or ""),
            investor_activity_summary=data.get("investor_activity_summary", ""),
            possible_rationales=[
                PossibleRationale(**r) for r in data.get("possible_rationales", [])
            ],
            patterns_vs_history=data.get("patterns_vs_history", "Insufficient historical data to compare."),
            evidence_panel=evidence_panel,
            what_is_unknown=data.get("what_is_unknown", what_is_unknown),
            disclaimer=data.get("disclaimer", localized_disclaimer),
        )

        # Validate for compliance
        provided_signal_ids = evidence_builder.get_signal_ids()
        is_valid, errors = AIOutputValidator.validate_rationale_response(
            response, provided_signal_ids
        )
        if not is_valid:
            logger.warning(f"AI rationale validation warnings: {errors}")
            if any("disclaimer" in e.lower() for e in errors):
                response.disclaimer = localized_disclaimer

        return response

    except (json.JSONDecodeError, KeyError, ValueError) as e:
        logger.error(f"AI rationale parsing error: {e}")
        return AICompanyRationaleResponse(
            company_overview=(company.description if company else "") or f"{resolved_name} ({resolved_ticker})",
            investor_activity_summary=f"Activity detected for {investor.name} on {resolved_ticker}",
            possible_rationales=[
                PossibleRationale(
                    hypothesis="Unable to generate detailed analysis",
                    supporting_signals=["Insufficient data for analysis"],
                    evidence_ids=[],
                    confidence="low",
                )
            ],
            patterns_vs_history="Unable to analyze historical patterns.",
            evidence_panel=evidence_panel,
            what_is_unknown=what_is_unknown,
            disclaimer="Informational only, not investment advice.",
        )


def _strip_markdown_json(text: str) -> str:
    """Strip markdown code block wrapping from AI responses."""
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


async def call_ai(prompt: str, language: str = DEFAULT_LANGUAGE) -> str:
    """
    Call the configured AI provider with compliance-aware system prompt.

    Supports Gemini 3 (primary), OpenAI, and Anthropic Claude.
    Gemini 3 is the default for the Gemini 3 Hackathon submission.

    Args:
        prompt: The analysis prompt
        language: ISO 639-1 language code for response language (e.g., "en", "zh", "es")

    Returns:
        AI-generated response text in the specified language
    """
    # Get language instruction for non-English responses
    language_instruction = get_language_instruction(language)
    system_prompt = AI_SYSTEM_PROMPT
    if language_instruction:
        system_prompt = f"{AI_SYSTEM_PROMPT}\n\n{language_instruction}"

    if settings.ai_provider == "gemini" and gemini_model:
        # Use Gemini 3 - Google's latest model with enhanced reasoning
        combined_prompt = f"{system_prompt}\n\n---\n\n{prompt}"
        response = await gemini_model.generate_content_async(
            combined_prompt,
            generation_config=genai.GenerationConfig(
                temperature=0.2,
                max_output_tokens=8000,
            ),
        )
        return _strip_markdown_json(response.text)

    elif settings.ai_provider == "openai" and openai_client:
        response = await openai_client.chat.completions.create(
            model=settings.ai_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            max_tokens=2000,
        )
        return response.choices[0].message.content

    elif settings.ai_provider == "anthropic" and anthropic_client:
        response = anthropic_client.messages.create(
            model="claude-3-sonnet-20240229",
            system=system_prompt,
            max_tokens=2000,
            messages=[
                {"role": "user", "content": prompt},
            ],
        )
        return response.content[0].text

    else:
        logger.warning("No AI API configured - returning mock response")
        disclaimer = get_localized_disclaimer(language)
        return json.dumps({
            "headline": "Holdings Update Available",
            "what_changed": ["Position changes detected - API not configured for detailed analysis"],
            "top_buys": [],
            "top_sells": [],
            "observations": ["Data available for review"],
            "interpretation_notes": [],
            "limitations": "AI summary unavailable - API key not configured.",
            "disclaimer": disclaimer,
        })


# =============================================================================
# GEMINI 3 MULTIMODAL ANALYSIS (Hackathon Feature)
# =============================================================================

MULTIMODAL_CHART_PROMPT = """Analyze the provided chart image and respond in JSON format with chart_type, key_observations, notable_patterns, data_points_identified, limitations, and disclaimer. Respond ONLY with valid JSON."""

MULTIMODAL_DOCUMENT_PROMPT = """Analyze the provided document image and respond in JSON format with document_type, key_information, holdings_mentioned, dates_referenced, numerical_data, extraction_confidence, limitations, and disclaimer. Respond ONLY with valid JSON."""


async def analyze_chart_with_gemini(
    image_data: bytes,
    mime_type: str = "image/png",
    additional_context: Optional[str] = None,
) -> dict:
    """
    Analyze a financial chart using Gemini 3's multimodal capabilities.

    This is a key Gemini 3 Hackathon feature - leveraging multimodal AI
    to extract insights from visual financial data.

    Args:
        image_data: Raw image bytes
        mime_type: MIME type of the image (e.g., "image/png", "image/jpeg")
        additional_context: Optional context about the chart

    Returns:
        Dictionary with chart analysis results
    """
    if not gemini_model:
        logger.warning("Gemini not configured - multimodal analysis unavailable")
        return {
            "error": "Gemini 3 not configured",
            "chart_type": "unknown",
            "key_observations": ["Multimodal analysis requires Gemini 3 API key"],
            "disclaimer": "This is not investment advice.",
        }

    try:
        # Prepare the multimodal prompt
        prompt = MULTIMODAL_CHART_PROMPT
        if additional_context:
            prompt = f"Context: {additional_context}\n\n{prompt}"

        # Create image part for Gemini
        image_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(image_data).decode("utf-8"),
        }

        # Call Gemini 3 with multimodal input
        response = await gemini_model.generate_content_async(
            [prompt, image_part],
            generation_config=genai.GenerationConfig(
                temperature=0.1,  # Lower for factual extraction
                max_output_tokens=1500,
            ),
        )

        # Parse JSON response
        result = json.loads(response.text)
        return result

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Gemini chart analysis: {e}")
        return {
            "error": "Failed to parse analysis",
            "raw_response": response.text if response else None,
            "disclaimer": "This is not investment advice.",
        }
    except Exception as e:
        logger.error(f"Gemini multimodal analysis failed: {e}")
        return {
            "error": str(e),
            "chart_type": "analysis_failed",
            "disclaimer": "This is not investment advice.",
        }


async def analyze_document_with_gemini(
    image_data: bytes,
    mime_type: str = "image/png",
    document_type_hint: Optional[str] = None,
) -> dict:
    """
    Extract information from financial documents using Gemini 3's vision.

    This enables analysis of:
    - SEC 13F filing screenshots
    - Annual reports
    - Earnings releases
    - Prospectus pages

    Args:
        image_data: Raw image bytes of the document
        mime_type: MIME type of the image
        document_type_hint: Optional hint about document type

    Returns:
        Dictionary with extracted document information
    """
    if not gemini_model:
        logger.warning("Gemini not configured - document analysis unavailable")
        return {
            "error": "Gemini 3 not configured",
            "document_type": "unknown",
            "key_information": ["Document analysis requires Gemini 3 API key"],
            "disclaimer": "This is not investment advice.",
        }

    try:
        prompt = MULTIMODAL_DOCUMENT_PROMPT
        if document_type_hint:
            prompt = f"Document type hint: {document_type_hint}\n\n{prompt}"

        image_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(image_data).decode("utf-8"),
        }

        response = await gemini_model.generate_content_async(
            [prompt, image_part],
            generation_config=genai.GenerationConfig(
                temperature=0.1,
                max_output_tokens=8000,
            ),
        )

        result = json.loads(response.text)
        return result

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Gemini document analysis: {e}")
        return {
            "error": "Failed to parse analysis",
            "raw_response": response.text if response else None,
            "disclaimer": "This is not investment advice.",
        }
    except Exception as e:
        logger.error(f"Gemini document analysis failed: {e}")
        return {
            "error": str(e),
            "document_type": "analysis_failed",
            "disclaimer": "This is not investment advice.",
        }


async def compare_holdings_visually(
    chart1_data: bytes,
    chart2_data: bytes,
    mime_type: str = "image/png",
    comparison_context: Optional[str] = None,
) -> dict:
    """
    Compare two holdings charts/visualizations using Gemini 3 multimodal.

    Useful for comparing:
    - Before/after portfolio allocations
    - Period-over-period changes
    - Different investor allocations

    Args:
        chart1_data: First chart image bytes
        chart2_data: Second chart image bytes
        mime_type: MIME type for both images
        comparison_context: Context about what's being compared

    Returns:
        Dictionary with comparison analysis
    """
    if not gemini_model:
        return {
            "error": "Gemini 3 not configured",
            "disclaimer": "This is not investment advice.",
        }

    comparison_prompt = f"""Provide comparison analysis of two chart visualizations in JSON format with chart1_summary, chart2_summary, key_differences, similarities, notable_changes, comparison_confidence, limitations, and disclaimer. Respond ONLY with valid JSON."""

    try:
        image1_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(chart1_data).decode("utf-8"),
        }
        image2_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(chart2_data).decode("utf-8"),
        }

        response = await gemini_model.generate_content_async(
            [comparison_prompt, image1_part, image2_part],
            generation_config=genai.GenerationConfig(
                temperature=0.1,
                max_output_tokens=8000,
            ),
        )

        return json.loads(response.text)

    except Exception as e:
        logger.error(f"Gemini comparison analysis failed: {e}")
        return {
            "error": str(e),
            "disclaimer": "This is not investment advice.",
        }


# =============================================================================
# GEMINI 3 ENHANCED REASONING (Hackathon Feature)
# =============================================================================

async def generate_deep_analysis_with_reasoning(
    investor: Investor,
    changes: list[HoldingsChange],
    include_thinking: bool = True,
) -> dict:
    """
    Generate deep analysis using Gemini 3's enhanced reasoning capabilities.

    This leverages Gemini 3's advanced reasoning to provide:
    - Multi-step analysis of holdings patterns
    - Cross-sector correlation detection
    - Thematic investment identification

    Note: This is a Hackathon feature showcasing Gemini 3's reasoning.
    """
    if not gemini_model:
        return {
            "error": "Gemini 3 not configured",
            "disclaimer": "This is not investment advice.",
        }

    disclosure_context = get_disclosure_context(investor)
    evidence_builder = build_evidence_for_summary(investor, changes, disclosure_context)

    reasoning_prompt = f"""Provide analysis of investor holdings in JSON format with sector_analysis, pattern_analysis, thematic_connections, synthesis, reasoning_steps, unknowns, and disclaimer. Respond ONLY with valid JSON."""

    try:
        response = await gemini_model.generate_content_async(
            reasoning_prompt,
            generation_config=genai.GenerationConfig(
                temperature=0.3,  # Slightly higher for reasoning
                max_output_tokens=3000,
            ),
        )

        # Extract JSON from response (may include thinking text)
        response_text = response.text
        json_start = response_text.find("{")
        json_end = response_text.rfind("}") + 1

        if json_start != -1 and json_end > json_start:
            json_str = response_text[json_start:json_end]
            result = json.loads(json_str)

            # Include reasoning trace if present
            if include_thinking and json_start > 0:
                result["reasoning_trace"] = response_text[:json_start].strip()

            return result
        else:
            return {
                "error": "Could not extract JSON from response",
                "raw_response": response_text,
                "disclaimer": "This is not investment advice.",
            }

    except Exception as e:
        logger.error(f"Gemini deep analysis failed: {e}")
        return {
            "error": str(e),
            "disclaimer": "This is not investment advice.",
        }
