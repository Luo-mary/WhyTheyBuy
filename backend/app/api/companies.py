"""Companies API routes."""
from datetime import date, timedelta
from uuid import UUID
from fastapi import APIRouter, HTTPException, status, Query
from sqlalchemy import select, func

from app.api.deps import DB, OptionalUser
from app.models.company import Company, MarketPrice
from app.models.holdings import HoldingsChange, InvestorAction
from app.models.investor import Investor
from app.schemas.company import (
    CompanyResponse,
    MarketPriceResponse,
    PriceRangeResponse,
    PriceHistoryResponse,
    CompanyActivityResponse,
)
from app.schemas.holdings import HoldingsChangeResponse, InvestorActionResponse
from app.services.market_data import fetch_realtime_quote, fetch_price_data

router = APIRouter()


@router.get("", response_model=list[CompanyResponse])
async def list_companies(
    db: DB,
    search: str | None = None,
    sector: str | None = None,
    skip: int = 0,
    limit: int = 50,
):
    """List companies with optional filtering."""
    query = select(Company).where(Company.is_active == True)
    
    if search:
        query = query.where(
            Company.ticker.ilike(f"%{search}%") |
            Company.name.ilike(f"%{search}%")
        )
    
    if sector:
        query = query.where(Company.sector == sector)
    
    query = query.order_by(Company.ticker).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/sectors")
async def get_sectors(db: DB):
    """Get list of unique sectors."""
    result = await db.execute(
        select(Company.sector)
        .where(Company.sector != None, Company.is_active == True)
        .distinct()
        .order_by(Company.sector)
    )
    sectors = [r[0] for r in result.all() if r[0]]
    return {"sectors": sectors}


@router.get("/{ticker}", response_model=CompanyResponse)
async def get_company(ticker: str, db: DB):
    """Get company profile by ticker."""
    result = await db.execute(
        select(Company).where(Company.ticker == ticker.upper())
    )
    company = result.scalar_one_or_none()
    
    if not company:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Company not found",
        )
    
    return company


@router.get("/{ticker}/price", response_model=PriceHistoryResponse)
async def get_company_price_history(
    ticker: str,
    db: DB,
    range: str = Query(default="1m", regex="^(1w|1m|3m|6m|1y)$"),
):
    """Get company price history for charting."""
    # Calculate date range
    days_map = {"1w": 7, "1m": 30, "3m": 90, "6m": 180, "1y": 365}
    days = days_map.get(range, 30)
    start_date = date.today() - timedelta(days=days)
    
    result = await db.execute(
        select(MarketPrice)
        .where(
            MarketPrice.ticker == ticker.upper(),
            MarketPrice.price_date >= start_date,
        )
        .order_by(MarketPrice.price_date.asc())
    )
    prices = result.scalars().all()
    
    return PriceHistoryResponse(
        ticker=ticker.upper(),
        prices=[MarketPriceResponse.model_validate(p) for p in prices],
    )


@router.get("/{ticker}/price-range", response_model=PriceRangeResponse)
async def get_price_range(
    ticker: str,
    db: DB,
    from_date: date,
    to_date: date,
):
    """Get price range for a specific period."""
    result = await db.execute(
        select(
            func.min(MarketPrice.low_price).label("period_low"),
            func.max(MarketPrice.high_price).label("period_high"),
            func.avg(MarketPrice.volume).label("average_volume"),
        )
        .where(
            MarketPrice.ticker == ticker.upper(),
            MarketPrice.price_date >= from_date,
            MarketPrice.price_date <= to_date,
        )
    )
    row = result.one()
    
    # Get first and last day prices
    first_day = await db.execute(
        select(MarketPrice)
        .where(
            MarketPrice.ticker == ticker.upper(),
            MarketPrice.price_date >= from_date,
        )
        .order_by(MarketPrice.price_date.asc())
        .limit(1)
    )
    first_price = first_day.scalar_one_or_none()
    
    last_day = await db.execute(
        select(MarketPrice)
        .where(
            MarketPrice.ticker == ticker.upper(),
            MarketPrice.price_date <= to_date,
        )
        .order_by(MarketPrice.price_date.desc())
        .limit(1)
    )
    last_price = last_day.scalar_one_or_none()
    
    return PriceRangeResponse(
        ticker=ticker.upper(),
        from_date=from_date,
        to_date=to_date,
        period_low=row.period_low,
        period_high=row.period_high,
        period_open=first_price.open_price if first_price else None,
        period_close=last_price.close_price if last_price else None,
        average_volume=row.average_volume,
    )


@router.get("/{ticker}/investor-activity")
async def get_investor_activity(
    ticker: str,
    db: DB,
    investor_id: UUID | None = None,
    limit: int = Query(default=20, le=100),
):
    """Get investor activity for a company."""
    ticker = ticker.upper()
    
    # Build base queries
    actions_query = select(InvestorAction).where(InvestorAction.ticker == ticker)
    changes_query = select(HoldingsChange).where(HoldingsChange.ticker == ticker)
    
    if investor_id:
        actions_query = actions_query.where(InvestorAction.investor_id == investor_id)
        changes_query = changes_query.where(HoldingsChange.investor_id == investor_id)
    
    # Get actions
    actions_result = await db.execute(
        actions_query.order_by(InvestorAction.trade_date.desc()).limit(limit)
    )
    actions = actions_result.scalars().all()
    
    # Get changes
    changes_result = await db.execute(
        changes_query.order_by(HoldingsChange.to_date.desc()).limit(limit)
    )
    changes = changes_result.scalars().all()
    
    # Get investor names
    investor_ids = set(
        [a.investor_id for a in actions] + [c.investor_id for c in changes]
    )
    investors_result = await db.execute(
        select(Investor).where(Investor.id.in_(investor_ids))
    )
    investors = {i.id: i for i in investors_result.scalars().all()}
    
    return {
        "ticker": ticker,
        "actions": [
            {
                **InvestorActionResponse.model_validate(a).model_dump(),
                "investor_name": investors.get(a.investor_id).name if investors.get(a.investor_id) else None,
            }
            for a in actions
        ],
        "changes": [
            {
                **HoldingsChangeResponse.model_validate(c).model_dump(),
                "investor_name": investors.get(c.investor_id).name if investors.get(c.investor_id) else None,
            }
            for c in changes
        ],
    }


@router.get("/{ticker}/investors")
async def get_company_investors(ticker: str, db: DB):
    """Get list of investors who hold/traded this company."""
    ticker = ticker.upper()
    
    # Get from recent changes
    investor_ids_query = (
        select(HoldingsChange.investor_id)
        .where(HoldingsChange.ticker == ticker)
        .distinct()
    )
    
    investor_ids_result = await db.execute(investor_ids_query)
    investor_ids = [r[0] for r in investor_ids_result.all()]
    
    if not investor_ids:
        return {"investors": []}
    
    investors_result = await db.execute(
        select(Investor)
        .where(Investor.id.in_(investor_ids), Investor.is_active == True)
        .order_by(Investor.name)
    )
    investors = investors_result.scalars().all()
    
    return {
        "investors": [
            {
                "id": str(i.id),
                "name": i.name,
                "short_name": i.short_name,
                "category": i.category.value,
            }
            for i in investors
        ]
    }


@router.get("/{ticker}/live")
async def get_live_quote(ticker: str):
    """
    Get real-time stock quote from Alpha Vantage.

    Returns current price, change, and daily statistics.
    Note: Free tier has 25 calls/day limit.
    """
    quote = await fetch_realtime_quote(ticker.upper())

    if not quote:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to fetch live quote. API may be unavailable or rate limited.",
        )

    return quote


@router.get("/{ticker}/live-history")
async def get_live_price_history(
    ticker: str,
    range: str = Query(default="1m", pattern="^(1d|1w|1m|3m|6m|1y|5y|all)$"),
):
    """
    Get historical price data directly from Alpha Vantage.

    Returns OHLCV data for charting.
    Supports ranges: 1d (intraday), 1w, 1m, 3m, 6m, 1y, 5y, all

    Note: Uses more API calls, consider caching for production.
    """
    # Map range to days (for '1d' we'll use intraday data)
    days_map = {
        "1d": 1,  # Intraday
        "1w": 7,
        "1m": 30,
        "3m": 90,
        "6m": 180,
        "1y": 365,
        "5y": 365 * 5,
        "all": 365 * 20,  # Max ~20 years
    }
    days = days_map.get(range, 30)

    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    # For 1d, we would use intraday API - for now, return recent daily data
    prices = await fetch_price_data(ticker.upper(), start_date, end_date)

    if not prices:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to fetch price history. API may be unavailable or rate limited.",
        )

    return {
        "ticker": ticker.upper(),
        "range": range,
        "prices": [
            {
                "date": str(p["date"]),
                "open": float(p["open"]),
                "high": float(p["high"]),
                "low": float(p["low"]),
                "close": float(p["close"]),
                "volume": p["volume"],
            }
            for p in prices
        ],
    }
