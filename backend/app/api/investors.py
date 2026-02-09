"""
Investors API routes - Generic investor support.

This module supports ANY investor or institution, not limited to ARK or 13F filers.
The system abstracts over different public disclosure mechanisms.
"""
from datetime import date, timedelta
from uuid import UUID
from fastapi import APIRouter, HTTPException, status, Query
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.api.deps import DB, OptionalUser
from app.models.investor import (
    Investor,
    DisclosureSource,
    StrategyNote,
    InvestorType,
    DisclosureSourceType,
    DataGranularity,
    TransparencyLabel,
    TransparencyScorer,
)
from app.models.holdings import HoldingsSnapshot, HoldingsChange, InvestorAction, HoldingRecord
from app.schemas.investor import (
    InvestorResponse,
    InvestorListResponse,
    InvestorDetailResponse,
    InvestorCardResponse,
    DisclosureSourceResponse,
    DisclosureSourceSummary,
    StrategyNoteResponse,
    InvestorFilterParams,
    TransparencyInfo,
    TransparencyScoreBreakdown,
    TransparencyLabelsResponse,
    TRANSPARENCY_DISCLAIMER,
    get_investor_type_info,
    get_disclosure_type_info,
    get_transparency_label_info,
)
from app.schemas.holdings import (
    HoldingsSnapshotResponse,
    HoldingsChangeResponse,
    InvestorActionResponse,
    HoldingsChangesListResponse,
    InvestorActionsListResponse,
    HoldingRecordResponse,
)
from app.services.disclosure import DisclosureService

router = APIRouter()
disclosure_service = DisclosureService()


def _investor_filter(investor_id: str):
    """Build SQLAlchemy filter for investor by UUID or slug."""
    try:
        uid = UUID(investor_id)
        return Investor.id == uid
    except (ValueError, AttributeError):
        return Investor.slug == investor_id


async def _resolve_investor_uuid(investor_id: str, db) -> UUID:
    """Resolve investor_id (UUID or slug) to a UUID. Raises 404 if not found."""
    try:
        return UUID(investor_id)
    except (ValueError, AttributeError):
        pass
    # Slug lookup
    result = await db.execute(
        select(Investor.id).where(Investor.slug == investor_id, Investor.is_active == True)
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )
    return row


# =============================================================================
# INVESTOR LISTING AND SEARCH
# =============================================================================

@router.get("", response_model=InvestorListResponse)
async def list_investors(
    db: DB,
    investor_type: InvestorType | None = None,
    disclosure_type: DisclosureSourceType | None = None,
    update_frequency: DataGranularity | None = None,
    min_confidence: int | None = None,
    featured_only: bool = False,
    search: str | None = None,
    skip: int = 0,
    limit: int = 50,
):
    """
    List all investors with filtering.
    
    Supports filtering by:
    - investor_type: ETF Manager, Hedge Fund, Individual, etc.
    - disclosure_type: ETF Holdings, SEC 13F, etc.
    - update_frequency: Daily, Quarterly, etc.
    - min_confidence: Minimum data confidence score (0-100)
    - featured_only: Only show featured investors
    - search: Search by name
    """
    query = (
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.is_active == True)
    )
    
    if investor_type:
        query = query.where(Investor.investor_type == investor_type)
    
    if update_frequency:
        query = query.where(Investor.expected_update_frequency == update_frequency)
    
    if min_confidence:
        query = query.where(Investor.data_confidence_score >= min_confidence)
    
    if featured_only:
        query = query.where(Investor.is_featured == True)
    
    if search:
        query = query.where(
            Investor.name.ilike(f"%{search}%") | 
            Investor.short_name.ilike(f"%{search}%")
        )
    
    # Filter by disclosure type (requires join)
    if disclosure_type:
        query = query.join(DisclosureSource).where(
            DisclosureSource.source_type == disclosure_type,
            DisclosureSource.is_primary == True,
        )
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = await db.scalar(count_query)
    
    # Get paginated results (featured first, then by name)
    query = (
        query
        .order_by(Investor.is_featured.desc(), Investor.name)
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    investors = result.scalars().unique().all()
    
    return InvestorListResponse(investors=investors, total=total)


@router.get("/types")
async def get_investor_types():
    """
    Get all supported investor types with descriptions.
    
    Helps users understand what kinds of investors can be monitored.
    """
    return {
        "types": get_investor_type_info(),
        "description": (
            "WhyTheyBuy supports monitoring ANY notable investor or institution "
            "with public disclosure mechanisms. This includes but is not limited to "
            "ETF managers, hedge funds, pension funds, and individual investors."
        ),
    }


@router.get("/disclosure-types")
async def get_disclosure_types():
    """
    Get all supported disclosure types with descriptions.
    
    Helps users understand data availability and limitations.
    """
    return {
        "types": get_disclosure_type_info(),
        "description": (
            "Different investors have different disclosure mechanisms. "
            "The frequency, delay, and completeness of data varies by source type."
        ),
    }


@router.get("/transparency-info", response_model=TransparencyLabelsResponse)
async def get_transparency_info():
    """
    Get information about transparency scoring.
    
    IMPORTANT: Transparency reflects disclosure characteristics, NOT performance
    or investment quality. This score should NOT be used to rank investors.
    
    The transparency score (0-100) is computed from four components:
    - Disclosure Frequency (0-25)
    - Reporting Delay (0-25)
    - Data Granularity (0-25)
    - Source Reliability (0-25)
    """
    return TransparencyLabelsResponse(
        labels=get_transparency_label_info(),
    )


@router.get("/featured")
async def get_featured_investors(db: DB, limit: int = 10):
    """
    Get featured investors for homepage display.
    
    Returns a mix of different investor types to showcase diversity.
    """
    result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.is_active == True, Investor.is_featured == True)
        .order_by(Investor.name)
        .limit(limit)
    )
    investors = result.scalars().all()
    
    # Build card responses with disclosure summaries
    cards = []
    for investor in investors:
        primary = investor.get_primary_disclosure()
        primary_summary = None
        if primary:
            primary_summary = DisclosureSourceSummary(
                source_type=primary.source_type,
                source_name=primary.source_name,
                data_granularity=primary.data_granularity,
                known_limitations=primary.known_limitations or [],
            )
        
        cards.append(InvestorCardResponse(
            id=investor.id,
            name=investor.name,
            slug=investor.slug,
            short_name=investor.short_name,
            investor_type=investor.investor_type,
            update_frequency=investor.expected_update_frequency,
            data_confidence_score=investor.data_confidence_score,
            primary_disclosure=primary_summary,
            logo_url=investor.logo_url,
            is_featured=investor.is_featured,
            last_change_detected=investor.last_change_detected,
        ))
    
    return {"investors": cards}


# =============================================================================
# INVESTOR DETAILS
# =============================================================================

@router.get("/{investor_id}", response_model=InvestorDetailResponse)
async def get_investor(investor_id: str, db: DB):
    """
    Get detailed investor information.
    Accepts UUID or slug as investor_id.

    Returns:
    - Full investor profile
    - All disclosure sources with limitations
    - Data confidence indicators
    - Recent statistics
    """
    result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(_investor_filter(investor_id), Investor.is_active == True)
    )
    investor = result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )

    # Get additional stats
    snapshot_result = await db.execute(
        select(HoldingsSnapshot)
        .where(HoldingsSnapshot.investor_id == investor.id)
        .order_by(HoldingsSnapshot.snapshot_date.desc())
        .limit(1)
    )
    latest_snapshot = snapshot_result.scalar_one_or_none()
    
    # Changes count in last 30 days
    thirty_days_ago = date.today() - timedelta(days=30)
    changes_count = await db.scalar(
        select(func.count())
        .select_from(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor.id,
            HoldingsChange.to_date >= thirty_days_ago
        )
    )

    # For quarterly filers, get the latest filing date range and count of changes in that filing
    latest_filing_from = None
    latest_filing_to = None
    latest_filing_changes_count = None

    if latest_snapshot and investor.expected_update_frequency == DataGranularity.QUARTERLY:
        # Get the earliest change date that matches this snapshot's to_date
        latest_changes_result = await db.execute(
            select(func.min(HoldingsChange.from_date), func.max(HoldingsChange.to_date), func.count())
            .where(
                HoldingsChange.investor_id == investor.id,
                HoldingsChange.to_date == latest_snapshot.snapshot_date
            )
        )
        filing_row = latest_changes_result.one_or_none()
        if filing_row and filing_row[0]:
            latest_filing_from = str(filing_row[0])
            latest_filing_to = str(filing_row[1]) if filing_row[1] else str(latest_snapshot.snapshot_date)
            latest_filing_changes_count = filing_row[2] or 0
    
    # Get primary disclosure info
    primary = investor.get_primary_disclosure()
    primary_disclosure_type = primary.source_type if primary else None
    
    # Build limitations summary
    limitations = []
    for source in investor.disclosure_sources:
        if source.known_limitations:
            limitations.extend(source.known_limitations)
    data_limitations_summary = "; ".join(set(limitations)) if limitations else None
    
    # Build disclosure source responses
    disclosure_responses = [
        DisclosureSourceResponse(
            id=s.id,
            source_type=s.source_type,
            source_name=s.source_name,
            is_primary=s.is_primary,
            data_granularity=s.data_granularity,
            reporting_delay_days=s.reporting_delay_days,
            available_fields=s.available_fields or [],
            known_limitations=s.known_limitations or [],
            is_active=s.is_active,
            last_fetch_at=s.last_fetch_at,
            last_fetch_success=s.last_fetch_success,
        )
        for s in investor.disclosure_sources
    ]
    
    return InvestorDetailResponse(
        id=investor.id,
        name=investor.name,
        slug=investor.slug,
        short_name=investor.short_name,
        description=investor.description,
        investor_type=investor.investor_type,
        expected_update_frequency=investor.expected_update_frequency,
        typical_reporting_delay_days=investor.typical_reporting_delay_days,
        supported_features=investor.supported_features or [],
        supported_alert_frequencies=investor.supported_alert_frequencies or [],
        logo_url=investor.logo_url,
        website_url=investor.website_url,
        aum_billions=investor.aum_billions,
        is_active=investor.is_active,
        is_featured=investor.is_featured,
        last_data_fetch=investor.last_data_fetch,
        last_change_detected=investor.last_change_detected,
        data_confidence_score=investor.data_confidence_score,
        disclosure_sources=disclosure_responses,
        total_holdings=latest_snapshot.total_positions if latest_snapshot else None,
        latest_snapshot_date=str(latest_snapshot.snapshot_date) if latest_snapshot else None,
        changes_count_30d=changes_count or 0,
        # For quarterly filers: include latest filing date range and changes count
        latest_filing_from=latest_filing_from,
        latest_filing_to=latest_filing_to,
        latest_filing_changes_count=latest_filing_changes_count,
        primary_disclosure_type=primary_disclosure_type,
        data_limitations_summary=data_limitations_summary,
    )


@router.get("/{investor_id}/disclosure-info")
async def get_investor_disclosure_info(investor_id: UUID, db: DB):
    """
    Get detailed disclosure information for an investor.
    
    Provides transparency about:
    - What disclosure sources are available
    - How often updates are expected
    - What kind of insights can be generated
    - Known limitations of the data
    """
    result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_id, Investor.is_active == True)
    )
    investor = result.scalar_one_or_none()
    
    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )
    
    return disclosure_service.get_disclosure_summary(investor)


@router.get("/{investor_id}/transparency", response_model=TransparencyInfo)
async def get_investor_transparency(investor_id: UUID, db: DB):
    """
    Get detailed transparency information for an investor.
    
    IMPORTANT DISCLAIMER:
    Transparency reflects disclosure characteristics, NOT performance or quality.
    This score should NOT be used to rank investors or imply investment quality.
    
    Returns:
    - Transparency score (0-100)
    - Label (High/Medium/Low)
    - Explanation of the score
    - Score breakdown by component
    """
    result = await db.execute(
        select(Investor)
        .where(Investor.id == investor_id, Investor.is_active == True)
    )
    investor = result.scalar_one_or_none()
    
    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )
    
    # Compute score breakdown
    frequency_score = TransparencyScorer.FREQUENCY_SCORES.get(
        investor.expected_update_frequency, 5
    )
    delay_score = TransparencyScorer.compute_delay_score(
        investor.typical_reporting_delay_days
    )
    granularity_score = TransparencyScorer.GRANULARITY_LEVEL_SCORES.get(
        investor.data_granularity_level, 15
    )
    reliability_score = TransparencyScorer.RELIABILITY_SCORES.get(
        investor.source_reliability, 15
    )
    
    total_score = investor.transparency_score or (
        frequency_score + delay_score + granularity_score + reliability_score
    )
    label = investor.transparency_label or TransparencyLabel.MEDIUM
    explanation = investor.transparency_explanation or ""
    
    breakdown = TransparencyScoreBreakdown(
        frequency_score=frequency_score,
        delay_score=delay_score,
        granularity_score=granularity_score,
        reliability_score=reliability_score,
        total_score=total_score,
        frequency_explanation=f"Disclosure frequency: {investor.expected_update_frequency.value}",
        delay_explanation=f"Typical reporting delay: {investor.typical_reporting_delay_days or 0} days",
        granularity_explanation=f"Data granularity: {investor.data_granularity_level.value if investor.data_granularity_level else 'position_level'}",
        reliability_explanation=f"Source reliability: {investor.source_reliability.value if investor.source_reliability else 'official_regulatory'}",
    )
    
    return TransparencyInfo(
        score=total_score,
        label=label,
        label_description=TransparencyScorer.get_label_description(label),
        explanation=explanation,
        breakdown=breakdown,
    )


# =============================================================================
# HOLDINGS AND CHANGES
# =============================================================================

@router.get("/{investor_id}/holdings", response_model=HoldingsSnapshotResponse)
async def get_investor_holdings(
    investor_id: str,
    db: DB,
    snapshot_date: date | None = None,
):
    """Get investor's current or historical holdings.

    For 13F filings, multiple entries for the same company (same CUSIP)
    are aggregated into a single record.  Weight percentages are computed
    from market values when not already present.  Records are returned
    sorted by market value descending. Includes sector allocation and
    top holdings changes.
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)
    query = (
        select(HoldingsSnapshot)
        .options(selectinload(HoldingsSnapshot.records))
        .where(HoldingsSnapshot.investor_id == investor_uuid)
    )

    if snapshot_date:
        query = query.where(HoldingsSnapshot.snapshot_date == snapshot_date)
    else:
        query = query.order_by(HoldingsSnapshot.snapshot_date.desc())

    query = query.limit(1)
    result = await db.execute(query)
    snapshot = result.scalar_one_or_none()

    if not snapshot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Holdings snapshot not found",
        )

    # --- Aggregate duplicate CUSIPs and compute weights ---
    records = snapshot.records or []

    # Group by CUSIP (or company_name if CUSIP missing)
    from collections import defaultdict
    from decimal import Decimal as D

    grouped: dict[str, dict] = {}
    for r in records:
        key = r.cusip or r.company_name or r.ticker or str(r.id)
        if key in grouped:
            g = grouped[key]
            g["shares"] = (g["shares"] or D(0)) + (r.shares or D(0))
            g["market_value"] = (g["market_value"] or D(0)) + (r.market_value or D(0))
        else:
            grouped[key] = {
                "id": str(r.id),
                "ticker": r.ticker or "",
                "company_name": r.company_name or "",
                "cusip": r.cusip or "",
                "shares": r.shares,
                "market_value": r.market_value,
                "weight_percent": r.weight_percent,
                "share_price": r.share_price,
            }

    # Compute weight_percent from market_value if missing
    total_mv = sum(
        g["market_value"] for g in grouped.values() if g["market_value"]
    ) or D(1)
    for g in grouped.values():
        if g["weight_percent"] is None and g["market_value"]:
            g["weight_percent"] = round(g["market_value"] / total_mv * 100, 2)

    # Sort by market_value descending
    agg_records = sorted(
        grouped.values(),
        key=lambda x: float(x["market_value"] or 0),
        reverse=True,
    )

    # --- Compute sector allocation ---
    sector_map: dict[str, dict] = {}
    for r in agg_records:
        # For now, sector is not in aggregated records, need to look at original records
        pass
    
    # Recompute sector allocation from original records with sector info
    for r in records:
        sector = r.sector or "Unknown"
        if sector not in sector_map:
            sector_map[sector] = {"weight": D(0), "count": 0}
        sector_map[sector]["weight"] += r.weight_percent or D(0)
        sector_map[sector]["count"] += 1
    
    sector_allocation = None
    if sector_map:
        sector_allocation = [
            {
                "sector": sector,
                "weight_percent": float(round(data["weight"], 2)),
                "num_positions": data["count"]
            }
            for sector, data in sorted(
                sector_map.items(),
                key=lambda x: float(x[1]["weight"]),
                reverse=True
            )
        ]

    # --- Get top holdings changes ---
    top_changes = None
    try:
        from app.models.holdings import HoldingsChange
        changes_result = await db.execute(
            select(HoldingsChange)
            .where(HoldingsChange.investor_id == investor_uuid)
            .order_by(HoldingsChange.to_date.desc(), HoldingsChange.value_delta.desc())
            .limit(5)
        )
        top_changes = changes_result.scalars().all()
    except:
        pass

    return {
        "id": str(snapshot.id),
        "investor_id": str(snapshot.investor_id),
        "snapshot_date": snapshot.snapshot_date,
        "filing_date": snapshot.filing_date,
        "period_end_date": snapshot.period_end_date,
        "total_positions": len(agg_records),
        "total_value": snapshot.total_value,
        "records": agg_records,
        "sector_allocation": sector_allocation,
        "top_changes": top_changes,
    }


@router.get("/{investor_id}/holdings/dates")
async def get_holdings_dates(investor_id: str, db: DB):
    """Get available holdings snapshot dates."""
    investor_uuid = await _resolve_investor_uuid(investor_id, db)
    result = await db.execute(
        select(HoldingsSnapshot.snapshot_date, HoldingsSnapshot.filing_date)
        .where(HoldingsSnapshot.investor_id == investor_uuid)
        .order_by(HoldingsSnapshot.snapshot_date.desc())
        .limit(100)
    )
    dates = result.all()
    
    return {
        "dates": [
            {
                "snapshot_date": str(d.snapshot_date),
                "filing_date": str(d.filing_date) if d.filing_date else None,
            }
            for d in dates
        ]
    }


@router.get("/{investor_id}/holdings/ai-analysis")
async def get_holdings_ai_analysis(
    investor_id: str,
    db: DB,
    limit: int = 5,
):
    """Get AI-generated analysis for investor's holdings.
    
    Returns AI-generated reports for top holdings including:
    - Sector classification
    - Investment rationale (fundamental, technical, sentiment, news factors)
    - Risk factors
    - Confidence scores
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)
    
    try:
        from app.models.report import AICompanyReport
        
        result = await db.execute(
            select(AICompanyReport)
            .where(AICompanyReport.investor_id == investor_uuid)
            .order_by(AICompanyReport.generated_at.desc())
            .limit(limit)
        )
        reports = result.scalars().all()
        
        return {
            "investor_id": str(investor_uuid),
            "reports": [
                {
                    "ticker": r.ticker,
                    "analysis": r.json_payload,
                    "generated_at": r.generated_at.isoformat(),
                }
                for r in reports
            ],
        }
    except Exception as e:
        return {
            "investor_id": str(investor_uuid),
            "reports": [],
            "error": str(e),
        }


@router.get("/{investor_id}/portfolio-overview")
async def get_portfolio_overview(
    investor_id: str,
    db: DB,
    days: int = 30,
):
    """
    Portfolio overview: sector/industry breakdown from latest holdings
    snapshot plus a summary of recent changes.

    Returns data suitable for rendering a horizontal bar chart of sector
    weights and a brief textual summary of recent activity.
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)

    # --- Latest snapshot with records ---
    snap_result = await db.execute(
        select(HoldingsSnapshot)
        .options(selectinload(HoldingsSnapshot.records))
        .where(HoldingsSnapshot.investor_id == investor_uuid)
        .order_by(HoldingsSnapshot.snapshot_date.desc())
        .limit(1)
    )
    snapshot = snap_result.scalar_one_or_none()

    sector_breakdown: list[dict] = []
    snapshot_date = None
    total_positions = 0

    if snapshot and snapshot.records:
        snapshot_date = str(snapshot.snapshot_date)
        total_positions = snapshot.total_positions or len(snapshot.records)

        # Try company table first, fall back to ticker-based classification
        from app.models.company import Company
        ticker_set = {r.ticker for r in snapshot.records if r.ticker}
        company_result = await db.execute(
            select(Company.ticker, Company.sector, Company.industry)
            .where(Company.ticker.in_(ticker_set))
        )
        sector_map: dict[str, str] = {}
        for row in company_result.all():
            if row.sector:
                sector_map[row.ticker] = row.sector

        # For tickers not in company table, use a built-in mapping
        sector_breakdown = _compute_sector_breakdown(snapshot.records, sector_map)

    # --- Recent changes ---
    # Check if investor has daily exposure
    from app.models.investor import DataGranularity
    investor_result = await db.execute(
        select(Investor).where(Investor.id == investor_uuid)
    )
    investor = investor_result.scalar_one_or_none()
    is_daily = investor and investor.expected_update_frequency == DataGranularity.DAILY

    if is_daily:
        # For daily investors (ARK), get last 7 days of changes grouped by day
        week_ago = date.today() - timedelta(days=7)
        changes_result = await db.execute(
            select(HoldingsChange)
            .where(
                HoldingsChange.investor_id == investor_uuid,
                HoldingsChange.to_date >= week_ago,
            )
            .order_by(HoldingsChange.to_date.desc(), func.abs(HoldingsChange.shares_delta).desc().nullslast())
        )
        changes = changes_result.scalars().all()
        changes_summary = _summarize_changes_by_day(changes, top_n=5)
    else:
        # For non-daily investors (13F), no changes (holdings only)
        changes_summary = {
            "total": 0,
            "buys": [],
            "sells": [],
            "summary_text": "Holdings only - no daily trade data available.",
            "date": None,
        }

    return {
        "snapshot_date": snapshot_date,
        "total_positions": total_positions,
        "sector_breakdown": sector_breakdown,
        "recent_changes": changes_summary,
    }


# Well-known ticker -> sector mapping for common holdings
_TICKER_SECTOR: dict[str, str] = {
    # Technology
    "AAPL": "Technology", "MSFT": "Technology", "GOOG": "Technology",
    "GOOGL": "Technology", "META": "Technology", "AMZN": "Technology",
    "NVDA": "Technology", "TSM": "Technology", "AVGO": "Technology",
    "AMD": "Technology", "PLTR": "Technology", "SHOP": "Technology",
    "COIN": "Technology", "HOOD": "Technology", "TTD": "Technology",
    "RBLX": "Technology", "SOFI": "Technology", "CRWV": "Technology",
    "ROKU": "Technology", "PD": "Technology", "PATH": "Technology",
    # Crypto / Blockchain
    "COIN": "Crypto & Blockchain", "CRCL": "Crypto & Blockchain",
    "BLSH": "Crypto & Blockchain", "BMNR": "Crypto & Blockchain",
    # Healthcare / Biotech
    "CRSP": "Healthcare", "BEAM": "Healthcare", "NTLA": "Healthcare",
    "ILMN": "Healthcare", "TEM": "Healthcare", "TWST": "Healthcare",
    "TXG": "Healthcare", "RXRX": "Healthcare", "NTRA": "Healthcare",
    "VCYT": "Healthcare", "PACB": "Healthcare", "WGS": "Healthcare",
    "GH": "Healthcare", "PSNL": "Healthcare", "CDNA": "Healthcare",
    "ADPT": "Healthcare", "ABSI": "Healthcare", "IONS": "Healthcare",
    "SDGR": "Healthcare", "NRIX": "Healthcare", "BFLY": "Healthcare",
    "PRME": "Healthcare", "CMPS": "Healthcare", "INCY": "Healthcare",
    "AMGN": "Healthcare", "VRTX": "Healthcare", "VEEV": "Healthcare",
    "QSI": "Healthcare", "MASS": "Healthcare", "CAI": "Healthcare",
    "LAB": "Healthcare", "CERS": "Healthcare",
    "ARCT UQ": "Healthcare", "ATAI UQ": "Healthcare",
    "UNH": "Healthcare", "JNJ": "Healthcare", "LLY": "Healthcare",
    "PFE": "Healthcare", "MRK": "Healthcare", "ABBV": "Healthcare",
    # Automotive / EV
    "TSLA": "Automotive & EV",
    # Aerospace & Defense
    "ACHR": "Aerospace & Defense", "KTOS": "Aerospace & Defense",
    "BWXT": "Aerospace & Defense", "RKLB": "Aerospace & Defense",
    # Industrial
    "TER": "Industrials", "DE": "Industrials",
    # Consumer
    "ABNB": "Consumer", "DKNG UW": "Consumer", "DKNG": "Consumer",
    "KO": "Consumer", "PG": "Consumer", "WMT": "Consumer",
    "COST": "Consumer",
    # Financials
    "V": "Financials", "MA": "Financials", "AXP": "Financials",
    "BAC": "Financials", "JPM": "Financials", "GS": "Financials",
    "WFC": "Financials", "C": "Financials", "BLK": "Financials",
    "MCO": "Financials", "ALLY FINL INC": "Financials",
    # Chinese Tech
    "BIDU": "Technology", "BABA": "Technology",
    # Telecom / Media
    "XYZ": "Technology",  # Block Inc (formerly SQ)
    # Energy
    "OXY": "Energy", "CVX": "Energy",
}

# CUSIP-based company name -> sector for 13F data
_COMPANY_SECTOR: dict[str, str] = {
    "APPLE INC": "Technology",
    "AMAZON COM INC": "Technology",
    "ALPHABET INC": "Technology",
    "BANK AMER CORP": "Financials",
    "AMERICAN EXPRESS CO": "Financials",
    "COCA COLA CO": "Consumer",
    "CHEVRON CORP NEW": "Energy",
    "KRAFT HEINZ CO": "Consumer",
    "OCCIDENTAL PETE CORP": "Energy",
    "MOODYS CORP": "Financials",
    "CAPITAL ONE FINL CORP": "Financials",
    "VISA INC": "Financials",
    "MASTERCARD INC": "Financials",
    "DAVITA INC": "Healthcare",
    "UNITEDHEALTH GROUP INC": "Healthcare",
    "VERISIGN INC": "Technology",
    "CHARTER COMMUNICATIONS INC N": "Telecom",
    "DOMINOS PIZZA INC": "Consumer",
    "KROGER CO": "Consumer",
    "NVR INC": "Real Estate",
    "NUCOR CORP": "Industrials",
    "SIRIUS XM HOLDINGS INC": "Telecom",
    "CONSTELLATION BRANDS INC": "Consumer",
    "POOL CORP": "Consumer",
    "CHUBB LIMITED": "Financials",
    "LENNAR CORP": "Real Estate",
    "AON PLC": "Financials",
    "ALLEGION PLC": "Industrials",
    "HEICO CORP NEW": "Industrials",
    "JEFFERIES FINL GROUP INC": "Financials",
    "DEERE & CO": "Industrials",
    "LOUISIANA PAC CORP": "Industrials",
    "LAMAR ADVERTISING CO NEW": "Real Estate",
    "ATLANTA BRAVES HLDGS INC": "Consumer",
    "DIAGEO P L C": "Consumer",
    "LIBERTY MEDIA CORP DEL": "Telecom",
    "LIBERTY LATIN AMERICA LTD": "Telecom",
    "HILTON WORLDWIDE HLDGS INC": "Consumer",
    "CHIPOTLE MEXICAN GRILL INC": "Consumer",
    "RESTAURANT BRANDS INTL INC": "Consumer",
    "HOWARD HUGHES HOLDINGS INC": "Real Estate",
    "BROOKFIELD CORP": "Financials",
    "HERTZ GLOBAL HLDGS INC": "Industrials",
    "SEAPORT ENTMT GROUP INC": "Consumer",
    "UBER TECHNOLOGIES INC": "Technology",
    # Bridgewater/RenTech common names
    "MICROSOFT CORP": "Technology",
    "NVIDIA CORP": "Technology",
    "TESLA INC": "Automotive & EV",
    "BROADCOM INC": "Technology",
    "META PLATFORMS INC": "Technology",
    "APPLE INC": "Technology",
    "EXXON MOBIL CORP": "Energy",
    "PROCTER AND GAMBLE CO": "Consumer",
    "JOHNSON AND JOHNSON": "Healthcare",
    "JPMORGAN CHASE & CO": "Financials",
    "BERKSHIRE HATHAWAY": "Financials",
    "ELI LILLY & CO": "Healthcare",
    "WALMART INC": "Consumer",
    "HOME DEPOT INC": "Consumer",
    "COSTCO WHOLESALE CORP": "Consumer",
    "ABBVIE INC": "Healthcare",
    "SALESFORCE INC": "Technology",
    "CISCO SYS INC": "Technology",
    "PFIZER INC": "Healthcare",
    "THERMO FISHER SCIENTIFIC INC": "Healthcare",
    "NEXTERA ENERGY INC": "Energy",
    "CATERPILLAR INC": "Industrials",
    "UNION PAC CORP": "Industrials",
    "BOEING CO": "Industrials",
    "INTEL CORP": "Technology",
    "INTL BUSINESS MACHINES CORP": "Technology",
    "ORACLE CORP": "Technology",
    "ADOBE INC": "Technology",
    "NETFLIX INC": "Technology",
    "PAYPAL HLDGS INC": "Technology",
    "STARBUCKS CORP": "Consumer",
    "MCDONALDS CORP": "Consumer",
    "WALT DISNEY CO": "Consumer",
    "PEPSICO INC": "Consumer",
    "PHILIP MORRIS INTL INC": "Consumer",
    "MONDELEZ INTL INC": "Consumer",
    "COLGATE-PALMOLIVE CO": "Consumer",
    "GENERAL ELECTRIC CO": "Industrials",
    "HONEYWELL INTL INC": "Industrials",
    "RAYTHEON CO": "Aerospace & Defense",
    "RTX CORP": "Aerospace & Defense",
    "LOCKHEED MARTIN CORP": "Aerospace & Defense",
    "GENERAL DYNAMICS CORP": "Aerospace & Defense",
    "NORTHROP GRUMMAN CORP": "Aerospace & Defense",
    "GOLDMAN SACHS GROUP INC": "Financials",
    "MORGAN STANLEY": "Financials",
    "WELLS FARGO & CO NEW": "Financials",
    "CITIGROUP INC": "Financials",
    "BLACKROCK INC": "Financials",
    "S&P GLOBAL INC": "Financials",
    "CHARLES SCHWAB CORP": "Financials",
    "PROGRESSIVE CORP": "Financials",
    "MARSH & MCLENNAN COS INC": "Financials",
    "TRAVELERS COS INC": "Financials",
    "DUKE ENERGY CORP NEW": "Energy",
    "SOUTHERN CO": "Energy",
    "SEMPRA": "Energy",
    "CONOCOPHILLIPS": "Energy",
    "SCHLUMBERGER LTD": "Energy",
    "LINDE PLC": "Industrials",
    "ACCENTURE PLC IRELAND": "Technology",
    "AUTOMATIC DATA PROCESSING": "Technology",
    "APPLIED MATLS INC": "Technology",
    "QUALCOMM INC": "Technology",
    "TEXAS INSTRUMENTS INC": "Technology",
    "ADVANCED MICRO DEVICES INC": "Technology",
    "MICRON TECHNOLOGY INC": "Technology",
}


_KEYWORD_SECTOR: list[tuple[list[str], str]] = [
    # Financials
    (["BANCORP", "BANCSHARES", "BANCSHS", "BANK ", " BANK", "FINL ", "FINANCIAL",
     "CAPITAL GRP", "CAPITAL ONE", "GOLDMAN", "MORGAN STANLEY", "SCHWAB",
     "INSURANCE", "ASSURANCE", "FIDELITY", "ASSET MGMT", "INVT CORP",
     "CREDIT", "LENDING", "EXCHANGE", "BROKERAGE"], "Financials"),
    # Healthcare / Biotech / Pharma
    (["PHARMA", "THERAPEUT", "BIOSCIEN", "BIOTECH", "MEDICAL", "HEALTH",
     "GENOMIC", "ONCOL", "SURGICAL", "DIAGNOSTICS", "BIOLOG", "LABS INC",
     "HOSPITAL", "VACCINE", "MEDTRONIC", "ABBOTT", "STRYKER", "BAXTER",
     "DANAHER", "BECTON", "EDWARDS LIFE", "INTUITIVE SURG", "MOLINA",
     "CENTENE", "HUMANA", "CIGNA", "AETNA", "REGENERON", "GILEAD",
     "AMGEN", "VERTEX", "ILLUMINA"], "Healthcare"),
    # Technology
    (["SOFTWARE", "SEMICOND", "MICROSYS", "TECHNOLOG", "DIGITAL",
     "CYBER", "CLOUD", "DATA ", "SYSTEMS INC", "COMPUTING",
     "INTERNET", " TECH", "MICROCHIP", "MICRON", "SYNOPSYS",
     "CADENCE", "PALANTIR", "SERVICENOW", "WORKDAY", "SNOWFLAKE",
     "CROWDSTRIKE", "FORTINET", "PALO ALTO", "VERISIGN", "AUTODESK",
     "ATLASSIAN", "TWILIO", "SPLUNK", "ELASTIC", "MONGODB",
     "INFORMATICA", "CERIDIAN", "PAYCOM", "HUBSPOT"], "Technology"),
    # Energy
    (["ENERGY", "PETROL", "CRUDE", "OIL ", "GAS CO", "PIPELINE",
     "DRILLING", "MINING", "MINERAL", "RESOURCES INC", "SOLAR",
     "NATURAL GAS", "EXXON", "CHEVRON", "CONOCOPH", "SCHLUM",
     "HALLIBURTON", "PIONEER NATL", "WILLIAMS COS", "KINDER MORGAN",
     "VALERO", "MARATHON OIL", "MARATHON PETE", "PHILLIPS 66",
     "DEVON ENERGY", "COTERRA", "DIAMONDBACK", "HESS CORP"], "Energy"),
    # Industrials
    (["INDUSTRIAL", "MANUFACT", "AEROSPACE", "DEFENSE", "AVIATION",
     "TRANSPORT", "LOGISTICS", "TRUCKING", "RAILROAD", "RAILWAY",
     "FREIGHT", "MACHINERY", "EQUIPMENT", "DEERE", "CATERPILLAR",
     "HONEYWELL", "EMERSON ELEC", "ILLINOIS TOOL", "PARKER HANNIFIN",
     "GENERAL ELEC", "NORTHROP", "RAYTHEON", "LOCKHEED", "BOEING",
     "GENERAL DYNAMICS", "L3HARRIS", "LEIDOS", "JACOBS SOLUTIONS",
     "WASTE MGMT", "REPUBLIC SVCS", "FASTENAL", "CINTAS"], "Industrials"),
    # Consumer
    (["RESTAURANT", "RETAIL", "FOOD", "BEVERAGE", "GROCERY",
     "APPAREL", "CLOTHING", "FASHION", "HOTEL", "RESORT", "LEISURE",
     "ENTERTAINMENT", "GAMING", "CASINO", "DISNEY", "COMCAST",
     "STARBUCKS", "MCDONALD", "COCA COLA", "PEPSI", "PROCTER",
     "COLGATE", "COSTCO", "WALMART", "TARGET CORP", "HOME DEPOT",
     "LOWES COS", "NIKE", "ESTEE LAUDER", "CHURCH & DWIGHT",
     "KIMBERLY-CLARK", "CLOROX", "HERSHEY", "GENERAL MILLS",
     "KELLOGG", "CAMPBELL SOUP", "JM SMUCKER", "MONDELEZ",
     "KRAFT HEINZ", "TYSON FOODS", "HORMEL", "CONAGRA"], "Consumer"),
    # Real Estate
    (["REALTY", "REAL ESTATE", "REIT", "PROPERTY", "PROLOGIS",
     "SIMON PROPERTY", "PUBLIC STORAGE", "EQUINIX", "CROWN CASTLE",
     "DIGITAL REALTY", "WEYERHAEUSER", "VENTAS", "WELLTOWER",
     "ESSEX PROPERTY", "AVALONBAY"], "Real Estate"),
    # Telecom
    (["TELECOM", "COMMUNICAT", "WIRELESS", "BROADBAND", "CABLE",
     "SATELLITE", "AT&T", "VERIZON", "T-MOBILE", "CHARTER COMM",
     "LIBERTY MEDIA", "LIBERTY LATIN"], "Telecom"),
    # Automotive
    (["AUTOMOTIVE", "AUTO ", "MOTOR", "TESLA", "GENERAL MOTORS",
     "FORD MOTOR", "RIVIAN", "LUCID GRP"], "Automotive & EV"),
]


def _classify_holding(record: HoldingRecord, sector_map: dict[str, str]) -> str:
    """Classify a holding record into a sector."""
    ticker = (record.ticker or "").strip()
    name = (record.company_name or "").strip().upper()

    # Check DB-provided sector first
    if ticker in sector_map:
        return sector_map[ticker]
    # Check ticker mapping
    if ticker in _TICKER_SECTOR:
        return _TICKER_SECTOR[ticker]
    # Check company name mapping (for 13F data where ticker = "COM")
    for key, sector in _COMPANY_SECTOR.items():
        if key.upper() in name or name in key.upper():
            return sector
    # Keyword-based classification for broad coverage of 13F filings
    for keywords, sector in _KEYWORD_SECTOR:
        for kw in keywords:
            if kw in name:
                return sector
    return "Other"


def _compute_sector_breakdown(
    records: list[HoldingRecord], sector_map: dict[str, str]
) -> list[dict]:
    """Compute sector breakdown from holdings records."""
    sector_weights: dict[str, float] = {}
    sector_counts: dict[str, int] = {}
    sector_value: dict[str, float] = {}

    for r in records:
        sector = _classify_holding(r, sector_map)
        wt = float(r.weight_percent) if r.weight_percent else 0
        mv = float(r.market_value) if r.market_value else 0
        sector_weights[sector] = sector_weights.get(sector, 0) + wt
        sector_value[sector] = sector_value.get(sector, 0) + mv
        sector_counts[sector] = sector_counts.get(sector, 0) + 1

    # If no weight data (13F), compute from market values
    total_value = sum(sector_value.values())
    use_value = all(v == 0 for v in sector_weights.values()) and total_value > 0

    results = []
    total_pct = 0.0
    for sector in sorted(sector_weights.keys(),
                         key=lambda s: sector_weights.get(s, 0) if not use_value
                         else sector_value.get(s, 0),
                         reverse=True):
        pct = (sector_value[sector] / total_value * 100) if use_value else sector_weights[sector]
        total_pct += pct
        results.append({
            "sector": sector,
            "weight_pct": round(pct, 1),
            "count": sector_counts[sector],
        })

    # Add "Cash & Other" if total doesn't sum to 100% (common for ETFs with cash positions)
    if not use_value and total_pct < 99.5:
        cash_pct = 100.0 - total_pct
        if cash_pct >= 0.5:  # Only show if >= 0.5%
            results.append({
                "sector": "Cash & Other",
                "weight_pct": round(cash_pct, 1),
                "count": 0,
            })

    return results


def _summarize_changes(changes: list[HoldingsChange], *, fallback: bool = False, latest_date: date | None = None) -> dict:
    """Summarize recent holdings changes into a compact overview.

    Changes are already sorted by transaction size (abs shares_delta) descending.
    Only shows changes from the most recent date.
    """
    if not changes:
        return {
            "total": 0,
            "buys": [],
            "sells": [],
            "summary_text": "No disclosed changes.",
            "date": None,
        }

    buys = []
    sells = []
    for c in changes:
        ct = c.change_type.value if hasattr(c.change_type, "value") else str(c.change_type)
        entry = {
            "ticker": c.ticker,
            "company_name": c.company_name,
            "change_type": ct,
            "shares_delta": str(c.shares_delta) if c.shares_delta else "0",
            "weight_delta": str(c.weight_delta) if c.weight_delta else "0",
            "date": str(c.to_date) if c.to_date else None,
        }
        if ct in ("new", "added"):
            buys.append(entry)
        elif ct in ("reduced", "sold_out"):
            sells.append(entry)

    parts = []
    if buys:
        tickers = ", ".join(b["ticker"] for b in buys[:5])
        parts.append(f"{len(buys)} buy{'s' if len(buys) != 1 else ''} ({tickers})")
    if sells:
        tickers = ", ".join(s["ticker"] for s in sells[:5])
        parts.append(f"{len(sells)} sell{'s' if len(sells) != 1 else ''} ({tickers})")

    display_date = latest_date or (changes[0].to_date if changes else None)
    if display_date:
        suffix = f" on {display_date}."
    else:
        suffix = "."

    summary_text = " and ".join(parts) + suffix if parts else "No changes."

    return {
        "total": len(changes),
        "buys": buys,
        "sells": sells,
        "summary_text": summary_text,
        "date": str(display_date) if display_date else None,
    }


def _summarize_changes_by_day(changes: list[HoldingsChange], top_n: int = 5) -> dict:
    """Group changes by day, with top N buys and sells per day.

    Returns structure for daily-exposure investors (like ARK ETFs).
    Days are ordered from most recent to oldest.
    Within each day, buys and sells are sorted by transaction size.
    """
    if not changes:
        return {
            "total": 0,
            "days": [],
            "summary_text": "No disclosed changes.",
        }

    # Group changes by date
    from collections import defaultdict
    by_date: dict[date, list] = defaultdict(list)
    for c in changes:
        if c.to_date:
            by_date[c.to_date].append(c)

    # Sort dates descending (most recent first)
    sorted_dates = sorted(by_date.keys(), reverse=True)

    days = []
    total_buys = 0
    total_sells = 0

    for d in sorted_dates:
        day_changes = by_date[d]

        # Separate buys and sells
        buys = []
        sells = []
        for c in day_changes:
            ct = c.change_type.value if hasattr(c.change_type, "value") else str(c.change_type)
            entry = {
                "ticker": c.ticker,
                "company_name": c.company_name,
                "change_type": ct,
                "shares_delta": str(c.shares_delta) if c.shares_delta else "0",
                "weight_delta": str(c.weight_delta) if c.weight_delta else "0",
            }
            if ct in ("new", "added"):
                buys.append(entry)
            elif ct in ("reduced", "sold_out"):
                sells.append(entry)

        # Sort by absolute shares_delta (transaction size)
        buys.sort(key=lambda x: abs(float(x["shares_delta"] or 0)), reverse=True)
        sells.sort(key=lambda x: abs(float(x["shares_delta"] or 0)), reverse=True)

        total_buys += len(buys)
        total_sells += len(sells)

        days.append({
            "date": str(d),
            "top_buys": buys[:top_n],
            "top_sells": sells[:top_n],
            "remaining_buys": buys[top_n:],
            "remaining_sells": sells[top_n:],
            "total_buys": len(buys),
            "total_sells": len(sells),
        })

    # Summary text
    parts = []
    if total_buys:
        parts.append(f"{total_buys} buy{'s' if total_buys != 1 else ''}")
    if total_sells:
        parts.append(f"{total_sells} sell{'s' if total_sells != 1 else ''}")
    summary_text = " and ".join(parts) + f" over {len(days)} day{'s' if len(days) != 1 else ''}." if parts else "No changes."

    return {
        "total": len(changes),
        "days": days,
        "summary_text": summary_text,
    }


@router.get("/{investor_id}/changes", response_model=HoldingsChangesListResponse)
async def get_investor_changes(
    investor_id: str,
    db: DB,
    from_date: date | None = None,
    to_date: date | None = None,
    change_type: str | None = None,
    ticker: str | None = None,
    sector: str | None = None,
    sort_by: str = "shares_delta_abs",  # Default: sort by transaction size
    sort_order: str = "desc",
    latest_only: bool = True,  # Default: only show most recent date
    skip: int = 0,
    limit: int = 50,
):
    """Get investor's holdings changes with filtering.

    By default, returns only the most recent date's changes, sorted by transaction size.
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)

    # If latest_only, first find the most recent date
    actual_from_date = from_date
    actual_to_date = to_date
    if latest_only and not from_date and not to_date:
        latest_date_result = await db.execute(
            select(func.max(HoldingsChange.to_date))
            .where(HoldingsChange.investor_id == investor_uuid)
        )
        latest_date = latest_date_result.scalar()
        if latest_date:
            actual_from_date = latest_date
            actual_to_date = latest_date

    query = select(HoldingsChange).where(HoldingsChange.investor_id == investor_uuid)

    if actual_from_date:
        query = query.where(HoldingsChange.to_date >= actual_from_date)
    if actual_to_date:
        query = query.where(HoldingsChange.to_date <= actual_to_date)
    if change_type:
        query = query.where(HoldingsChange.change_type == change_type)
    if ticker:
        query = query.where(HoldingsChange.ticker.ilike(f"%{ticker}%"))

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = await db.scalar(count_query)

    # Sort - default to absolute shares_delta (transaction size)
    if sort_by == "shares_delta_abs":
        if sort_order == "desc":
            query = query.order_by(func.abs(HoldingsChange.shares_delta).desc().nullslast())
        else:
            query = query.order_by(func.abs(HoldingsChange.shares_delta).asc().nullsfirst())
    else:
        sort_column = getattr(HoldingsChange, sort_by, HoldingsChange.to_date)
        if sort_order == "desc":
            query = query.order_by(sort_column.desc())
        else:
            query = query.order_by(sort_column.asc())

    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    changes = result.scalars().all()

    return HoldingsChangesListResponse(
        changes=changes,
        total=total,
        from_date=actual_from_date,
        to_date=actual_to_date,
    )


@router.get("/{investor_id}/trades", response_model=InvestorActionsListResponse)
async def get_investor_trades(
    investor_id: str,
    db: DB,
    from_date: date | None = None,
    to_date: date | None = None,
    action_type: str | None = None,
    ticker: str | None = None,
    fund_name: str | None = None,
    skip: int = 0,
    limit: int = 50,
):
    """
    Get investor's trades (primarily for daily disclosures like ARK).
    
    Note: This endpoint is most useful for investors with daily disclosure.
    For quarterly 13F filers, use /changes instead.
    """
    investor_uuid = await _resolve_investor_uuid(investor_id, db)
    # Check if investor supports trade history
    investor_result = await db.execute(
        select(Investor).where(Investor.id == investor_uuid)
    )
    investor = investor_result.scalar_one_or_none()
    
    if investor and "trade_history" not in (investor.supported_features or []):
        # Return empty with note
        return InvestorActionsListResponse(
            actions=[],
            total=0,
            from_date=from_date,
            to_date=to_date,
            note="Trade-level detail not available for this investor's disclosure type.",
        )
    
    query = select(InvestorAction).where(InvestorAction.investor_id == investor_uuid)
    
    if from_date:
        query = query.where(InvestorAction.trade_date >= from_date)
    if to_date:
        query = query.where(InvestorAction.trade_date <= to_date)
    if action_type:
        query = query.where(InvestorAction.action_type == action_type)
    if ticker:
        query = query.where(InvestorAction.ticker.ilike(f"%{ticker}%"))
    if fund_name:
        query = query.where(InvestorAction.fund_name.ilike(f"%{fund_name}%"))
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = await db.scalar(count_query)
    
    query = query.order_by(InvestorAction.trade_date.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    actions = result.scalars().all()
    
    return InvestorActionsListResponse(
        actions=actions,
        total=total,
        from_date=from_date,
        to_date=to_date,
    )


# =============================================================================
# STRATEGY NOTES AND SUMMARY
# =============================================================================

@router.get("/{investor_id}/strategy-notes", response_model=list[StrategyNoteResponse])
async def get_strategy_notes(investor_id: UUID, db: DB):
    """Get curated strategy notes for an investor."""
    result = await db.execute(
        select(StrategyNote)
        .where(StrategyNote.investor_id == investor_id, StrategyNote.is_active == True)
        .order_by(StrategyNote.source_date.desc())
    )
    return result.scalars().all()


@router.get("/{investor_id}/summary")
async def get_investor_summary(
    investor_id: UUID,
    db: DB,
    days: int = Query(default=30, le=365),
):
    """
    Get summary statistics for an investor.
    
    Adapts to disclosure type - shows appropriate metrics based on data availability.
    """
    # Get investor for context
    investor_result = await db.execute(
        select(Investor)
        .options(selectinload(Investor.disclosure_sources))
        .where(Investor.id == investor_id)
    )
    investor = investor_result.scalar_one_or_none()
    
    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )
    
    start_date = date.today() - timedelta(days=days)
    
    # Get changes stats
    changes_result = await db.execute(
        select(
            HoldingsChange.change_type,
            func.count().label("count"),
        )
        .where(
            HoldingsChange.investor_id == investor_id,
            HoldingsChange.to_date >= start_date,
        )
        .group_by(HoldingsChange.change_type)
    )
    changes_by_type = {str(r.change_type.value): r.count for r in changes_result.all()}
    
    # Get top buys
    top_buys = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_id,
            HoldingsChange.to_date >= start_date,
            HoldingsChange.change_type.in_(["new", "added"]),
        )
        .order_by(HoldingsChange.value_delta.desc().nullslast())
        .limit(5)
    )
    
    # Get top sells
    top_sells = await db.execute(
        select(HoldingsChange)
        .where(
            HoldingsChange.investor_id == investor_id,
            HoldingsChange.to_date >= start_date,
            HoldingsChange.change_type.in_(["reduced", "sold_out"]),
        )
        .order_by(HoldingsChange.value_delta.asc().nullslast())
        .limit(5)
    )
    
    # Get disclosure context
    disclosure_summary = disclosure_service.get_disclosure_summary(investor)
    
    # Get transparency info
    transparency_label = investor.transparency_label.value if investor.transparency_label else "medium"
    transparency_score = investor.transparency_score or 50
    
    return {
        "period_days": days,
        "investor_type": investor.investor_type.value,
        "disclosure_context": disclosure_summary,
        # Transparency info (NOT a performance indicator)
        "transparency": {
            "score": transparency_score,
            "label": transparency_label,
            "disclaimer": TRANSPARENCY_DISCLAIMER,
        },
        "changes_by_type": changes_by_type,
        "top_buys": [HoldingsChangeResponse.model_validate(c) for c in top_buys.scalars().all()],
        "top_sells": [HoldingsChangeResponse.model_validate(c) for c in top_sells.scalars().all()],
        "data_note": (
            f"Data from {disclosure_summary.get('primary_disclosure', 'public disclosure')}. "
            f"Updates typically {disclosure_summary.get('update_frequency', 'periodically')}. "
            f"Transparency: {transparency_label}."
        ),
    }
