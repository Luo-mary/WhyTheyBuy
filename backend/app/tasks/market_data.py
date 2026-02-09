"""Market data tasks."""
import logging
from datetime import date, datetime, timedelta

from app.worker import celery_app
from app.tasks.ingestion import _make_task_session_factory
from app.models.company import Company, MarketPrice
from app.models.holdings import HoldingsChange
from app.services.market_data import fetch_price_data, fetch_company_profile
from sqlalchemy import select, distinct

logger = logging.getLogger(__name__)


@celery_app.task
def refresh_company_profiles():
    """Refresh company profiles for all tracked tickers."""
    import asyncio
    asyncio.run(_refresh_company_profiles_async())


async def _refresh_company_profiles_async():
    """Async implementation of company profile refresh."""
    logger.info("Refreshing company profiles")
    
    async with _make_task_session_factory()() as db:
        # Get all unique tickers from holdings changes
        result = await db.execute(
            select(distinct(HoldingsChange.ticker))
        )
        tickers = [r[0] for r in result.all()]
        
        logger.info(f"Found {len(tickers)} unique tickers to refresh")
        
        for ticker in tickers:
            try:
                await refresh_single_company(db, ticker)
            except Exception as e:
                logger.error(f"Error refreshing {ticker}: {e}")
        
        await db.commit()
        logger.info("Company profiles refresh complete")


async def refresh_single_company(db, ticker: str):
    """Refresh a single company's profile."""
    # Check if company exists
    result = await db.execute(
        select(Company).where(Company.ticker == ticker)
    )
    company = result.scalar_one_or_none()
    
    # Fetch profile
    profile = await fetch_company_profile(ticker)
    
    if not profile:
        logger.warning(f"No profile data for {ticker}")
        return
    
    if company:
        # Update existing
        company.name = profile.get("name") or company.name
        company.exchange = profile.get("exchange") or company.exchange
        company.sector = profile.get("sector") or company.sector
        company.industry = profile.get("industry") or company.industry
        company.market_cap = profile.get("market_cap") or company.market_cap
        company.website = profile.get("website") or company.website
        company.logo_url = profile.get("logo_url") or company.logo_url
        company.profile_last_updated = datetime.utcnow()
    else:
        # Create new
        company = Company(
            ticker=ticker,
            name=profile.get("name", ticker),
            exchange=profile.get("exchange"),
            sector=profile.get("sector"),
            industry=profile.get("industry"),
            market_cap=profile.get("market_cap"),
            website=profile.get("website"),
            logo_url=profile.get("logo_url"),
            profile_last_updated=datetime.utcnow(),
        )
        db.add(company)
    
    logger.info(f"Updated profile for {ticker}")


@celery_app.task
def fetch_historical_prices(ticker: str, days: int = 365):
    """Fetch historical prices for a ticker."""
    import asyncio
    asyncio.run(_fetch_historical_prices_async(ticker, days))


async def _fetch_historical_prices_async(ticker: str, days: int):
    """Async implementation of historical price fetch."""
    logger.info(f"Fetching {days} days of prices for {ticker}")
    
    to_date = date.today()
    from_date = to_date - timedelta(days=days)
    
    prices = await fetch_price_data(ticker, from_date, to_date)
    
    if not prices:
        logger.warning(f"No price data fetched for {ticker}")
        return
    
    async with _make_task_session_factory()() as db:
        for price in prices:
            # Check if exists
            existing = await db.execute(
                select(MarketPrice).where(
                    MarketPrice.ticker == ticker,
                    MarketPrice.price_date == price["date"],
                )
            )
            if existing.scalar_one_or_none():
                continue
            
            # Insert new
            market_price = MarketPrice(
                ticker=ticker,
                price_date=price["date"],
                open_price=price.get("open"),
                high_price=price.get("high"),
                low_price=price.get("low"),
                close_price=price.get("close"),
                volume=price.get("volume"),
                adj_close=price.get("close"),
            )
            db.add(market_price)
        
        await db.commit()
    
    logger.info(f"Stored {len(prices)} price records for {ticker}")


@celery_app.task
def update_prices_for_changes(change_date: str):
    """Update price ranges for holdings changes on a specific date."""
    import asyncio
    asyncio.run(_update_prices_for_changes_async(change_date))


async def _update_prices_for_changes_async(change_date: str):
    """Async implementation of price update for changes."""
    change_date_obj = date.fromisoformat(change_date)
    logger.info(f"Updating prices for changes on {change_date_obj}")
    
    async with _make_task_session_factory()() as db:
        # Get changes without prices
        result = await db.execute(
            select(HoldingsChange).where(
                HoldingsChange.to_date == change_date_obj,
                HoldingsChange.price_range_low == None,
            )
        )
        changes = result.scalars().all()
        
        for change in changes:
            prices = await fetch_price_data(
                change.ticker,
                change.from_date,
                change.to_date,
            )
            
            if prices:
                lows = [p["low"] for p in prices if p.get("low")]
                highs = [p["high"] for p in prices if p.get("high")]
                
                if lows and highs:
                    change.price_range_low = min(lows)
                    change.price_range_high = max(highs)
        
        await db.commit()
    
    logger.info("Prices updated")
