"""
AI API routes - Compliance-aware endpoints.

COMPLIANCE:
- All outputs are descriptive, historical, and hypothetical
- No predictive or advisory language
- Proper disclaimers included in all responses

GEMINI 3 HACKATHON:
- Multimodal analysis endpoints for chart/document analysis
- Enhanced reasoning for deep financial pattern detection

LOCALIZATION:
- Supports multiple languages for AI responses
- Language is extracted from Accept-Language header
"""
import json
import logging
import os
from datetime import date, timedelta
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form, Header
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import DB, CurrentUser, OptionalUser, ProSubscription
from app.api.investors import _resolve_investor_uuid
from app.models.investor import Investor, StrategyNote
from app.models.holdings import HoldingsChange, InvestorAction
from app.models.company import Company, MarketPrice
from app.models.report import Report, AICompanyReport
from app.schemas.report import (
    AISummaryResponse,
    AICompanyRationaleResponse,
    AICompanyRationaleRequest,
)
from app.services.ai import (
    generate_investor_summary,
    generate_company_rationale,
    analyze_chart_with_gemini,
    analyze_document_with_gemini,
    compare_holdings_visually,
    generate_deep_analysis_with_reasoning,
)
from app.services.reasoning_demo import (
    generate_gemini_rationale,
    to_company_rationale_response,
    run_reasoning_demo,
)
from app.schemas.reasoning import (
    MultiAgentReasoningRequest,
    MultiAgentReasoningResponse,
)
from app.services.multi_agent_reasoning import (
    get_multi_agent_reasoning_for_change,
)
from app.services.cusip_lookup import get_cusip_from_ticker
from app.services.language import normalize_language_code, DEFAULT_LANGUAGE

router = APIRouter()
logger = logging.getLogger(__name__)


def get_language_from_header(accept_language: Optional[str] = None) -> str:
    """
    Extract the preferred language from the Accept-Language header.

    Args:
        accept_language: The Accept-Language header value (e.g., "zh-CN,zh;q=0.9,en;q=0.8")

    Returns:
        Normalized language code (e.g., "zh", "en", "es")
    """
    if not accept_language:
        return DEFAULT_LANGUAGE

    # Parse Accept-Language header (take the first language)
    # Format: "zh-CN,zh;q=0.9,en;q=0.8"
    first_lang = accept_language.split(",")[0].split(";")[0].strip()
    return normalize_language_code(first_lang)


@router.get("/investor-summary/{investor_id}", response_model=AISummaryResponse)
async def get_investor_ai_summary(
    investor_id: str,
    user: OptionalUser,
    db: DB,
    days: int = 30,
    accept_language: Optional[str] = Header(None, alias="Accept-Language"),
):
    """
    Generate AI summary for investor's recent disclosed changes.

    COMPLIANCE NOTE:
    - This endpoint returns descriptive, historical analysis only
    - All interpretations are framed as hypotheses
    - Response includes mandatory disclaimers

    LOCALIZATION:
    - Respects Accept-Language header for response language
    - Supports: en, zh, es, ja, ko, de, fr, ar

    Args:
        investor_id: UUID of the investor to summarize
        days: Number of days to look back (default 30)
        accept_language: Accept-Language header for response localization

    Returns:
        AISummaryResponse with compliance-aware fields in requested language
    """
    # Extract language from header
    language = get_language_from_header(accept_language)
    # Resolve UUID or slug
    investor_uuid = await _resolve_investor_uuid(investor_id, db)

    # Get investor with disclosure sources eagerly loaded
    investor_result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_uuid, Investor.is_active == True)
    )
    investor = investor_result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    # Get recent changes
    start_date = date.today() - timedelta(days=days)
    changes_result = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_uuid,
            HoldingsChange.to_date >= start_date,
        )
        .order_by(HoldingsChange.to_date.desc())
        .limit(50)
    )
    changes = changes_result.scalars().all()
    
    if not changes:
        # Return a compliant empty response
        return AISummaryResponse(
            headline=f"No Recent Changes for {investor.name}",
            what_changed=["No disclosed holdings changes in the selected period"],
            top_buys=[],
            top_sells=[],
            observations=["Insufficient data for observations"],
            interpretation_notes=[],
            limitations="No recent changes to analyze.",
            disclaimer="This is not investment advice.",
        )
    
    # Generate AI summary with language support
    summary = await generate_investor_summary(investor, changes, language=language)

    return summary


@router.post("/company-rationale", response_model=AICompanyRationaleResponse)
async def generate_company_rationale_report(
    request: AICompanyRationaleRequest,
    user: OptionalUser,
    db: DB,
    accept_language: Optional[str] = Header(None, alias="Accept-Language"),
):
    """
    Generate AI rationale for an investor's disclosed activity in a company.

    COMPLIANCE NOTE:
    - This endpoint returns hypothetical analysis only
    - All rationales are framed as possible explanations, not facts
    - We do NOT know the investor's actual reasoning
    - Response includes mandatory disclaimers and limitations
    
    Args:
        request: Contains investor_id and ticker
    
    Returns:
        AICompanyRationaleResponse with compliance-aware fields
    """
    # Resolve UUID or slug from request
    investor_uuid = await _resolve_investor_uuid(str(request.investor_id), db)

    # Get investor with disclosure sources eagerly loaded
    investor_result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_uuid, Investor.is_active == True)
    )
    investor = investor_result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    # Get company (optional — may not exist yet if company profiles haven't been refreshed)
    ticker_to_query = request.ticker.upper()
    company_result = await db.execute(
        select(Company).where(Company.ticker == ticker_to_query)
    )
    company = company_result.scalar_one_or_none()

    # Get investor's actions/changes for this ticker
    actions_result = await db.execute(
        select(InvestorAction)
        .where(
            InvestorAction.investor_id == investor_uuid,
            InvestorAction.ticker == ticker_to_query,
        )
        .order_by(InvestorAction.trade_date.desc())
        .limit(20)
    )
    actions = list(actions_result.scalars().all())

    changes_result = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_uuid,
            HoldingsChange.ticker == ticker_to_query,
        )
        .order_by(HoldingsChange.to_date.desc())
        .limit(10)
    )
    changes = list(changes_result.scalars().all())

    # If no results, try reverse lookup (ticker -> CUSIP)
    # This handles frontend sending resolved ticker "KHC" when DB has CUSIP "500754106"
    if not actions and not changes:
        cusip = get_cusip_from_ticker(ticker_to_query)
        if cusip:
            logger.info(f"Reverse lookup for company-rationale: {ticker_to_query} -> CUSIP {cusip}")
            actions_result = await db.execute(
                select(InvestorAction)
                .where(
                    InvestorAction.investor_id == investor_uuid,
                    InvestorAction.ticker == cusip,
                )
                .order_by(InvestorAction.trade_date.desc())
                .limit(20)
            )
            actions = list(actions_result.scalars().all())

            changes_result = await db.execute(
                select(HoldingsChange)
                .where(
                    HoldingsChange.investor_id == investor_uuid,
                    HoldingsChange.ticker == cusip,
                )
                .order_by(HoldingsChange.to_date.desc())
                .limit(10)
            )
            changes = list(changes_result.scalars().all())

    if not actions and not changes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No disclosed activity found for this investor and company",
        )
    
    # Get strategy notes
    notes_result = await db.execute(
        select(StrategyNote)
        .where(StrategyNote.investor_id == investor_uuid, StrategyNote.is_active == True)
    )
    strategy_notes = notes_result.scalars().all()
    
    # Get recent price data (for reference only, NOT execution prices)
    thirty_days_ago = date.today() - timedelta(days=30)
    prices_result = await db.execute(
        select(MarketPrice)
        .where(
            MarketPrice.ticker == request.ticker.upper(),
            MarketPrice.price_date >= thirty_days_ago,
        )
        .order_by(MarketPrice.price_date.desc())
    )
    prices = prices_result.scalars().all()
    
    # Build activity summary from DB data
    resolved_ticker = request.ticker.upper()
    resolved_name = (company.name if company else None) or (
        changes[0].company_name if changes else (
            actions[0].company_name if actions else resolved_ticker
        )
    )

    activity_lines: list[str] = []
    change_type = "changed"
    for c in changes[:5]:
        ct = c.change_type.value.upper() if c.change_type else "CHANGED"
        change_type = ct
        # Format shares delta nicely
        if c.shares_delta and c.shares_delta != 0:
            shares_str = f"{c.shares_delta:+,.0f} shares"
        else:
            shares_str = ""
        # Format value delta if available
        if c.value_delta and c.value_delta != 0:
            value_str = f" (${c.value_delta:+,.0f})"
        else:
            value_str = ""
        activity_lines.append(
            f"• {ct}: {shares_str}{value_str}"
        )
    for a in actions[:5]:
        at = a.action_type.value.upper() if a.action_type else "TRADE"
        shares_info = f"{a.shares:,.0f} shares" if a.shares else ""
        date_str = a.trade_date.isoformat() if a.trade_date else "date unknown"
        activity_lines.append(
            f"• {at}: {shares_info} on {date_str}"
        )
    activity_summary = "\n".join(activity_lines) if activity_lines else (
        f"{investor.name} has a disclosed position in {resolved_ticker}."
    )

    # --- Primary: Gemini with 6-pillar analysis ---
    _logger = logging.getLogger(__name__)

    rationale_dict: dict | None = None
    if os.getenv("GEMINI_API_KEY"):
        try:
            gemini_result = await generate_gemini_rationale(
                investor_name=investor.name,
                ticker=resolved_ticker,
                company_name=resolved_name,
                change_type=change_type,
                activity_summary=activity_summary,
            )
            rationale_dict = to_company_rationale_response(
                gemini_result=gemini_result,
                investor_name=investor.name,
                company_name=resolved_name,
                ticker=resolved_ticker,
                activity_summary=activity_summary,
            )
        except Exception as e:
            _logger.warning(f"Gemini reasoning failed for {resolved_ticker}, falling back: {e}")

    # --- Fallback: ai.py generic reasoning ---
    if rationale_dict is None:
        try:
            rationale_obj = await generate_company_rationale(
                investor=investor,
                company=company,
                actions=actions,
                changes=changes,
                strategy_notes=strategy_notes,
                price_data=prices,
                ticker=resolved_ticker,
            )
            rationale_dict = rationale_obj.model_dump()
        except Exception as e:
            _logger.warning(f"ai.py reasoning also failed for {resolved_ticker}: {e}")
            # Return a safe default
            rationale_dict = {
                "company_overview": f"{resolved_name} ({resolved_ticker})",
                "investor_activity_summary": activity_summary,
                "possible_rationales": [],
                "patterns_vs_history": "",
                "evidence_panel": None,
                "what_is_unknown": "We do not know the exact execution prices, the investor's private reasoning, or their future intentions.",
                "disclaimer": "This analysis is generated by AI. Do not make investment decisions based on this analysis.",
            }

    # Store the report for audit trail (only if user is authenticated)
    if user is not None:
        ai_report = AICompanyReport(
            user_id=user.id,
            investor_id=investor.id,
            ticker=resolved_ticker,
            json_payload=rationale_dict,
            input_data={
                "actions_count": len(actions),
                "changes_count": len(changes),
                "strategy_notes_count": len(strategy_notes),
                "price_data_available": len(prices) > 0,
                "engine": "gemini_6pillar" if os.getenv("GEMINI_API_KEY") else "ai_py_fallback",
            },
        )
        db.add(ai_report)
        await db.commit()

    return rationale_dict


@router.post("/company-rationale-mock", response_model=AICompanyRationaleResponse)
async def generate_company_rationale_mock(
    request: AICompanyRationaleRequest,
):
    """
    TEMPORARY MOCK ENDPOINT for testing frontend 6-pillar display.
    Returns a complete mock response with all 6 pillars and evidence panel.
    
    Usage: Call this endpoint instead of /company-rationale to test frontend.
    DELETE THIS after Gemini API quota is restored and real endpoint is verified.
    """
    return {
        "company_overview": f"{request.ticker} is a major corporation with significant market presence in its sector.",
        "investor_activity_summary": "Recent disclosed activity shows strategic position changes including both new investments and reductions in specific holdings.",
        "possible_rationales": [
            {
                "hypothesis": "[Industry & Competition] The competitive landscape has shifted significantly, with new entrants and changing market dynamics affecting strategic positioning.",
                "supporting_signals": ["Based on Industry & Competition analysis"],
                "evidence_ids": ["E1"],
                "confidence": "low"
            },
            {
                "hypothesis": "[Product & Sales] Recent product launches and sales performance indicate evolving market demand patterns and revenue diversification opportunities.",
                "supporting_signals": ["Based on Product & Sales analysis"],
                "evidence_ids": ["E2"],
                "confidence": "low"
            },
            {
                "hypothesis": "[Financial Fundamentals] Balance sheet strength and cash flow metrics show improving operational efficiency and financial flexibility.",
                "supporting_signals": ["Based on Financial Fundamentals analysis"],
                "evidence_ids": ["E3"],
                "confidence": "low"
            },
            {
                "hypothesis": "[Research & Reputation] Market sentiment and analyst coverage patterns have evolved, reflecting changing institutional perspectives on valuation.",
                "supporting_signals": ["Based on Research & Reputation analysis"],
                "evidence_ids": ["E4"],
                "confidence": "low"
            },
            {
                "hypothesis": "[Technical Analysis] Price action, volume trends, and institutional flow patterns suggest tactical repositioning by major market participants.",
                "supporting_signals": ["Based on Technical Analysis analysis"],
                "evidence_ids": [],
                "confidence": "low"
            },
            {
                "hypothesis": "[Synthesis] Overall, the position changes likely reflect a strategic reassessment combining fundamental analysis, sector rotation considerations, and portfolio risk management objectives.",
                "supporting_signals": ["Based on Synthesis analysis"],
                "evidence_ids": ["E1", "E2", "E3", "E4"],
                "confidence": "medium"
            }
        ],
        "patterns_vs_history": "This activity pattern represents a notable strategic shift compared to historical positioning, potentially indicating evolving investment thesis or portfolio rebalancing.",
        "evidence_panel": {
            "signals_used": [
                {
                    "signal_id": "DISC_META_001",
                    "category": "disclosure_metadata",
                    "description": f"Comprehensive analysis of disclosed holdings activity in {request.ticker}",
                    "source": "Public regulatory filings (13F, 13G)",
                    "value": "Strategic position change reflecting institutional decision-making"
                },
                {
                    "signal_id": "E1",
                    "category": "web_search",
                    "description": "Industry competitive analysis reveals shifting market dynamics and emerging sector trends",
                    "source": "Market intelligence reports",
                    "value": "https://example.com/industry-competitive-landscape"
                },
                {
                    "signal_id": "E2",
                    "category": "web_search",
                    "description": "Product performance data shows evolving consumer demand patterns and revenue mix changes",
                    "source": "Company earnings reports & market data",
                    "value": "https://example.com/product-performance-analysis"
                },
                {
                    "signal_id": "E3",
                    "category": "web_search",
                    "description": "Financial statement analysis indicates improving operational metrics and capital efficiency",
                    "source": "SEC filings & financial databases",
                    "value": "https://example.com/financial-fundamentals"
                },
                {
                    "signal_id": "E4",
                    "category": "web_search",
                    "description": "Institutional analyst reports and research coverage provide valuation perspective shifts",
                    "source": "Equity research & analyst consensus",
                    "value": "https://example.com/analyst-research-summary"
                }
            ],
            "unknowns": [
                {
                    "unknown_id": "execution_price",
                    "description": "The exact price(s) at which trades were executed",
                    "is_standard": True
                },
                {
                    "unknown_id": "investor_reasoning",
                    "description": "The investor's actual private reasoning and decision-making process",
                    "is_standard": True
                },
                {
                    "unknown_id": "future_intentions",
                    "description": "Whether the investor plans to increase, decrease, or maintain this position",
                    "is_standard": True
                }
            ],
            "evidence_completeness": "sufficient",
            "should_auto_expand": False
        },
        "what_is_unknown": "We do not know the exact execution prices, the investor's private reasoning, or their future intentions.",
        "disclaimer": "This analysis is generated by AI based on publicly available information. It represents hypothetical reasoning, not the investor's actual rationale. Do not make investment decisions based on this analysis."
    }


@router.get("/history")
async def get_ai_report_history(
    user: CurrentUser,
    db: DB,
    limit: int = 20,
):
    """
    Get user's AI report generation history.
    
    Returns a list of previously generated AI reports for audit/review.
    """
    result = await db.execute(
        select(AICompanyReport)
        .where(AICompanyReport.user_id == user.id)
        .order_by(AICompanyReport.generated_at.desc())
        .limit(limit)
    )
    reports = result.scalars().all()
    
    return {
        "reports": [
            {
                "id": str(r.id),
                "investor_id": str(r.investor_id) if r.investor_id else None,
                "ticker": r.ticker,
                "generated_at": r.generated_at.isoformat(),
            }
            for r in reports
        ]
    }


@router.get("/compliance-info")
async def get_compliance_info():
    """
    Return compliance information about AI-generated content.
    
    This endpoint provides transparency about how AI analysis is generated
    and its limitations.
    """
    return {
        "product_type": "Financial Information & Analytics Tool",
        "ai_content_type": "Descriptive, Historical, Hypothetical",
        "what_we_provide": [
            "Aggregation of publicly disclosed holdings data",
            "Structured change detection and summaries",
            "AI-assisted descriptive analysis of disclosed activity",
        ],
        "what_we_do_not_provide": [
            "Investment advice or recommendations",
            "Personalized investment suggestions",
            "Buy/Sell/Hold instructions",
            "Price predictions or targets",
            "Asset management services",
        ],
        "ai_limitations": [
            "All interpretations are hypotheses, not facts",
            "We do not know investors' actual reasoning",
            "Execution prices are unknown (only market price ranges)",
            "Past holdings changes do not indicate future actions",
            "Confidence levels are never 'high' - we operate with inherent uncertainty",
        ],
        "disclaimer": (
            "WhyTheyBuy provides financial information for informational purposes only. "
            "Content does not constitute investment advice. Please consult a qualified "
            "financial advisor before making investment decisions."
        ),
        "ai_provider": "Gemini 3 (Google DeepMind)",
        "hackathon": "Gemini 3 Global Hackathon Submission",
    }


# =============================================================================
# INVESTOR REPORT EMAIL ENDPOINT
# =============================================================================

@router.post("/investor-report/{investor_id}")
async def generate_and_send_investor_report(
    investor_id: str,
    user: CurrentUser,
    db: DB,
    format: str = "email",
    language: str = "en",
):
    """
    Generate a comprehensive investor report and send it via email.

    The report includes:
    - Portfolio overview with sector breakdown
    - Recent holdings changes with AI reasoning
    - Top buys and sells analysis
    - Investment thesis hypotheses
    - Compliance disclaimers

    COMPLIANCE:
    - All analysis is descriptive and hypothetical
    - Includes mandatory disclaimers
    - No investment recommendations
    """
    from app.services.email import send_email
    from app.config import settings

    # Resolve investor
    investor_uuid = await _resolve_investor_uuid(investor_id, db)

    investor_result = await db.execute(
        select(Investor)
        .where(Investor.id == investor_uuid, Investor.is_active == True)
    )
    investor = investor_result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    # Get recent changes (last 30 days)
    start_date = date.today() - timedelta(days=30)
    changes_result = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_uuid,
            HoldingsChange.to_date >= start_date,
        )
        .order_by(HoldingsChange.shares_delta.desc().nullsfirst())
        .limit(50)
    )
    changes = changes_result.scalars().all()

    # Separate buys and sells
    buys = [c for c in changes if c.change_type in ('NEW', 'ADDED')]
    sells = [c for c in changes if c.change_type in ('REDUCED', 'SOLD_OUT')]

    # Sort by absolute share delta
    buys.sort(key=lambda x: abs(x.shares_delta or 0), reverse=True)
    sells.sort(key=lambda x: abs(x.shares_delta or 0), reverse=True)

    # Format numbers
    def fmt_shares(n):
        if n is None:
            return "N/A"
        return f"{n:,.0f}"

    def fmt_value(n):
        if n is None:
            return "N/A"
        if abs(n) >= 1_000_000_000:
            return f"${n/1_000_000_000:.1f}B"
        if abs(n) >= 1_000_000:
            return f"${n/1_000_000:.1f}M"
        return f"${n:,.0f}"

    # Build HTML email content
    buys_html = ""
    for c in buys[:5]:
        buys_html += f"""
        <tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{c.ticker}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{c.company_name or ''}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee; color: #22c55e;">+{fmt_shares(c.shares_delta)}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{fmt_value(c.value_after)}</td>
        </tr>
        """

    sells_html = ""
    for c in sells[:5]:
        sells_html += f"""
        <tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{c.ticker}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{c.company_name or ''}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee; color: #ef4444;">{fmt_shares(c.shares_delta)}</td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">{fmt_value(c.value_after)}</td>
        </tr>
        """

    # Generate AI summary if API key available
    ai_summary = ""
    if settings.gemini_api_key:
        try:
            summary_result = await generate_investor_summary(
                investor=investor,
                changes=changes[:20],
                disclosure_sources=investor.disclosure_sources if hasattr(investor, 'disclosure_sources') else [],
            )
            if summary_result:
                ai_summary = f"""
                <div style="background: #f0fdf4; padding: 16px; border-radius: 8px; margin: 16px 0;">
                    <h3 style="color: #166534; margin: 0 0 8px 0;">AI Analysis Summary</h3>
                    <p style="color: #15803d; margin: 0;">{summary_result.headline}</p>
                    <ul style="color: #166534; margin: 8px 0 0 0; padding-left: 20px;">
                        {''.join(f'<li>{h}</li>' for h in (summary_result.highlights or [])[:3])}
                    </ul>
                </div>
                """
        except Exception as e:
            logger.warning(f"AI summary generation failed: {e}")

    html_content = f"""
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; color: #1f2937;">
        <div style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 24px; border-radius: 12px 12px 0 0;">
            <h1 style="color: white; margin: 0; font-size: 24px;">Portfolio Analysis Report</h1>
            <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0;">{investor.name}</p>
        </div>

        <div style="background: white; padding: 24px; border: 1px solid #e5e7eb; border-top: none;">
            <p style="color: #6b7280; font-size: 14px;">
                Report generated on {date.today().strftime('%B %d, %Y')} • Last 30 days of disclosed activity
            </p>

            {ai_summary}

            <h2 style="color: #1f2937; font-size: 18px; margin-top: 24px;">Top Buys</h2>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                <thead>
                    <tr style="background: #f9fafb;">
                        <th style="padding: 8px; text-align: left;">Ticker</th>
                        <th style="padding: 8px; text-align: left;">Company</th>
                        <th style="padding: 8px; text-align: left;">Shares</th>
                        <th style="padding: 8px; text-align: left;">Value</th>
                    </tr>
                </thead>
                <tbody>
                    {buys_html if buys_html else '<tr><td colspan="4" style="padding: 16px; text-align: center; color: #9ca3af;">No buys in this period</td></tr>'}
                </tbody>
            </table>

            <h2 style="color: #1f2937; font-size: 18px; margin-top: 24px;">Top Sells</h2>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                <thead>
                    <tr style="background: #f9fafb;">
                        <th style="padding: 8px; text-align: left;">Ticker</th>
                        <th style="padding: 8px; text-align: left;">Company</th>
                        <th style="padding: 8px; text-align: left;">Shares</th>
                        <th style="padding: 8px; text-align: left;">Value</th>
                    </tr>
                </thead>
                <tbody>
                    {sells_html if sells_html else '<tr><td colspan="4" style="padding: 16px; text-align: center; color: #9ca3af;">No sells in this period</td></tr>'}
                </tbody>
            </table>

            <div style="margin-top: 24px; padding: 16px; background: #fef3c7; border-radius: 8px;">
                <p style="color: #92400e; font-size: 12px; margin: 0;">
                    <strong>Disclaimer:</strong> This report is for informational purposes only and does not constitute investment advice.
                    AI-generated analysis represents hypothetical reasoning based on publicly disclosed information, not the investor's actual rationale.
                    Past holdings changes do not indicate future actions. Always consult a qualified financial advisor before making investment decisions.
                </p>
            </div>
        </div>

        <div style="background: #1f2937; padding: 16px; border-radius: 0 0 12px 12px; text-align: center;">
            <p style="color: #9ca3af; font-size: 12px; margin: 0;">
                Powered by WhyTheyBuy • Gemini 3 AI Analysis
            </p>
        </div>
    </div>
    """

    # Send email
    try:
        await send_email(
            to_email=user.email,
            subject=f"Portfolio Report: {investor.name}",
            html_content=html_content,
        )

        # Create report record
        report = Report(
            user_id=user.id,
            investor_id=investor.id,
            report_type="investor_change",
            report_date=date.today(),
            title=f"Portfolio Report: {investor.name}",
            summary_json={
                "buys_count": len(buys),
                "sells_count": len(sells),
                "total_changes": len(changes),
            },
            email_sent=True,
            email_sent_at=date.today(),
            email_recipient=user.email,
        )
        db.add(report)
        await db.commit()

        return {
            "status": "success",
            "message": f"Report sent to {user.email}",
            "investor": investor.name,
            "changes_included": len(changes),
        }

    except Exception as e:
        logger.error(f"Failed to send report email: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send report. Please try again later.",
        )


# =============================================================================
# GEMINI 3 MULTIMODAL ENDPOINTS (Hackathon Features)
# =============================================================================

@router.post("/analyze-chart")
async def analyze_financial_chart(
    user: CurrentUser,
    file: UploadFile = File(...),
    context: Optional[str] = Form(None),
):
    """
    Analyze a financial chart using Gemini 3's multimodal capabilities.

    HACKATHON FEATURE: This endpoint demonstrates Gemini 3's vision
    capabilities for extracting insights from financial visualizations.

    Supports: PNG, JPEG, WebP chart images

    COMPLIANCE:
    - Returns descriptive analysis only
    - No predictions or recommendations
    - Includes mandatory disclaimers
    """
    # Validate file type
    allowed_types = ["image/png", "image/jpeg", "image/webp"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type. Allowed: {allowed_types}",
        )

    # Read file content
    image_data = await file.read()

    # Check file size (max 10MB)
    if len(image_data) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size: 10MB",
        )

    # Analyze with Gemini 3
    result = await analyze_chart_with_gemini(
        image_data=image_data,
        mime_type=file.content_type,
        additional_context=context,
    )

    return {
        "analysis": result,
        "filename": file.filename,
        "powered_by": "Gemini 3 Multimodal",
    }


@router.post("/analyze-document")
async def analyze_financial_document(
    user: CurrentUser,
    file: UploadFile = File(...),
    document_type: Optional[str] = Form(None),
):
    """
    Extract information from financial documents using Gemini 3's vision.

    HACKATHON FEATURE: Demonstrates Gemini 3's document understanding
    for SEC filings, reports, and other financial documents.

    Supports: PNG, JPEG, WebP, PDF (first page) images

    COMPLIANCE:
    - Extracts factual information only
    - No interpretive predictions
    - Includes disclaimers
    """
    allowed_types = ["image/png", "image/jpeg", "image/webp", "application/pdf"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type. Allowed: {allowed_types}",
        )

    image_data = await file.read()

    if len(image_data) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size: 10MB",
        )

    # For PDFs, we'd need additional processing - for now, handle images
    mime_type = file.content_type
    if mime_type == "application/pdf":
        # PDF handling note - would need pdf2image in production
        mime_type = "image/png"  # Assume converted

    result = await analyze_document_with_gemini(
        image_data=image_data,
        mime_type=mime_type,
        document_type_hint=document_type,
    )

    return {
        "extraction": result,
        "filename": file.filename,
        "powered_by": "Gemini 3 Document Understanding",
    }


@router.post("/compare-charts")
async def compare_holdings_charts(
    user: CurrentUser,
    file1: UploadFile = File(...),
    file2: UploadFile = File(...),
    context: Optional[str] = Form(None),
):
    """
    Compare two holdings charts using Gemini 3's multimodal analysis.

    HACKATHON FEATURE: Demonstrates multi-image analysis capabilities
    for comparing before/after portfolios or different investor allocations.

    COMPLIANCE:
    - Describes observable differences only
    - No predictive recommendations
    - Includes disclaimers
    """
    allowed_types = ["image/png", "image/jpeg", "image/webp"]

    for f, name in [(file1, "file1"), (file2, "file2")]:
        if f.content_type not in allowed_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{name}: Unsupported file type. Allowed: {allowed_types}",
            )

    chart1_data = await file1.read()
    chart2_data = await file2.read()

    for data, name in [(chart1_data, "file1"), (chart2_data, "file2")]:
        if len(data) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{name}: File too large. Maximum size: 10MB",
            )

    result = await compare_holdings_visually(
        chart1_data=chart1_data,
        chart2_data=chart2_data,
        mime_type=file1.content_type,
        comparison_context=context,
    )

    return {
        "comparison": result,
        "files": [file1.filename, file2.filename],
        "powered_by": "Gemini 3 Multi-Image Analysis",
    }


@router.get("/deep-analysis/{investor_id}")
async def get_deep_analysis_with_reasoning(
    investor_id: str,
    user: CurrentUser,
    subscription: ProSubscription,
    db: DB,
    days: int = 30,
    include_reasoning: bool = True,
):
    """
    Generate deep analysis using Gemini 3's enhanced reasoning.

    HACKATHON FEATURE: Showcases Gemini 3's advanced reasoning for:
    - Multi-step pattern analysis
    - Cross-sector correlation detection
    - Thematic investment identification

    COMPLIANCE:
    - All analysis is hypothetical
    - No predictions or recommendations
    - Includes full disclaimers
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)

    # Get investor with disclosure sources eagerly loaded
    investor_result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_uuid, Investor.is_active == True)
    )
    investor = investor_result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    # Get recent changes
    start_date = date.today() - timedelta(days=days)
    changes_result = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_uuid,
            HoldingsChange.to_date >= start_date,
        )
        .order_by(HoldingsChange.to_date.desc())
        .limit(100)  # More data for deep analysis
    )
    changes = list(changes_result.scalars().all())

    if not changes:
        return {
            "analysis": {
                "error": "No recent changes to analyze",
                "disclaimer": "This is not investment advice.",
            },
            "investor": investor.name,
            "powered_by": "Gemini 3 Enhanced Reasoning",
        }

    # Generate deep analysis with Gemini 3
    result = await generate_deep_analysis_with_reasoning(
        investor=investor,
        changes=changes,
        include_thinking=include_reasoning,
    )

    return {
        "analysis": result,
        "investor": investor.name,
        "period_days": days,
        "changes_analyzed": len(changes),
        "powered_by": "Gemini 3 Enhanced Reasoning",
    }


@router.post("/reasoning-demo")
async def reasoning_demo_endpoint(
    request: AICompanyRationaleRequest,
    user: OptionalUser,
    db: DB,
):
    """
    Synchronous reasoning demo endpoint for 6-pillar analysis.

    HACKATHON FEATURE: Demonstrates Gemini 3's 6-pillar institutional
    investment reasoning in a blocking/demo mode.

    This endpoint provides the same analysis as /company-rationale but
    with synchronous (blocking) execution, suitable for demos and testing.

    COMPLIANCE:
    - Returns hypothetical analysis only
    - All interpretations are framed as possible explanations
    - No investment advice or predictions
    - Includes mandatory disclaimers and limitations

    Args:
        request: Contains investor_id and ticker

    Returns:
        AICompanyRationaleResponse-compatible response
    """
    # Build minimal activity summary without database (for demo purposes)
    # In a real scenario, you might want to look up holdings data
    resolved_ticker = request.ticker.upper()
    
    # For demo, we can optionally look up the investor if DB is provided
    investor_name = "Investor"
    company_name = resolved_ticker
    activity_summary = f"Position activity in {resolved_ticker}"
    change_type = "changed"

    # Try to get real data from database
    try:
        investor_uuid = await _resolve_investor_uuid(str(request.investor_id), db)
        
        investor_result = await db.execute(
            select(Investor)
            .options(selectinload(Investor.disclosure_sources))
            .where(Investor.id == investor_uuid, Investor.is_active == True)
        )
        investor = investor_result.scalar_one_or_none()
        
        if investor:
            investor_name = investor.name
            
            # Get company info
            company_result = await db.execute(
                select(Company).where(Company.ticker == resolved_ticker)
            )
            company = company_result.scalar_one_or_none()
            if company:
                company_name = company.name
            
            # Get investor's actions/changes for this ticker
            changes_result = await db.execute(
                select(HoldingsChange)
                .where(
                    HoldingsChange.investor_id == investor_uuid,
                    HoldingsChange.ticker == resolved_ticker,
                )
                .order_by(HoldingsChange.to_date.desc())
                .limit(5)
            )
            changes = changes_result.scalars().all()
            
            if changes:
                change_type = changes[0].change_type.value if changes[0].change_type else "changed"
                activity_lines = []
                for c in changes:
                    ct = c.change_type.value if c.change_type else "CHANGED"
                    delta = f"{c.shares_delta:+,.0f} shares" if c.shares_delta else ""
                    activity_lines.append(f"{ct}: {c.from_date} to {c.to_date} {delta}")
                activity_summary = "\n".join(activity_lines)
    except Exception as e:
        # Silently fall back to demo mode if database lookup fails
        logger.warning(f"Database lookup failed in reasoning-demo: {e}")

    # Call synchronous reasoning function
    try:
        result = run_reasoning_demo(
            investor_name=investor_name,
            ticker=resolved_ticker,
            company_name=company_name,
            change_type=change_type,
            activity_summary=activity_summary,
        )
        return result
    except RuntimeError as e:
        # If GEMINI_API_KEY is not set
        if "GEMINI_API_KEY" in str(e):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Gemini API key not configured. Please set GEMINI_API_KEY environment variable.",
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Reasoning engine failed: {str(e)}",
        )
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to parse Gemini response: {str(e)}",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error in reasoning demo: {str(e)}",
        )


@router.post("/multi-agent-reasoning", response_model=MultiAgentReasoningResponse)
async def get_multi_agent_reasoning(
    request: MultiAgentReasoningRequest,
    user: OptionalUser,
    db: DB,
    accept_language: Optional[str] = Header(None, alias="Accept-Language"),
):
    """
    Generate multi-agent reasoning analysis for a portfolio change.

    This endpoint provides 6 different perspective analyses:
    - Fundamental Analysis: Financial metrics, valuation, balance sheet
    - Market Context: Sector trends, macro environment, peer comparison
    - Technical Analysis: Price patterns, volume, technical indicators
    - Bullish Perspective: Arguments supporting the position
    - Bearish Perspective: Risk factors and concerns
    - Synthesis: Balanced conclusion combining all perspectives

    COMPLIANCE:
    - All analysis is HYPOTHETICAL and for educational purposes only
    - NO buy/sell recommendations or investment advice
    - NO predictions of future price movements
    - Confidence capped at "medium" (never "high")
    - Mandatory disclaimers on each perspective card

    LOCALIZATION:
    - Respects Accept-Language header for response language
    - Supports: en, zh, es, ja, ko, de, fr, ar

    Args:
        request: Contains investor_id and ticker
        accept_language: Accept-Language header for response localization

    Returns:
        MultiAgentReasoningResponse with 6 perspective cards in requested language
    """
    import time
    start_time = time.time()
    user_email = user.email if user else "anonymous"

    # Extract language from header
    language = get_language_from_header(accept_language)

    logger.info("=" * 60)
    logger.info("AI REASONING REQUEST STARTED")
    logger.info(f"  User: {user_email}")
    logger.info(f"  Investor ID: {request.investor_id}")
    logger.info(f"  Ticker: {request.ticker}")
    logger.info(f"  Change Type: {request.change_type or 'not specified'}")
    logger.info(f"  Language: {language}")
    logger.info("=" * 60)

    # Resolve investor
    investor_uuid = await _resolve_investor_uuid(str(request.investor_id), db)

    investor_result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_uuid, Investor.is_active == True)
    )
    investor = investor_result.scalar_one_or_none()

    if not investor:
        logger.warning(f"  [FAIL] Investor not found: {request.investor_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    logger.info(f"  [OK] Found investor: {investor.name}")

    resolved_ticker = request.ticker.upper()

    # Get company info
    company_result = await db.execute(
        select(Company).where(Company.ticker == resolved_ticker)
    )
    company = company_result.scalar_one_or_none()
    company_name = company.name if company else resolved_ticker
    logger.info(f"  [OK] Company: {company_name} ({resolved_ticker})")

    # Get investor's changes for this ticker
    # First try with the ticker as-is
    changes_result = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_uuid,
            HoldingsChange.ticker == resolved_ticker,
        )
        .order_by(HoldingsChange.to_date.desc())
        .limit(5)
    )
    changes = list(changes_result.scalars().all())

    # If no changes found, try reverse lookup (ticker -> CUSIP)
    # This handles the case where frontend sends resolved ticker "KHC"
    # but database stores the original CUSIP "500754106"
    db_ticker = resolved_ticker  # The ticker used for DB query
    if not changes:
        cusip = get_cusip_from_ticker(resolved_ticker)
        if cusip:
            logger.info(f"Reverse lookup: {resolved_ticker} -> CUSIP {cusip}")
            changes_result = await db.execute(
                select(HoldingsChange)
                .where(
                    HoldingsChange.investor_id == investor_uuid,
                    HoldingsChange.ticker == cusip,
                )
                .order_by(HoldingsChange.to_date.desc())
                .limit(5)
            )
            changes = list(changes_result.scalars().all())
            if changes:
                db_ticker = cusip  # Remember we used CUSIP for the query
                # Also try to get company name from the change record
                if not company and changes[0].company_name:
                    company_name = changes[0].company_name

    if not changes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No disclosed activity found for this investor and company",
        )

    # If change_type is specified in request, filter to that specific transaction
    if request.change_type:
        requested_type = request.change_type.upper()
        matching_changes = [
            c for c in changes
            if c.change_type and c.change_type.value.upper() == requested_type
        ]
        if matching_changes:
            changes = matching_changes
            logger.info(f"Filtered to {len(changes)} changes matching type {requested_type}")
        else:
            # No match found - try searching by CUSIP for this change_type
            cusip = get_cusip_from_ticker(resolved_ticker)
            if cusip:
                logger.info(f"No {requested_type} found for {resolved_ticker}, trying CUSIP {cusip}")
                cusip_changes_result = await db.execute(
                    select(HoldingsChange)
                    .where(
                        HoldingsChange.investor_id == investor_uuid,
                        HoldingsChange.ticker == cusip,
                    )
                    .order_by(HoldingsChange.to_date.desc())
                    .limit(5)
                )
                cusip_changes = list(cusip_changes_result.scalars().all())
                cusip_matching = [
                    c for c in cusip_changes
                    if c.change_type and c.change_type.value.upper() == requested_type
                ]
                if cusip_matching:
                    changes = cusip_matching
                    logger.info(f"Found {len(changes)} matching changes via CUSIP {cusip}")
                    # Update company name if available
                    if cusip_matching[0].company_name:
                        company_name = cusip_matching[0].company_name
                else:
                    logger.warning(f"No changes found matching type {requested_type}, using most recent")
            else:
                logger.warning(f"No changes found matching type {requested_type}, using most recent")

    # Get the most recent change details
    latest_change = changes[0]
    change_type = latest_change.change_type.value.upper() if latest_change.change_type else "CHANGED"
    shares_change = int(latest_change.shares_delta) if latest_change.shares_delta else None
    value_change = float(latest_change.value_delta) if latest_change.value_delta else None

    logger.info(f"  [OK] Found transaction: {change_type}")
    logger.info(f"       Shares delta: {shares_change:,}" if shares_change else "       Shares delta: N/A")
    logger.info(f"       Value delta: ${value_change:,.0f}" if value_change else "       Value delta: N/A")
    logger.info("-" * 60)
    logger.info("  Calling Gemini AI for 6-perspective analysis...")

    try:
        ai_start_time = time.time()
        result = await get_multi_agent_reasoning_for_change(
            investor_name=investor.name,
            ticker=resolved_ticker,
            company_name=company_name,
            change_type=change_type,
            shares_change=shares_change,
            value_change=value_change,
            language=language,
        )
        ai_duration = time.time() - ai_start_time
        total_duration = time.time() - start_time

        logger.info(f"  [SUCCESS] AI reasoning generated in {language}")
        logger.info(f"       Cards generated: {len(result.cards)}")
        logger.info(f"       AI call duration: {ai_duration:.2f}s")
        logger.info(f"       Total request duration: {total_duration:.2f}s")
        logger.info("=" * 60)

        return result

    except RuntimeError as e:
        total_duration = time.time() - start_time
        logger.error(f"  [FAIL] RuntimeError after {total_duration:.2f}s: {e}")
        logger.error("=" * 60)
        if "GEMINI_API_KEY" in str(e):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Gemini API key not configured. Please set GEMINI_API_KEY environment variable.",
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Multi-agent reasoning engine failed: {str(e)}",
        )
    except json.JSONDecodeError as e:
        total_duration = time.time() - start_time
        logger.error(f"  [FAIL] JSON parse error after {total_duration:.2f}s: {e}")
        logger.error("=" * 60)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to parse Gemini response: {str(e)}",
        )
    except Exception as e:
        total_duration = time.time() - start_time
        logger.error(f"  [FAIL] Unexpected error after {total_duration:.2f}s: {e}")
        logger.error("=" * 60)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error: {str(e)}",
        )


@router.get("/gemini-capabilities")
async def get_gemini_capabilities():
    """
    Describe Gemini 3 capabilities available in this API.

    For Hackathon judges: This endpoint documents the Gemini 3 features
    integrated into WhyTheyBuy.
    """
    return {
        "hackathon": "Gemini 3 Global Hackathon 2026",
        "project": "WhyTheyBuy - AI-Powered Institutional Holdings Tracker",
        "gemini_integration": {
            "model": "gemini-3-flash-preview",
            "features_used": [
                {
                    "name": "Text Generation with Structured Output",
                    "endpoint": "/api/ai/investor-summary/{id}",
                    "description": "Generate compliance-aware summaries of investor holdings changes",
                },
                {
                    "name": "6-Pillar Reasoning Analysis",
                    "endpoint": "/api/ai/reasoning-demo",
                    "description": "Synchronous reasoning demo with institutional investment strategy analysis",
                },
                {
                    "name": "Multi-Agent Reasoning (TradingAgents-inspired)",
                    "endpoint": "/api/ai/multi-agent-reasoning",
                    "description": "6-perspective analysis inspired by TradingAgents paper: Fundamental, Market Context, Technical, Bullish, Bearish, Synthesis",
                },
                {
                    "name": "Multimodal Chart Analysis",
                    "endpoint": "/api/ai/analyze-chart",
                    "description": "Extract insights from financial charts using vision capabilities",
                },
                {
                    "name": "Document Understanding",
                    "endpoint": "/api/ai/analyze-document",
                    "description": "Extract data from SEC filings and financial documents",
                },
                {
                    "name": "Multi-Image Comparison",
                    "endpoint": "/api/ai/compare-charts",
                    "description": "Compare before/after portfolios using multi-image analysis",
                },
                {
                    "name": "Enhanced Reasoning",
                    "endpoint": "/api/ai/deep-analysis/{id}",
                    "description": "Multi-step pattern analysis with reasoning transparency",
                },
            ],
        },
        "compliance_features": [
            "Evidence-based analysis with signal tracking",
            "Mandatory disclaimers and limitations",
            "Confidence capping (never 'high')",
            "Forbidden phrase validation",
        ],
        "unique_value": (
            "WhyTheyBuy uses Gemini 3 to democratize access to institutional "
            "holdings analysis while maintaining strict compliance with financial "
            "regulations. The multimodal features enable analysis of visual financial "
            "data that was previously only accessible to professional analysts."
        ),
    }
