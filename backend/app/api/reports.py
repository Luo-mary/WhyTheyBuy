"""Reports API routes."""
import logging
from datetime import date, datetime
from typing import Any
from uuid import UUID
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, func

from app.api.deps import DB, CurrentUser
from app.models.report import Report, ReportType
from app.schemas.report import ReportResponse, ReportListResponse
from app.services.email import send_email

router = APIRouter()
logger = logging.getLogger(__name__)


# =============================================================================
# COMBINED TRANSACTION REPORT
# =============================================================================

class TransactionCard(BaseModel):
    """A single analysis perspective card."""
    perspective: str
    title: str
    key_points: list[str]
    confidence: str
    verdict: str | None = None
    verdict_reasoning: str | None = None
    news_sentiment: str | None = None
    news_summary: str | None = None
    risk_level: str | None = None
    risk_factors: list[str] | None = None
    risk_summary: str | None = None
    bull_points: list[str] | None = None
    bear_points: list[str] | None = None


class TransactionData(BaseModel):
    """Data for a single transaction's analysis."""
    ticker: str
    company_name: str
    change_type: str
    activity_summary: str
    cards: list[TransactionCard]


class CombinedReportRequest(BaseModel):
    """Request to send combined transaction report to email."""
    investor_id: str
    investor_name: str
    tickers: list[str]
    transactions: list[TransactionData]
    language: str = "en"


def _build_combined_report_html(request: CombinedReportRequest) -> str:
    """Build HTML content for combined transaction report email."""
    # Color map for change types
    change_colors = {
        "NEW": "#10B981",
        "ADDED": "#10B981",
        "REDUCED": "#F59E0B",
        "SOLD_OUT": "#EF4444",
    }

    # Color map for perspectives
    perspective_colors = {
        "fundamental": "#3B82F6",
        "news_sentiment": "#EC4899",
        "market_context": "#06B6D4",
        "technical": "#8B5CF6",
        "bull_vs_bear": "#F59E0B",
        "risk_assessment": "#EF4444",
    }

    perspective_titles = {
        "fundamental": "Fundamental Analysis",
        "news_sentiment": "News & Sentiment",
        "market_context": "Market Context",
        "technical": "Technical Analysis",
        "bull_vs_bear": "Investment Debate",
        "risk_assessment": "Risk Assessment",
    }

    # Build ticker chips
    ticker_chips = " ".join([
        f'<span style="display: inline-block; background: rgba(59, 130, 246, 0.1); color: #3B82F6; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: 600; margin-right: 6px;">{ticker}</span>'
        for ticker in request.tickers
    ])

    # Build transactions HTML
    transactions_html = ""
    for txn in request.transactions:
        change_color = change_colors.get(txn.change_type.upper(), "#6B7280")

        # Build cards HTML
        cards_html = ""
        for card in txn.cards:
            card_color = perspective_colors.get(card.perspective, "#6B7280")
            card_title = perspective_titles.get(card.perspective, card.title)

            # Key points
            key_points_html = "".join([
                f'<li style="margin-bottom: 6px;">{point}</li>'
                for point in card.key_points[:5]  # Limit to 5 points
            ])

            # Special sections
            special_html = ""

            # Verdict for bull_vs_bear
            if card.perspective == "bull_vs_bear" and card.verdict:
                verdict_color = {"BULLISH": "#10B981", "BEARISH": "#EF4444", "NEUTRAL": "#F59E0B"}.get(card.verdict.upper(), "#6B7280")
                special_html += f'''
                <div style="background: rgba(0,0,0,0.05); padding: 12px; border-radius: 8px; margin-top: 10px; text-align: center;">
                    <strong style="color: {verdict_color}; font-size: 14px;">VERDICT: {card.verdict}</strong>
                    {f'<p style="margin: 8px 0 0 0; font-size: 12px; color: #6B7280; font-style: italic;">{card.verdict_reasoning}</p>' if card.verdict_reasoning else ''}
                </div>
                '''

            # Risk level for risk_assessment
            if card.perspective == "risk_assessment" and card.risk_level:
                risk_color = {"LOW": "#10B981", "MODERATE": "#F59E0B", "HIGH": "#F97316", "VERY_HIGH": "#EF4444"}.get(card.risk_level.upper(), "#6B7280")
                special_html += f'''
                <div style="background: rgba(239, 68, 68, 0.1); padding: 10px; border-radius: 8px; margin-top: 10px; border-left: 3px solid {risk_color};">
                    <strong style="color: {risk_color}; font-size: 12px;">RISK LEVEL: {card.risk_level.replace('_', ' ')}</strong>
                </div>
                '''

            cards_html += f'''
            <div style="background: #f9fafb; border-radius: 10px; padding: 14px; margin-bottom: 12px; border-left: 3px solid {card_color};">
                <h4 style="margin: 0 0 10px 0; color: {card_color}; font-size: 14px;">{card_title}</h4>
                <ul style="margin: 0; padding-left: 18px; color: #374151; font-size: 13px; line-height: 1.6;">
                    {key_points_html}
                </ul>
                {special_html}
            </div>
            '''

        transactions_html += f'''
        <div style="background: white; border-radius: 12px; padding: 20px; margin-bottom: 20px; border: 1px solid #e5e7eb;">
            <div style="display: flex; align-items: center; margin-bottom: 16px;">
                <span style="background: rgba({int(change_color[1:3], 16)}, {int(change_color[3:5], 16)}, {int(change_color[5:7], 16)}, 0.15); color: {change_color}; padding: 6px 12px; border-radius: 8px; font-weight: 700; font-size: 14px; margin-right: 12px;">{txn.ticker}</span>
                <span style="color: #374151; font-size: 15px; font-weight: 500;">{txn.company_name}</span>
                <span style="background: rgba({int(change_color[1:3], 16)}, {int(change_color[3:5], 16)}, {int(change_color[5:7], 16)}, 0.1); color: {change_color}; padding: 3px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; margin-left: 10px;">{txn.change_type}</span>
            </div>
            <p style="color: #6B7280; font-size: 13px; margin: 0 0 16px 0; line-height: 1.5;">{txn.activity_summary}</p>
            {cards_html}
        </div>
        '''

    html = f'''
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 700px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #0D1117 0%, #161B22 100%); border-radius: 16px; padding: 24px; margin-bottom: 24px;">
            <h1 style="color: #E6EDF3; margin: 0 0 8px 0; font-size: 22px; font-weight: 700;">Combined Analysis Report</h1>
            <p style="color: #8B949E; margin: 0 0 16px 0; font-size: 14px;">{request.investor_name}</p>
            <div>{ticker_chips}</div>
        </div>

        <div style="background: #f0f9ff; border-left: 4px solid #3B82F6; padding: 14px; margin-bottom: 20px; border-radius: 0 8px 8px 0;">
            <p style="margin: 0; color: #1e40af; font-size: 13px;">
                This report combines AI-generated analysis for <strong>{len(request.transactions)} transactions</strong> from {request.investor_name}.
                Each transaction includes 6 perspectives: Fundamental, News & Sentiment, Market Context, Technical, Investment Debate, and Risk Assessment.
            </p>
        </div>

        {transactions_html}

        <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 0 8px 8px 0; margin-top: 20px;">
            <p style="margin: 0; color: #92400e; font-size: 12px; font-weight: 600;">EDUCATIONAL USE ONLY</p>
            <p style="margin: 8px 0 0 0; color: #92400e; font-size: 12px; line-height: 1.5;">
                This report is AI-generated for educational purposes only. It does NOT constitute investment advice.
                All analyses are hypothetical and based on publicly available information.
            </p>
        </div>
    </div>
    '''
    return html


@router.post("/combined-transaction-report")
async def send_combined_transaction_report(
    request: CombinedReportRequest,
    user: CurrentUser,
    db: DB,
):
    """Send combined transaction report to user's email."""
    if not user.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No email address on file",
        )

    if not request.transactions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No transactions provided",
        )

    try:
        # Check if SendGrid is configured before attempting to send
        from app.config import settings
        if not settings.sendgrid_api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Email service is not configured. Please contact support or try again later.",
            )

        # Build email content
        html_content = _build_combined_report_html(request)

        subject = f"Combined Analysis Report: {request.investor_name} - {', '.join(request.tickers[:3])}"
        if len(request.tickers) > 3:
            subject += f" +{len(request.tickers) - 3} more"

        # Send email
        success = await send_email(
            to_email=user.email,
            subject=subject,
            html_content=html_content,
            include_disclaimer=True,
        )

        if not success:
            logger.error(f"SendGrid send_email returned False for {user.email}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Email service configuration error. The administrator needs to verify the sender email in SendGrid.",
            )

        logger.info(f"Sent combined report to {user.email} for {len(request.transactions)} transactions")
        return {"message": "Report sent successfully", "email": user.email}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending combined report: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate report",
        )


@router.get("", response_model=ReportListResponse)
async def list_reports(
    user: CurrentUser,
    db: DB,
    report_type: ReportType | None = None,
    investor_id: UUID | None = None,
    unread_only: bool = False,
    skip: int = 0,
    limit: int = 20,
):
    """List user's reports."""
    query = select(Report).where(Report.user_id == user.id)
    
    if report_type:
        query = query.where(Report.report_type == report_type)
    
    if investor_id:
        query = query.where(Report.investor_id == investor_id)
    
    if unread_only:
        query = query.where(Report.is_read == False)
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = await db.scalar(count_query)
    
    # Get paginated results
    query = query.order_by(Report.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    reports = result.scalars().all()
    
    return ReportListResponse(reports=reports, total=total)


@router.get("/unread-count")
async def get_unread_count(user: CurrentUser, db: DB):
    """Get count of unread reports."""
    count = await db.scalar(
        select(func.count())
        .select_from(Report)
        .where(Report.user_id == user.id, Report.is_read == False)
    )
    return {"unread_count": count or 0}


@router.get("/{report_id}", response_model=ReportResponse)
async def get_report(report_id: UUID, user: CurrentUser, db: DB):
    """Get a specific report."""
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.user_id == user.id)
    )
    report = result.scalar_one_or_none()
    
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )
    
    # Mark as read
    if not report.is_read:
        report.is_read = True
        report.read_at = datetime.utcnow()
        await db.commit()
        await db.refresh(report)
    
    return report


@router.post("/{report_id}/mark-read")
async def mark_report_read(report_id: UUID, user: CurrentUser, db: DB):
    """Mark a report as read."""
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.user_id == user.id)
    )
    report = result.scalar_one_or_none()
    
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )
    
    report.is_read = True
    report.read_at = datetime.utcnow()
    await db.commit()
    
    return {"message": "Report marked as read"}


@router.post("/mark-all-read")
async def mark_all_reports_read(user: CurrentUser, db: DB):
    """Mark all reports as read."""
    result = await db.execute(
        select(Report).where(Report.user_id == user.id, Report.is_read == False)
    )
    reports = result.scalars().all()
    
    now = datetime.utcnow()
    for report in reports:
        report.is_read = True
        report.read_at = now
    
    await db.commit()
    
    return {"message": f"Marked {len(reports)} reports as read"}


@router.delete("/{report_id}")
async def delete_report(report_id: UUID, user: CurrentUser, db: DB):
    """Delete a report."""
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.user_id == user.id)
    )
    report = result.scalar_one_or_none()
    
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )
    
    await db.delete(report)
    await db.commit()
    
    return {"message": "Report deleted"}
