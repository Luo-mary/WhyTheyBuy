"""
Multi-Agent Reasoning Service - Professional 6-Perspective Sequential Analysis.

Inspired by TradingAgents paper architecture, adapted for educational
analysis of WHY an investor may have made a portfolio change.

SEQUENTIAL ANALYSIS FLOW:
1. Fundamental Analysis - Foundation metrics
2. News & Sentiment - Recent news context
3. Market Context - Sector and macro (references 1,2)
4. Technical Analysis - Price patterns (references 1,2,3)
5. Investment Debate - Bull vs Bear (references ALL above)
6. Risk Assessment - Overall risk synthesis (references ALL above)

KEY IMPROVEMENTS:
- Sequential reasoning where each agent builds on previous analyses
- Professional analysis with specific metrics and figures
- Clickable evidence links to sources
- Bull vs Bear debate with integrated verdict
- Risk assessment with clear "no advice" disclaimers
- Comprehensive compliance disclaimers

COMPLIANCE:
- All analysis is HYPOTHETICAL and for educational purposes only
- NO buy/sell recommendations or investment advice
- NO predictions of future price movements
- Confidence is capped at "medium" (never "high")
- Mandatory disclaimers on each perspective card
- Risk assessment explicitly states NO investment advice

LOCALIZATION:
- Supports multiple languages for AI responses
- Language is passed from frontend via Accept-Language header
"""

import asyncio
import json
import logging
import re
from datetime import datetime
from typing import Optional, List

import google.generativeai as genai
from app.config import settings
from app.schemas.reasoning import (
    MultiAgentReasoningResponse,
    ReasoningCard,
    ReasoningPerspective,
    EvidenceLink,
    PERSPECTIVE_METADATA,
    PERSPECTIVE_PROMPTS,
    _get_perspective_disclaimer,
)
from app.services.cusip_lookup import lookup_ticker_from_cusip, get_ticker_from_cusip_sync
from app.services.language import (
    get_language_instruction,
    get_language_name,
    normalize_language_code,
    DEFAULT_LANGUAGE,
)

logger = logging.getLogger(__name__)


# =============================================================================
# CUSIP DETECTION AND RESOLUTION
# =============================================================================

def _is_likely_cusip(value: str) -> bool:
    """Check if a value looks like a CUSIP (9 alphanumeric chars, mostly digits)."""
    if not value or len(value) < 6:
        return False
    cleaned = value.strip().replace("-", "").replace(" ", "")
    if len(cleaned) >= 6 and len(cleaned) <= 9:
        digit_count = sum(1 for c in cleaned if c.isdigit())
        if digit_count >= 5:
            return True
    return False


async def _resolve_ticker(ticker: str, company_name: Optional[str] = None) -> str:
    """Resolve a ticker, converting CUSIP to actual ticker if needed."""
    if not ticker:
        return ticker

    if _is_likely_cusip(ticker):
        resolved = await lookup_ticker_from_cusip(ticker, company_name)
        if resolved:
            return resolved
        cached = get_ticker_from_cusip_sync(ticker)
        if cached:
            return cached

    return ticker


# =============================================================================
# SYSTEM INSTRUCTION FOR PROFESSIONAL MULTI-AGENT REASONING
# =============================================================================

MULTI_AGENT_SYSTEM_INSTRUCTION = """You are a team of senior financial analysts at a top-tier investment research firm providing professional-grade SEQUENTIAL multi-perspective analysis.

SEQUENTIAL ANALYSIS FLOW - Each agent MUST reference previous analyses:
1. FUNDAMENTAL (first) - Establishes the financial foundation
2. NEWS_SENTIMENT (second) - Adds recent news context
3. MARKET_CONTEXT (third) - References fundamentals and news
4. TECHNICAL (fourth) - References all above
5. BULL_VS_BEAR (fifth) - References ALL previous 4 analyses in the debate
6. RISK_ASSESSMENT (sixth) - Synthesizes risks from ALL 5 previous analyses

CRITICAL COMPLIANCE RULES:
1. This is HYPOTHETICAL analysis - you do NOT know the investor's actual reasoning
2. NEVER recommend buying, selling, or holding any security
3. NEVER predict future price movements or investment outcomes
4. Use professional language with SPECIFIC METRICS AND FIGURES
5. Every claim must be supported by evidence with source URLs
6. Confidence level must be "low" or "medium" only - NEVER "high"
7. The RISK_ASSESSMENT must explicitly state "This is NOT investment advice"

QUALITY STANDARDS:
- Include specific numbers: P/E ratios, revenue figures, growth percentages, price levels
- Reference actual market data, not vague generalizations
- Provide evidence links to SEC filings, news articles, financial data sources
- Write like a senior analyst presenting to institutional clients
- Later analyses MUST cross-reference earlier analyses by name

You must return a valid JSON object with exactly 6 perspective cards in sequential order.

REQUIRED JSON STRUCTURE:
{
  "activity_summary": "Professional summary with key figures (e.g., 'Disclosed new position of X shares valued at $X.XB')",
  "cards": [
    {
      "perspective": "fundamental",
      "key_points": [
        "P/E ratio of X.X compares to sector median of X.X, suggesting...",
        "Revenue of $X.XB in Q3 2024 represents X.X% YoY growth...",
        "Debt-to-equity ratio of X.X indicates..."
      ],
      "evidence": [
        {"title": "Yahoo Finance: Company Profile", "url": "https://finance.yahoo.com/quote/{TICKER}", "source_type": "financial_data"},
        {"title": "SEC EDGAR Filings", "url": "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={TICKER}&type=&dateb=&owner=include&count=40", "source_type": "sec_filing"}
      ],
      "confidence": "low"
    },
    {
      "perspective": "news_sentiment",
      "key_points": [
        "Recent earnings coverage has been predominantly positive/negative...",
        "Analyst upgrades/downgrades in the past 30 days...",
        "Industry news affecting {TICKER}..."
      ],
      "news_sentiment": "POSITIVE",
      "news_summary": "Recent coverage focuses on strong quarterly results and market share gains. Analysts have raised price targets following the earnings beat.",
      "news_sources": ["Yahoo Finance", "MarketWatch", "Reuters"],
      "evidence": [
        {"title": "Yahoo Finance: News", "url": "https://finance.yahoo.com/quote/{TICKER}/news", "source_type": "news"},
        {"title": "Google Finance: News", "url": "https://www.google.com/finance/quote/{TICKER}:NASDAQ", "source_type": "news"}
      ],
      "confidence": "low"
    },
    {
      "perspective": "market_context",
      "key_points": [
        "Sector has returned X.X% YTD vs S&P 500's X.X%...",
        "Building on the fundamental P/E of X.X noted above, peers trade at...",
        "News sentiment (POSITIVE/NEGATIVE) aligns with sector momentum..."
      ],
      "evidence": [
        {"title": "Yahoo Finance: Stock Analysis", "url": "https://finance.yahoo.com/quote/{TICKER}/analysis", "source_type": "financial_data"},
        {"title": "MarketWatch: Stock Overview", "url": "https://www.marketwatch.com/investing/stock/{TICKER}", "source_type": "financial_data"}
      ],
      "confidence": "low"
    },
    {
      "perspective": "technical",
      "key_points": [
        "Trading at $XX.XX, X.X% below 52-week high of $XX.XX...",
        "Volume patterns align with the news sentiment noted above...",
        "Price action reflects the fundamental valuation discussed earlier..."
      ],
      "evidence": [
        {"title": "Yahoo Finance: Chart & Technicals", "url": "https://finance.yahoo.com/quote/{TICKER}", "source_type": "financial_data"}
      ],
      "confidence": "low"
    },
    {
      "perspective": "bull_vs_bear",
      "key_points": ["Key debate centers on valuation vs growth potential, referencing all prior analyses..."],
      "bull_points": [
        "Bullish Arg 1: Fundamental Analysis shows revenue growth of X.X% exceeding industry...",
        "Bullish Arg 2: News Sentiment is POSITIVE with analyst upgrades...",
        "Bullish Arg 3: Technical Analysis shows support at $XX.XX with strong volume..."
      ],
      "bear_points": [
        "Bearish Arg 1: Fundamental Analysis reveals margin compression of X.X bps...",
        "Bearish Arg 2: Market Context shows peer valuations X% lower...",
        "Bearish Arg 3: Technical Analysis indicates resistance at $XX.XX..."
      ],
      "verdict": "BULLISH",
      "verdict_reasoning": "Synthesizing all analyses: Fundamentals show solid P/E of X.X, News Sentiment is POSITIVE, Market Context indicates sector tailwinds, and Technical support at $XX.XX. Key risks from bearish case warrant monitoring.",
      "evidence": [
        {"title": "Yahoo Finance: Financials", "url": "https://finance.yahoo.com/quote/{TICKER}/financials", "source_type": "financial_data"}
      ],
      "confidence": "medium"
    },
    {
      "perspective": "risk_assessment",
      "key_points": [
        "Synthesizing all 5 previous analyses to assess overall risk profile...",
        "Key uncertainties remain around investor intent and execution prices...",
        "This assessment is for EDUCATIONAL purposes only - NOT investment advice"
      ],
      "risk_level": "MODERATE",
      "risk_summary": "Based on Fundamental Analysis (debt ratio X.X), News Sentiment (POSITIVE but volatile), Market Context (sector headwinds), Technical Analysis (near resistance), and Investment Debate concerns - overall risk is assessed as MODERATE. This is NOT a recommendation.",
      "risk_factors": [
        "From Fundamental Analysis: Elevated debt-to-equity of X.X vs sector average of X.X",
        "From News Sentiment: Recent coverage is POSITIVE but sentiment can shift rapidly",
        "From Market Context: Sector faces headwinds from rising interest rates",
        "From Technical Analysis: Price approaching resistance at $XX.XX with declining volume",
        "From Investment Debate: Bearish concerns about margin pressure remain valid"
      ],
      "evidence": [
        {"title": "Yahoo Finance: Risk Analysis", "url": "https://finance.yahoo.com/quote/{TICKER}", "source_type": "financial_data"}
      ],
      "confidence": "low"
    }
  ]
}

CRITICAL EVIDENCE URL RULES - USE ONLY THESE EXACT PATTERNS:
You MUST ONLY use these verified URL templates. Do NOT make up or hallucinate URLs.
Replace {TICKER} with the actual stock ticker (e.g., KHC, AAPL, MSFT).

ALLOWED URLs (use ONLY these - they are guaranteed to work):
1. Yahoo Finance Quote: https://finance.yahoo.com/quote/{TICKER}
   Example: https://finance.yahoo.com/quote/KHC

2. Yahoo Finance Financials: https://finance.yahoo.com/quote/{TICKER}/financials
   Example: https://finance.yahoo.com/quote/KHC/financials

3. Yahoo Finance Analysis: https://finance.yahoo.com/quote/{TICKER}/analysis
   Example: https://finance.yahoo.com/quote/KHC/analysis

4. SEC EDGAR Company Search: https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={TICKER}&type=&dateb=&owner=include&count=40
   Example: https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=KHC&type=10-K&dateb=&owner=include&count=40

5. MarketWatch: https://www.marketwatch.com/investing/stock/{TICKER}
   Example: https://www.marketwatch.com/investing/stock/khc

6. Google Finance: https://www.google.com/finance/quote/{TICKER}:NASDAQ or https://www.google.com/finance/quote/{TICKER}:NYSE
   Example: https://www.google.com/finance/quote/KHC:NASDAQ

DO NOT create URLs to specific documents, filings, or news articles - they will be broken.
ONLY use the general page URLs listed above that are guaranteed to exist.

PERSPECTIVE GUIDELINES (SEQUENTIAL - each builds on previous):

1. FUNDAMENTAL (First - Foundation): Act as a Senior Equity Research Analyst
   - Include: P/E, EPS, revenue, margins, debt ratios, valuation metrics
   - Compare to historical averages and sector peers with specific numbers
   - Reference earnings reports and SEC filings
   - This establishes the financial foundation for all subsequent analyses

2. NEWS_SENTIMENT (Second): Act as a Senior Media Analyst
   - Analyze recent news coverage and market sentiment
   - Include: news_sentiment (POSITIVE, NEGATIVE, MIXED, NEUTRAL)
   - Include: news_summary (2-3 sentences of key themes)
   - Include: news_sources (list of outlets covering this stock)
   - This provides context for Market and Technical analyses

3. MARKET_CONTEXT (Third - References 1,2): Act as a Senior Market Strategist
   - Include: Sector performance vs benchmarks, peer comparison, macro factors
   - MUST reference fundamental metrics from step 1
   - MUST reference news sentiment from step 2
   - Cite market research and news sources

4. TECHNICAL (Fourth - References 1,2,3): Act as a Certified Market Technician
   - Include: Price levels, moving averages, support/resistance, volume, RSI
   - MUST connect price action to fundamentals and news
   - Note: Technical patterns are OBSERVATIONAL and do NOT predict future moves
   - Reference specific price points and percentages

5. BULL_VS_BEAR (Fifth - References ALL): Act as Chief Investment Officer
   - Present 3-4 compelling arguments for each side with data
   - EACH argument MUST reference a specific finding from analyses 1-4
   - Bull points should cite positive findings from prior analyses
   - Bear points should cite concerns from prior analyses
   - MUST include verdict (BULLISH, BEARISH, or NEUTRAL) with reasoning
   - Verdict reasoning MUST synthesize ALL prior analyses
   - Confidence is MEDIUM at most, never HIGH

6. RISK_ASSESSMENT (Sixth - Synthesizes ALL): Act as a Senior Risk Manager
   - MUST synthesize risks from ALL 5 previous analyses
   - Include: risk_level (LOW, MODERATE, HIGH, VERY_HIGH)
   - Include: risk_summary (2-3 sentences synthesizing the risk picture)
   - Include: risk_factors (list of 4-5 factors, each citing which analysis it came from)
   - CRITICAL: This is NOT investment advice - state this explicitly
   - Focus on DESCRIBING risks, not recommending actions
   - Confidence is always LOW for risk assessment
"""


# =============================================================================
# JSON CLEANING
# =============================================================================

def clean_json_text(text: str) -> str:
    """Extract and repair JSON from LLM output that may have markdown wrappers."""
    start_idx = text.find("{")
    if start_idx == -1:
        return text.strip()

    end_idx = text.rfind("}")
    if end_idx == -1:
        cleaned = text[start_idx:]
    else:
        cleaned = text[start_idx : end_idx + 1]

    # Remove markdown code blocks
    cleaned = re.sub(r"```json\s*", "", cleaned)
    cleaned = re.sub(r"```", "", cleaned)
    cleaned = cleaned.strip()

    # Structural repair for unclosed brackets
    open_braces = cleaned.count("{") - cleaned.count("}")
    open_brackets = cleaned.count("[") - cleaned.count("]")
    if open_brackets > 0:
        cleaned += "]" * open_brackets
    if open_braces > 0:
        cleaned += "}" * open_braces

    return cleaned


# =============================================================================
# CORE GEMINI CALL
# =============================================================================

async def call_gemini_multi_agent(query: str, language: str = DEFAULT_LANGUAGE) -> str:
    """
    Call Gemini API for multi-agent perspective analysis.

    Args:
        query: The analysis request with context
        language: ISO 639-1 language code for response language (e.g., "en", "zh")

    Returns:
        Raw JSON response text from Gemini

    Raises:
        RuntimeError: If GEMINI_API_KEY is not set
    """
    import time

    if not settings.gemini_api_key:
        logger.error("       [GEMINI] API key not configured!")
        raise RuntimeError("GEMINI_API_KEY is not set.")

    logger.info("       [GEMINI] Configuring Gemini API...")
    genai.configure(api_key=settings.gemini_api_key)

    # Build system instruction with language support
    system_instruction = MULTI_AGENT_SYSTEM_INSTRUCTION
    language_instruction = get_language_instruction(language)
    if language_instruction:
        system_instruction = f"{MULTI_AGENT_SYSTEM_INSTRUCTION}\n\n{language_instruction}"
        logger.info(f"       [GEMINI] Generating response in {get_language_name(language)}")

    model = genai.GenerativeModel(
        model_name="models/gemini-3-flash-preview",
        system_instruction=system_instruction,
        generation_config=genai.GenerationConfig(
            response_mime_type="application/json",
            max_output_tokens=12000,  # Larger for detailed professional analysis
            temperature=0.4,  # Slightly higher for nuanced perspectives
        ),
    )

    logger.info("       [GEMINI] Sending request to gemini-3-flash-preview...")
    logger.info(f"       [GEMINI] Query length: {len(query)} chars")

    # Run in thread pool for async compatibility
    start_time = time.time()
    response = await asyncio.to_thread(
        model.generate_content,
        query,
    )
    duration = time.time() - start_time

    response_len = len(response.text) if response.text else 0
    logger.info(f"       [GEMINI] Response received in {duration:.2f}s")
    logger.info(f"       [GEMINI] Response length: {response_len} chars")

    return response.text


# =============================================================================
# CARD BUILDER
# =============================================================================

def build_reasoning_card(
    perspective: ReasoningPerspective,
    raw_card: dict,
) -> ReasoningCard:
    """
    Build a ReasoningCard from raw Gemini output.

    Applies metadata from PERSPECTIVE_METADATA and generates disclaimers.
    Enforces compliance constraints on confidence level.
    """
    metadata = PERSPECTIVE_METADATA[perspective]

    # Extract key_points, ensure 3-6 items
    key_points = raw_card.get("key_points", [])
    if len(key_points) < 3:
        key_points = key_points + ["Analysis pending - insufficient data available"] * (3 - len(key_points))
    elif len(key_points) > 6:
        key_points = key_points[:6]

    # Extract evidence links
    raw_evidence = raw_card.get("evidence", [])
    evidence = []
    for e in raw_evidence:
        if isinstance(e, dict):
            evidence.append(EvidenceLink(
                title=e.get("title", "Source"),
                url=e.get("url", "#"),
                source_type=e.get("source_type", "web"),
            ))
        elif isinstance(e, str):
            # Legacy format - convert string to EvidenceLink
            evidence.append(EvidenceLink(
                title=e,
                url="#",
                source_type="web",
            ))

    # Enforce confidence cap - never allow "high"
    confidence = raw_card.get("confidence", "low")
    if confidence.lower() == "high":
        confidence = "medium"
    elif confidence.lower() not in ["low", "medium"]:
        confidence = "low"

    # Get perspective-specific disclaimer
    disclaimer = _get_perspective_disclaimer(perspective)

    # Handle bull_vs_bear specific fields (now includes verdict)
    bull_points = raw_card.get("bull_points")
    bear_points = raw_card.get("bear_points")

    # Handle verdict fields (now part of bull_vs_bear card)
    verdict = raw_card.get("verdict")
    verdict_reasoning = raw_card.get("verdict_reasoning")

    # Handle news_sentiment specific fields
    news_sentiment = raw_card.get("news_sentiment")
    news_summary = raw_card.get("news_summary")
    news_sources = raw_card.get("news_sources")

    # Handle risk_assessment specific fields
    risk_level = raw_card.get("risk_level")
    risk_factors = raw_card.get("risk_factors")
    risk_summary = raw_card.get("risk_summary")

    return ReasoningCard(
        perspective=perspective,
        title=metadata["title"],
        icon=metadata["icon"],
        accent_color=metadata["accent_color"],
        key_points=key_points,
        evidence=evidence,
        confidence=confidence,
        disclaimer=disclaimer,
        bull_points=bull_points,
        bear_points=bear_points,
        verdict=verdict,
        verdict_reasoning=verdict_reasoning,
        news_sentiment=news_sentiment,
        news_summary=news_summary,
        news_sources=news_sources,
        risk_level=risk_level,
        risk_factors=risk_factors,
        risk_summary=risk_summary,
    )


# =============================================================================
# MAIN GENERATION FUNCTION
# =============================================================================

async def generate_multi_agent_reasoning(
    investor_name: str,
    ticker: str,
    company_name: str,
    change_type: str,
    shares_delta: Optional[str] = None,
    value_delta: Optional[str] = None,
    additional_context: Optional[str] = None,
    language: str = DEFAULT_LANGUAGE,
) -> MultiAgentReasoningResponse:
    """
    Generate professional sequential multi-agent reasoning analysis for a portfolio change.

    This function calls Gemini to generate 6 SEQUENTIAL perspective analyses:
    1. Fundamental Analysis (foundation)
    2. News & Sentiment (context)
    3. Market Context (references 1,2)
    4. Technical Analysis (references 1,2,3)
    5. Investment Debate (references ALL above)
    6. Risk Assessment (synthesizes ALL above)

    COMPLIANCE:
    - All content is hypothetical and educational only
    - No investment recommendations
    - Confidence capped at "medium"
    - Risk assessment explicitly states "NOT investment advice"

    Args:
        investor_name: Name of the investor/fund
        ticker: Stock ticker symbol (or CUSIP, which will be resolved)
        company_name: Company name
        change_type: Type of change (NEW, ADDED, REDUCED, SOLD_OUT)
        shares_delta: Optional string describing share change
        value_delta: Optional string describing value change
        additional_context: Optional additional context
        language: ISO 639-1 language code for response language (e.g., "en", "zh")

    Returns:
        MultiAgentReasoningResponse with 6 perspective cards in sequential order

    Raises:
        RuntimeError: If Gemini API key not configured
        json.JSONDecodeError: If Gemini response is malformed
    """
    # Resolve CUSIP to ticker if needed (13F filings use CUSIPs)
    original_ticker = ticker
    resolved_ticker = await _resolve_ticker(ticker, company_name)

    if resolved_ticker != original_ticker:
        logger.info(f"Resolved CUSIP {original_ticker} -> {resolved_ticker}")

    # Use resolved ticker for display but keep original for reference
    display_ticker = resolved_ticker

    # Build the query with context
    context_parts = [
        f"Investor: {investor_name}",
        f"Stock: {display_ticker} ({company_name})",
        f"Action: {change_type}",
    ]

    if shares_delta:
        context_parts.append(f"Share Change: {shares_delta}")
    if value_delta:
        context_parts.append(f"Value Change: {value_delta}")
    if additional_context:
        context_parts.append(f"Additional Context: {additional_context}")

    query = f"""
Analyze this disclosed portfolio change with PROFESSIONAL-GRADE SEQUENTIAL analysis:

{chr(10).join(context_parts)}

REQUIREMENTS:
1. Include SPECIFIC NUMBERS and METRICS in every analysis point
2. Provide CLICKABLE EVIDENCE LINKS to real sources (SEC filings, news, financial data)
3. Write like a senior analyst at Goldman Sachs or Morgan Stanley
4. Each analysis MUST reference and build upon previous analyses
5. The Bull vs Bear debate must reference findings from ALL previous 4 analyses
6. The Risk Assessment must synthesize risks from ALL 5 previous analyses
7. Risk Assessment must clearly state this is NOT investment advice

Provide 6 SEQUENTIAL analyses in this exact order:
1. fundamental (foundation)
2. news_sentiment (adds news context)
3. market_context (references 1,2)
4. technical (references 1,2,3)
5. bull_vs_bear (references ALL above, includes verdict)
6. risk_assessment (synthesizes ALL above, NOT investment advice)

Remember: This is HYPOTHETICAL analysis. We do NOT know the investor's actual reasoning.
"""

    logger.info(f"Generating professional multi-agent reasoning for {ticker} ({investor_name})")
    if language != DEFAULT_LANGUAGE:
        logger.info(f"Response language: {get_language_name(language)}")

    # Call Gemini with language support
    response_text = await call_gemini_multi_agent(query, language=language)

    logger.debug(f"Raw Gemini response for {ticker}: {response_text[:500]}...")

    # Clean and parse JSON
    cleaned = clean_json_text(response_text)
    result = json.loads(cleaned)

    # Handle array response
    if isinstance(result, list):
        result = result[0] if result else {}

    # Extract activity summary
    activity_summary = result.get(
        "activity_summary",
        f"{investor_name} disclosed a {change_type.lower()} position in {display_ticker} ({company_name})."
    )

    # Build cards from response
    raw_cards = result.get("cards", [])

    # Map raw cards to perspectives (SEQUENTIAL ORDER)
    perspective_order = [
        ReasoningPerspective.FUNDAMENTAL,      # 1st: Foundation
        ReasoningPerspective.NEWS_SENTIMENT,   # 2nd: News context
        ReasoningPerspective.MARKET_CONTEXT,   # 3rd: References 1,2
        ReasoningPerspective.TECHNICAL,        # 4th: References 1,2,3
        ReasoningPerspective.BULL_VS_BEAR,     # 5th: References ALL above
        ReasoningPerspective.RISK_ASSESSMENT,  # 6th: Synthesizes ALL
    ]

    cards = []

    # Try to match cards by perspective name first
    cards_by_perspective = {}
    for raw_card in raw_cards:
        perspective_str = raw_card.get("perspective", "").lower()
        try:
            perspective = ReasoningPerspective(perspective_str)
            cards_by_perspective[perspective] = raw_card
        except ValueError:
            continue

    # Build cards in order, using matched or generating fallback
    for perspective in perspective_order:
        if perspective in cards_by_perspective:
            card = build_reasoning_card(perspective, cards_by_perspective[perspective])
        else:
            # Generate fallback card
            fallback_data = {
                "key_points": [
                    "Analysis data not available for this perspective",
                    "Unable to generate detailed metrics at this time",
                    "Please try again later for complete analysis",
                ],
                "evidence": [],
                "confidence": "low",
            }
            if perspective == ReasoningPerspective.BULL_VS_BEAR:
                fallback_data["bull_points"] = ["Bullish analysis pending"]
                fallback_data["bear_points"] = ["Bearish analysis pending"]
                fallback_data["verdict"] = "NEUTRAL"
                fallback_data["verdict_reasoning"] = "Insufficient data to render a verdict."
            if perspective == ReasoningPerspective.NEWS_SENTIMENT:
                fallback_data["news_sentiment"] = "NEUTRAL"
                fallback_data["news_summary"] = "News analysis not available at this time."
                fallback_data["news_sources"] = []
            if perspective == ReasoningPerspective.RISK_ASSESSMENT:
                fallback_data["risk_level"] = "MODERATE"
                fallback_data["risk_summary"] = "Risk assessment not available at this time. This is NOT investment advice."
                fallback_data["risk_factors"] = [
                    "Insufficient data to complete risk analysis",
                    "Please try again for complete assessment",
                ]

            card = build_reasoning_card(perspective, fallback_data)
        cards.append(card)

    # Build response (use resolved ticker for better display)
    response = MultiAgentReasoningResponse(
        ticker=display_ticker,
        company_name=company_name,
        investor_name=investor_name,
        change_type=change_type,
        activity_summary=activity_summary,
        cards=cards,
        generated_at=datetime.utcnow(),
    )

    logger.info(f"Successfully generated professional multi-agent reasoning for {display_ticker}")

    return response


# =============================================================================
# SIMPLIFIED HELPER FOR API ENDPOINT
# =============================================================================

async def get_multi_agent_reasoning_for_change(
    investor_name: str,
    ticker: str,
    company_name: str,
    change_type: str,
    shares_change: Optional[int] = None,
    value_change: Optional[float] = None,
    language: str = DEFAULT_LANGUAGE,
) -> MultiAgentReasoningResponse:
    """
    Simplified helper for API endpoint.

    Formats share/value changes and calls the main generation function.

    Args:
        investor_name: Name of the investor/fund
        ticker: Stock ticker symbol
        company_name: Company name
        change_type: Type of change
        shares_change: Number of shares changed
        value_change: Value of position change
        language: ISO 639-1 language code for response language (e.g., "en", "zh")
    """
    shares_delta = None
    if shares_change is not None:
        direction = "increased" if shares_change > 0 else "decreased"
        shares_delta = f"{direction} by {abs(shares_change):,} shares"

    value_delta = None
    if value_change is not None:
        direction = "increased" if value_change > 0 else "decreased"
        # Format large numbers nicely
        abs_value = abs(value_change)
        if abs_value >= 1_000_000_000:
            value_str = f"${abs_value / 1_000_000_000:.2f}B"
        elif abs_value >= 1_000_000:
            value_str = f"${abs_value / 1_000_000:.2f}M"
        else:
            value_str = f"${abs_value:,.0f}"
        value_delta = f"{direction} by {value_str}"

    return await generate_multi_agent_reasoning(
        investor_name=investor_name,
        ticker=ticker,
        company_name=company_name,
        change_type=change_type,
        shares_delta=shares_delta,
        value_delta=value_delta,
        language=language,
    )
