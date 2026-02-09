"""
Reasoning schemas - Multi-Agent Analysis with Professional Quality.

Multi-Agent Reasoning inspired by TradingAgents paper architecture,
adapted for educational analysis of WHY an investor may have made a change.

DESIGN PRINCIPLES:
- Professional: Analysis includes specific metrics, figures, and data points
- Evidence-based: All claims backed by clickable source links
- Balanced: Bull vs Bear debate with Facilitator verdict
- Compliant: Clear disclaimers on every card
- Honest: Only "low" or "medium" confidence, never "high"
"""
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field, field_validator
import enum


# =============================================================================
# MULTI-AGENT REASONING PERSPECTIVES (6 Agents - Sequential)
# =============================================================================

class ReasoningPerspective(str, enum.Enum):
    """
    6 analysis perspectives for professional-grade sequential reasoning.

    ORDER MATTERS - Each agent builds on previous analyses:
    1. Fundamental Analysis - Foundation of financial metrics
    2. News & Sentiment - Recent news context
    3. Market Context - Sector and macro environment
    4. Technical Analysis - Price action patterns
    5. Investment Debate - Bull vs Bear referencing ALL above
    6. Risk Assessment - Overall risk synthesis (NO investment advice)
    """
    FUNDAMENTAL = "fundamental"       # 1st: Financial metrics, earnings, valuation
    NEWS_SENTIMENT = "news_sentiment" # 2nd: Recent news and sentiment analysis
    MARKET_CONTEXT = "market_context" # 3rd: Sector trends, macro, peer comparison
    TECHNICAL = "technical"           # 4th: Price action, volume, technical patterns
    BULL_VS_BEAR = "bull_vs_bear"     # 5th: Bull/Bear debate WITH Final Verdict
    RISK_ASSESSMENT = "risk_assessment" # 6th: Overall risk synthesis


# Perspective metadata for UI (ordered by sequential flow)
PERSPECTIVE_METADATA = {
    ReasoningPerspective.FUNDAMENTAL: {
        "title": "Fundamental Analysis",
        "icon": "bar_chart",
        "accent_color": "#3B82F6",  # Blue
        "description": "Financial metrics, valuation, and company fundamentals",
        "order": 1,
    },
    ReasoningPerspective.NEWS_SENTIMENT: {
        "title": "News & Sentiment",
        "icon": "newspaper",
        "accent_color": "#EC4899",  # Pink
        "description": "Recent news coverage and market sentiment analysis",
        "order": 2,
    },
    ReasoningPerspective.MARKET_CONTEXT: {
        "title": "Market Context",
        "icon": "public",
        "accent_color": "#06B6D4",  # Cyan
        "description": "Sector trends, macro factors, and peer comparison",
        "order": 3,
    },
    ReasoningPerspective.TECHNICAL: {
        "title": "Technical Analysis",
        "icon": "show_chart",
        "accent_color": "#8B5CF6",  # Purple
        "description": "Price patterns, volume, and technical indicators",
        "order": 4,
    },
    ReasoningPerspective.BULL_VS_BEAR: {
        "title": "Investment Debate & Verdict",
        "icon": "gavel",
        "accent_color": "#F59E0B",  # Amber
        "description": "Bull vs Bear debate referencing all previous analyses",
        "order": 5,
    },
    ReasoningPerspective.RISK_ASSESSMENT: {
        "title": "Risk Assessment",
        "icon": "shield",
        "accent_color": "#EF4444",  # Red
        "description": "Overall risk factors - NOT investment advice",
        "order": 6,
    },
}


def _get_perspective_disclaimer(perspective: ReasoningPerspective) -> str:
    """Generate perspective-specific disclaimer."""
    base = "DISCLAIMER: This analysis is hypothetical and for educational purposes only. It does NOT constitute investment advice."

    perspective_notes = {
        ReasoningPerspective.FUNDAMENTAL: (
            f"{base} Financial metrics are based on publicly available data and may not reflect current conditions. "
            "Past performance does not guarantee future results."
        ),
        ReasoningPerspective.NEWS_SENTIMENT: (
            f"{base} News sentiment analysis is based on publicly available articles and may not reflect all relevant coverage. "
            "News sources may have biases and should not be the sole basis for investment decisions."
        ),
        ReasoningPerspective.MARKET_CONTEXT: (
            f"{base} Market conditions change rapidly. This context reflects a point-in-time snapshot and may already be outdated."
        ),
        ReasoningPerspective.TECHNICAL: (
            f"{base} Technical analysis patterns are observational and do NOT predict future price movements. "
            "No trading decisions should be based on this analysis."
        ),
        ReasoningPerspective.BULL_VS_BEAR: (
            f"{base} Both bullish and bearish arguments are hypothetical scenarios, not predictions. "
            "The verdict represents one possible interpretation among many. "
            "We do NOT know the investor's actual reasoning, execution prices, or future intentions."
        ),
        ReasoningPerspective.RISK_ASSESSMENT: (
            f"{base} This risk assessment is a synthesis of the analyses above and does NOT predict actual outcomes. "
            "Risk levels are subjective observations, NOT recommendations. "
            "We are NOT advising you to buy, sell, or hold any security. "
            "Consult a qualified financial advisor for personalized advice."
        ),
    }

    return perspective_notes.get(perspective, base)


# =============================================================================
# EVIDENCE LINK MODEL
# =============================================================================

class EvidenceLink(BaseModel):
    """A clickable evidence source with URL."""
    title: str = Field(description="Brief description of the evidence")
    url: str = Field(description="URL to the source document/news/data")
    source_type: str = Field(
        default="web",
        description="Type: sec_filing, news, financial_data, research, web"
    )


# =============================================================================
# REASONING CARD MODEL
# =============================================================================

class ReasoningCard(BaseModel):
    """
    Single perspective card for multi-agent display.

    Professional quality with specific metrics and clickable evidence.
    """
    perspective: ReasoningPerspective = Field(
        description="Which perspective this card represents"
    )
    title: str = Field(
        description="Display title (e.g., 'Fundamental Analysis')"
    )
    icon: str = Field(
        description="Flutter icon name (e.g., 'bar_chart', 'gavel')"
    )
    accent_color: str = Field(
        description="Hex color for card accent (e.g., '#3B82F6')"
    )
    key_points: List[str] = Field(
        min_length=2,
        max_length=6,
        description="3-6 bullet points with specific metrics and figures"
    )
    evidence: List[EvidenceLink] = Field(
        default_factory=list,
        description="Clickable source links for evidence"
    )
    confidence: Literal["low", "medium"] = Field(
        default="low",
        description="Confidence level - only 'low' or 'medium' allowed"
    )
    disclaimer: str = Field(
        description="Perspective-specific compliance disclaimer"
    )
    # For Bull vs Bear card (includes verdict)
    bull_points: Optional[List[str]] = Field(
        default=None,
        description="Bullish arguments (only for bull_vs_bear perspective)"
    )
    bear_points: Optional[List[str]] = Field(
        default=None,
        description="Bearish arguments (only for bull_vs_bear perspective)"
    )
    # Final Verdict (part of Bull vs Bear card)
    verdict: Optional[str] = Field(
        default=None,
        description="BULLISH, BEARISH, or NEUTRAL (part of bull_vs_bear card)"
    )
    verdict_reasoning: Optional[str] = Field(
        default=None,
        description="Detailed reasoning for the verdict"
    )
    # For News Sentiment card
    news_sentiment: Optional[str] = Field(
        default=None,
        description="Overall sentiment: POSITIVE, NEGATIVE, MIXED, or NEUTRAL"
    )
    news_summary: Optional[str] = Field(
        default=None,
        description="Brief summary of recent news coverage"
    )
    news_sources: Optional[List[str]] = Field(
        default=None,
        description="List of news source names referenced"
    )
    # For Risk Assessment card
    risk_level: Optional[str] = Field(
        default=None,
        description="Overall risk: LOW, MODERATE, HIGH, or VERY_HIGH"
    )
    risk_factors: Optional[List[str]] = Field(
        default=None,
        description="Key risk factors identified from all analyses"
    )
    risk_summary: Optional[str] = Field(
        default=None,
        description="Brief summary synthesizing risk from all perspectives"
    )

    @field_validator("confidence")
    @classmethod
    def validate_confidence(cls, v: str) -> str:
        """Enforce no high confidence claims."""
        if v.lower() == "high":
            raise ValueError(
                "High confidence is not allowed - "
                "we cannot know investor intent or future outcomes"
            )
        return v.lower()

    @classmethod
    def create_with_metadata(
        cls,
        perspective: ReasoningPerspective,
        key_points: List[str],
        evidence: List[EvidenceLink] | None = None,
        confidence: Literal["low", "medium"] = "low",
        bull_points: List[str] | None = None,
        bear_points: List[str] | None = None,
        verdict: str | None = None,
        verdict_reasoning: str | None = None,
        news_sentiment: str | None = None,
        news_summary: str | None = None,
        news_sources: List[str] | None = None,
        risk_level: str | None = None,
        risk_factors: List[str] | None = None,
        risk_summary: str | None = None,
    ) -> "ReasoningCard":
        """Factory method to create card with auto-filled metadata."""
        metadata = PERSPECTIVE_METADATA[perspective]
        disclaimer = _get_perspective_disclaimer(perspective)

        return cls(
            perspective=perspective,
            title=metadata["title"],
            icon=metadata["icon"],
            accent_color=metadata["accent_color"],
            key_points=key_points,
            evidence=evidence or [],
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
# MULTI-AGENT REASONING RESPONSE
# =============================================================================

class MultiAgentReasoningResponse(BaseModel):
    """
    Full response with 6 sequential perspective cards.

    Professional-grade analysis with compliance disclaimers.
    Sequential flow: Fundamental → News → Market → Technical → Debate → Risk
    """
    # Context
    ticker: str = Field(description="Stock ticker symbol")
    company_name: str = Field(description="Company name")
    investor_name: str = Field(description="Investor/fund name")
    change_type: str = Field(
        description="Type of change: NEW, ADDED, REDUCED, SOLD_OUT"
    )
    activity_summary: str = Field(
        description="Brief factual summary of the activity with key figures"
    )

    # The 6 perspective cards (sequential order)
    cards: List[ReasoningCard] = Field(
        min_length=6,
        max_length=6,
        description="Exactly 6 cards in sequential order"
    )

    # What we don't know section
    unknowns: List[str] = Field(
        default_factory=lambda: [
            "The exact execution prices at which trades were made",
            "The investor's private reasoning and decision-making process",
            "Whether the investor plans to increase, decrease, or maintain this position",
            "The investor's overall portfolio strategy and risk tolerance",
            "Any non-public information the investor may have access to",
        ],
        description="List of things we cannot know"
    )

    # Compliance
    overall_disclaimer: str = Field(
        default=(
            "IMPORTANT LEGAL DISCLAIMER: This multi-perspective analysis is generated by AI for "
            "educational and informational purposes ONLY. It does NOT constitute investment advice, "
            "a recommendation to buy, sell, or hold any security, or an offer to buy or sell securities. "
            "\n\n"
            "KEY LIMITATIONS:\n"
            "- We do NOT know the investor's actual reasoning or future intentions\n"
            "- Execution prices and exact timing are unknown\n"
            "- Past holdings changes do NOT predict future decisions\n"
            "- All interpretations are hypothetical scenarios, not facts\n"
            "- Market conditions may have changed significantly since this analysis\n"
            "\n"
            "Always conduct your own research and consult with a qualified financial advisor "
            "before making any investment decisions. Never invest based solely on this analysis."
        ),
        description="Required overall legal disclaimer"
    )

    # Metadata
    generated_at: datetime = Field(
        default_factory=datetime.utcnow,
        description="When this analysis was generated"
    )

    class Config:
        use_enum_values = True


# =============================================================================
# REQUEST SCHEMA
# =============================================================================

class MultiAgentReasoningRequest(BaseModel):
    """Request for multi-agent reasoning analysis."""
    investor_id: str = Field(description="Investor UUID or slug")
    ticker: str = Field(description="Stock ticker symbol")
    change_type: Optional[str] = Field(
        default=None,
        description="Type of change: NEW, ADDED, REDUCED, SOLD_OUT. If provided, filters results to this specific transaction type."
    )


# =============================================================================
# PROMPT TEMPLATES FOR PROFESSIONAL AI ANALYSIS
# =============================================================================

PERSPECTIVE_PROMPTS = {
    ReasoningPerspective.FUNDAMENTAL: """
You are a Senior Equity Research Analyst with 20+ years of experience at a top investment bank.

Analyze the FUNDAMENTAL factors for {ticker} ({company_name}):

REQUIRED FORMAT - Include specific numbers and metrics:
- P/E Ratio: State the current P/E and compare to 5-year average and sector median
- Revenue: Last quarter revenue, YoY growth rate (e.g., "$X.X billion, +X.X% YoY")
- Profit Margins: Gross margin, operating margin, net margin percentages
- EPS: Current EPS, analyst consensus, beat/miss history
- Balance Sheet: Debt-to-equity ratio, current ratio, cash position
- Valuation: Price-to-book, EV/EBITDA compared to peers

For each metric, explain its significance for this investment decision.

Provide 4-5 key points with SPECIFIC NUMBERS. No vague statements.
Include 2-3 evidence links to SEC filings, earnings reports, or financial data sources.
""",

    ReasoningPerspective.MARKET_CONTEXT: """
You are a Senior Market Strategist at a leading asset management firm.

Analyze the MARKET CONTEXT for {ticker} ({company_name}):

REQUIRED FORMAT - Include specific data points:
- Sector Performance: Sector YTD return vs S&P 500 (e.g., "Consumer Staples +X.X% vs S&P +X.X%")
- Peer Comparison: How {ticker} has performed vs top 3 competitors (with percentages)
- Macro Factors: Interest rate environment, inflation data, GDP growth affecting this sector
- Industry Trends: Market size, growth rate, key tailwinds/headwinds with figures
- Institutional Ownership: % held by institutions, recent changes in ownership
- Analyst Ratings: Consensus rating, average price target, range of targets

Provide 4-5 key points with SPECIFIC MARKET DATA. Reference actual market events.
Include 2-3 evidence links to market research, news articles, or data providers.
""",

    ReasoningPerspective.TECHNICAL: """
You are a Certified Market Technician (CMT) with expertise in institutional flow analysis.

Analyze the TECHNICAL factors for {ticker} ({company_name}):

REQUIRED FORMAT - Include specific price levels and figures:
- Price Action: Current price, 52-week high/low, distance from each (%)
- Moving Averages: 50-day MA, 200-day MA, current relationship (golden/death cross)
- Support/Resistance: Key levels with specific prices (e.g., "Support at $XX.XX")
- Volume Analysis: Average daily volume, recent volume vs average (%)
- RSI/Momentum: Current RSI, overbought/oversold status
- Trend: Primary trend direction, trend duration, key inflection points

IMPORTANT: Technical patterns are OBSERVATIONAL ONLY and do NOT predict future movements.

Provide 4-5 key points with SPECIFIC PRICE LEVELS AND PERCENTAGES.
Include 2-3 evidence links to chart analysis or technical data sources.
""",

    ReasoningPerspective.BULL_VS_BEAR: """
You are the Chief Investment Officer moderating a debate and providing a final verdict.

IMPORTANT: You have access to the previous analyses. Reference them specifically:
- Fundamental Analysis: Use the financial metrics and valuation data
- News & Sentiment: Consider recent news themes and sentiment
- Market Context: Reference sector performance and macro factors
- Technical Analysis: Consider price patterns and volume trends

Present BOTH sides of the argument for {ticker} ({company_name}), then deliver your FINAL VERDICT:

BULLISH CASE (3-4 arguments):
- Each argument must REFERENCE findings from previous analyses
- Include specific metrics from Fundamental Analysis
- Reference positive news from News & Sentiment if applicable
- Include price targets or valuation upside potential with numbers

BEARISH CASE (3-4 arguments):
- Each argument must REFERENCE findings from previous analyses
- Include risk metrics from Fundamental Analysis
- Reference negative news or concerns from News & Sentiment if applicable
- Include downside scenarios with specific figures

FINAL VERDICT (required):
After presenting both sides, provide your synthesized assessment:
1. VERDICT: State clearly - BULLISH, BEARISH, or NEUTRAL
2. REASONING: 2-3 sentences explaining why, referencing specific data from ALL previous analyses
3. CONFIDENCE: LOW or MEDIUM only (never HIGH - we cannot know investor intent)

Both bull/bear sides must be compelling and cross-reference other analyses.
Include 2-3 evidence links supporting key claims.

IMPORTANT: Frame the verdict as ONE POSSIBLE INTERPRETATION.
The investor's actual reasoning may be completely different.
""",

    ReasoningPerspective.NEWS_SENTIMENT: """
You are a Senior Media Analyst specializing in financial news sentiment analysis.

Analyze recent NEWS and MARKET SENTIMENT for {ticker} ({company_name}):

NOTE: Your analysis will inform the Market Context and Investment Debate that follow.

REQUIRED FORMAT:
1. NEWS SENTIMENT: State clearly - POSITIVE, NEGATIVE, MIXED, or NEUTRAL
2. NEWS SUMMARY: 2-3 sentences summarizing the key recent news themes
3. KEY NEWS POINTS (3-4 bullet points):
   - Recent earnings coverage and analyst reactions
   - Industry/sector news affecting the company
   - Company-specific announcements (products, leadership, strategy)
   - Any news related to institutional investor activity

4. SENTIMENT DRIVERS:
   - What is driving current market sentiment?
   - Any notable shifts in media coverage tone?

5. NEWS SOURCES: List 2-3 major news outlets covering this stock

IMPORTANT: Only reference news that is publicly available and verifiable.
News sentiment can change rapidly and should not be the sole basis for any investment decision.

Include 2-3 evidence links to Yahoo Finance news, MarketWatch, or Google Finance.
""",

    ReasoningPerspective.RISK_ASSESSMENT: """
You are a Senior Risk Manager synthesizing all previous analyses into an overall risk assessment.

CRITICAL: This is NOT investment advice. You are providing EDUCATIONAL risk observations only.

IMPORTANT: You MUST reference the previous 5 analyses:
1. Fundamental Analysis - Financial health and valuation risks
2. News & Sentiment - Media and sentiment-related risks
3. Market Context - Sector and macro risks
4. Technical Analysis - Price volatility and trend risks
5. Investment Debate - Key concerns raised in bearish case

REQUIRED FORMAT:

1. RISK LEVEL: State clearly - LOW, MODERATE, HIGH, or VERY_HIGH
   (Base this on the synthesis of ALL previous analyses)

2. RISK SUMMARY: 2-3 sentences synthesizing the overall risk picture,
   referencing specific findings from previous analyses.

3. KEY RISK FACTORS (4-5 bullet points):
   Each risk factor MUST reference which analysis it comes from:
   - "From Fundamental Analysis: [specific risk]"
   - "From News & Sentiment: [specific risk]"
   - "From Market Context: [specific risk]"
   - "From Technical Analysis: [specific risk]"
   - "From Investment Debate: [specific concern]"

4. KEY POINTS (3-4 observations):
   - Summarize the most important risk considerations
   - Note any conflicting signals across analyses
   - Highlight what is UNKNOWN (execution prices, investor intent, etc.)

CRITICAL COMPLIANCE:
- Do NOT recommend buying, selling, or holding
- Do NOT suggest this is a "good" or "bad" investment
- Only DESCRIBE and OBSERVE risks, never ADVISE
- Emphasize that risk assessment is subjective and may be wrong
- State clearly: "This is not investment advice"

Include 1-2 evidence links to support key risk factors.
""",
}
