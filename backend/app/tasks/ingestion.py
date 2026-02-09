"""Data ingestion tasks for ARK and 13F filings."""
import logging
from datetime import date, datetime, timedelta
from decimal import Decimal
import csv
import io
import httpx
from bs4 import BeautifulSoup

from app.worker import celery_app
from app.models.investor import Investor, DisclosureSourceType, DisclosureSource
from app.models.holdings import (
    HoldingsSnapshot,
    HoldingRecord,
    HoldingsChange,
    InvestorAction,
    SnapshotSource,
    ActionType,
    ChangeType,
)
from app.services.diff import compute_holdings_diff, diff_to_db_model
from app.services.market_data import get_price_range, get_single_day_price
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

logger = logging.getLogger(__name__)


def _make_task_session_factory():
    """Create a fresh async engine and session factory for Celery task context.

    Celery workers fork from the parent process, so the module-level engine's
    connection pool is bound to the parent's event loop.  Each task needs its
    own engine to avoid 'Future attached to a different loop' errors.
    """
    from app.config import settings

    database_url = settings.database_url.replace(
        "postgresql://", "postgresql+asyncpg://"
    )
    engine = create_async_engine(
        database_url,
        echo=False,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=5,
    )
    return async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )

# ARK ETF trade data URLs (assets.ark-funds.com CDN)
ARK_FUNDS = {
    "ARKK": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_INNOVATION_ETF_ARKK_HOLDINGS.csv",
    "ARKW": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_NEXT_GENERATION_INTERNET_ETF_ARKW_HOLDINGS.csv",
    "ARKG": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_GENOMIC_REVOLUTION_ETF_ARKG_HOLDINGS.csv",
    "ARKF": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_FINTECH_INNOVATION_ETF_ARKF_HOLDINGS.csv",
    "ARKQ": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_AUTONOMOUS_TECH._&_ROBOTICS_ETF_ARKQ_HOLDINGS.csv",
}

ARK_TRADES_URL = "https://www.ark-funds.com/auto/trades/ARK_Trades.csv"


@celery_app.task(bind=True, max_retries=3)
def ingest_ark_holdings(self):
    """
    Ingest ARK ETF daily holdings.
    
    This task:
    1. Downloads the latest holdings CSV for each ARK fund
    2. Parses and stores the holdings snapshot
    3. Computes diffs against the previous snapshot
    4. Triggers notifications for changes
    """
    import asyncio
    asyncio.run(_ingest_ark_holdings_async())


async def _ingest_ark_holdings_async():
    """Async implementation of ARK holdings ingestion."""
    logger.info("Starting ARK holdings ingestion")

    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        # Get ARK investors with ETF holdings disclosure sources
        result = await db.execute(
            select(Investor)
            .join(DisclosureSource)
            .where(
                DisclosureSource.source_type == DisclosureSourceType.ETF_HOLDINGS,
                Investor.is_active == True,
            )
            .options(selectinload(Investor.disclosure_sources))
        )
        investors = result.scalars().all()
        
        if not investors:
            logger.warning("No ARK investors found in database")
            return
        
        for investor in investors:
            try:
                await ingest_ark_fund(db, investor)
            except Exception as e:
                logger.error(f"Error ingesting {investor.name}: {e}")
                continue
        
        # Also ingest trades
        try:
            await ingest_ark_trades(db)
        except Exception as e:
            logger.error(f"Error ingesting ARK trades: {e}")


async def ingest_ark_fund(db, investor: Investor):
    """Ingest holdings for a single ARK fund."""
    fund_code = investor.short_name or "ARKK"
    url = ARK_FUNDS.get(fund_code)
    
    if not url:
        logger.warning(f"No URL for fund {fund_code}")
        return
    
    logger.info(f"Fetching {fund_code} holdings from {url}")
    
    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; WhyTheyBuy/1.0)",
    }
    async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
        response = await client.get(url, timeout=60.0)
        response.raise_for_status()
        csv_content = response.text

    # Parse CSV — normalise column names to handle format variations
    reader = csv.DictReader(io.StringIO(csv_content))
    holdings = []
    snapshot_date = None

    def _col(row, *candidates, default=""):
        """Return the first matching column value from a row."""
        for c in candidates:
            if c in row and row[c]:
                return row[c].strip()
        return default

    for row in reader:
        ticker = _col(row, "ticker")
        if not ticker:
            continue

        # Get date from first row
        if snapshot_date is None:
            date_str = _col(row, "date")
            if date_str:
                try:
                    snapshot_date = datetime.strptime(date_str, "%m/%d/%Y").date()
                except ValueError:
                    snapshot_date = date.today()

        shares_str = _col(row, "shares").replace(",", "")
        mv_str = _col(row, "market value ($)", "market value($)").replace(",", "").replace("$", "")
        wt_str = _col(row, "weight (%)", "weight(%)").replace("%", "")

        holdings.append({
            "ticker": ticker,
            "company_name": _col(row, "company"),
            "cusip": _col(row, "cusip"),
            "shares": Decimal(shares_str) if shares_str else None,
            "market_value": Decimal(mv_str) if mv_str else None,
            "weight_percent": Decimal(wt_str) if wt_str else None,
        })
    
    if not holdings:
        logger.warning(f"No holdings parsed for {fund_code}")
        return
    
    snapshot_date = snapshot_date or date.today()
    
    # Check if snapshot already exists
    existing = await db.execute(
        select(HoldingsSnapshot).where(
            HoldingsSnapshot.investor_id == investor.id,
            HoldingsSnapshot.snapshot_date == snapshot_date,
        )
    )
    if existing.scalar_one_or_none():
        logger.info(f"Snapshot for {fund_code} on {snapshot_date} already exists")
        return
    
    # Get previous snapshot for diff
    prev_result = await db.execute(
        select(HoldingsSnapshot)
        .options(selectinload(HoldingsSnapshot.records))
        .where(HoldingsSnapshot.investor_id == investor.id)
        .order_by(HoldingsSnapshot.snapshot_date.desc())
        .limit(1)
    )
    prev_snapshot = prev_result.scalar_one_or_none()
    
    # Create new snapshot
    snapshot = HoldingsSnapshot(
        investor_id=investor.id,
        snapshot_date=snapshot_date,
        source=SnapshotSource.ARK_DAILY,
        total_positions=len(holdings),
        total_value=sum(h.get("market_value") or Decimal(0) for h in holdings),
        raw_data_url=url,
        is_processed=True,
        processed_at=datetime.utcnow(),
    )
    db.add(snapshot)
    await db.flush()
    
    # Add holding records
    for holding in holdings:
        record = HoldingRecord(
            snapshot_id=snapshot.id,
            ticker=holding["ticker"],
            company_name=holding["company_name"],
            cusip=holding["cusip"],
            shares=holding["shares"],
            market_value=holding["market_value"],
            weight_percent=holding["weight_percent"],
        )
        db.add(record)
    
    # Compute diffs
    if prev_snapshot and prev_snapshot.records:
        old_holdings = {
            r.ticker: {
                "company_name": r.company_name,
                "shares": r.shares,
                "weight_percent": r.weight_percent,
                "market_value": r.market_value,
            }
            for r in prev_snapshot.records
        }
        
        new_holdings = {
            h["ticker"]: h for h in holdings
        }
        
        diffs = compute_holdings_diff(old_holdings, new_holdings)
        
        for diff in diffs:
            # Get price range for the day
            price_low, price_high = await get_price_range(
                diff.ticker, snapshot_date, snapshot_date
            )
            
            change = diff_to_db_model(
                diff,
                investor_id=investor.id,
                from_date=prev_snapshot.snapshot_date,
                to_date=snapshot_date,
                price_range_low=price_low,
                price_range_high=price_high,
            )
            db.add(change)
        
        if diffs:
            investor.last_change_detected = datetime.utcnow()
            # Trigger notifications
            from app.tasks.notifications import notify_holdings_change
            notify_holdings_change.delay(str(investor.id), snapshot_date.isoformat())
    
    investor.last_data_fetch = datetime.utcnow()
    await db.commit()
    
    logger.info(f"Ingested {len(holdings)} holdings for {fund_code} on {snapshot_date}")


async def ingest_ark_trades(db):
    """Ingest ARK daily trades from arkfunds.io API and create holdings changes."""
    logger.info("Fetching ARK trades from arkfunds.io API")

    # Get all ARK investors
    result = await db.execute(
        select(Investor)
        .join(DisclosureSource)
        .where(
            DisclosureSource.source_type == DisclosureSourceType.ETF_HOLDINGS,
            Investor.is_active == True,
        )
        .options(selectinload(Investor.disclosure_sources))
    )
    investors = {i.short_name: i for i in result.scalars().all()}

    if not investors:
        logger.warning("No ARK investors found")
        return

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; WhyTheyBuy/1.0)",
    }

    trades_added = 0
    changes_added = 0

    async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
        for fund_code, investor in investors.items():
            try:
                # Fetch trades for the last 7 days from arkfunds.io API
                api_url = f"https://arkfunds.io/api/v2/etf/trades?symbol={fund_code}"
                response = await client.get(api_url, timeout=30.0)

                if response.status_code != 200:
                    logger.warning(f"arkfunds.io API returned {response.status_code} for {fund_code}")
                    continue

                data = response.json()
                trades = data.get("trades", [])

                if not trades:
                    logger.info(f"No recent trades for {fund_code}")
                    continue

                logger.info(f"Found {len(trades)} trades for {fund_code}")

                # Get the latest snapshot to calculate prices from holdings data
                latest_snapshot_result = await db.execute(
                    select(HoldingsSnapshot)
                    .options(selectinload(HoldingsSnapshot.records))
                    .where(HoldingsSnapshot.investor_id == investor.id)
                    .order_by(HoldingsSnapshot.snapshot_date.desc())
                    .limit(1)
                )
                latest_snapshot = latest_snapshot_result.scalar_one_or_none()

                # Build a price lookup from holdings (market_value / shares)
                price_lookup = {}
                if latest_snapshot and latest_snapshot.records:
                    for record in latest_snapshot.records:
                        if record.ticker and record.shares and record.shares > 0 and record.market_value:
                            price_lookup[record.ticker] = record.market_value / record.shares

                for trade in trades:
                    ticker = trade.get("ticker", "").strip()
                    if not ticker:
                        continue

                    try:
                        trade_date = datetime.strptime(trade.get("date", ""), "%Y-%m-%d").date()
                    except ValueError:
                        continue

                    direction = trade.get("direction", "").lower()
                    shares = trade.get("shares", 0)
                    company_name = trade.get("company", "")
                    etf_percent = trade.get("etf_percent", 0)

                    # Calculate estimated value from price lookup
                    estimated_price = price_lookup.get(ticker)
                    value_delta = None
                    if estimated_price and shares:
                        value_delta = Decimal(str(shares)) * estimated_price
                        if direction == "sell":
                            value_delta = -value_delta

                    # Check if trade action already exists
                    existing_action = await db.execute(
                        select(InvestorAction).where(
                            InvestorAction.investor_id == investor.id,
                            InvestorAction.trade_date == trade_date,
                            InvestorAction.ticker == ticker,
                        )
                    )
                    if not existing_action.scalar_one_or_none():
                        action_type = ActionType.BUY if direction == "buy" else ActionType.SELL
                        action = InvestorAction(
                            investor_id=investor.id,
                            action_type=action_type,
                            ticker=ticker,
                            company_name=company_name,
                            trade_date=trade_date,
                            shares=Decimal(str(shares)) if shares else None,
                            weight_percent=Decimal(str(etf_percent)) if etf_percent else None,
                            fund_name=fund_code,
                            price_range_low=estimated_price,
                            price_range_high=estimated_price,
                        )
                        db.add(action)
                        trades_added += 1

                    # Also create a HoldingsChange record for visibility in the app
                    # Check if change already exists for this ticker/date/direction
                    change_type = (
                        ChangeType.ADDED if direction == "buy" else ChangeType.REDUCED
                    )

                    existing_change = await db.execute(
                        select(HoldingsChange).where(
                            HoldingsChange.investor_id == investor.id,
                            HoldingsChange.ticker == ticker,
                            HoldingsChange.to_date == trade_date,
                            HoldingsChange.change_type == change_type,
                        )
                    )
                    if not existing_change.scalar_one_or_none():
                        # For buys, shares_delta is positive; for sells, negative
                        shares_delta = Decimal(str(shares)) if shares else Decimal(0)
                        if direction == "sell":
                            shares_delta = -shares_delta

                        change = HoldingsChange(
                            investor_id=investor.id,
                            ticker=ticker,
                            company_name=company_name,
                            change_type=change_type,
                            from_date=trade_date - timedelta(days=1),
                            to_date=trade_date,
                            shares_delta=shares_delta,
                            value_delta=value_delta,
                            weight_after=Decimal(str(etf_percent)) if etf_percent else None,
                            price_range_low=estimated_price,
                            price_range_high=estimated_price,
                        )
                        db.add(change)
                        changes_added += 1

                # Update investor last_change_detected if we added changes
                if changes_added > 0:
                    investor.last_change_detected = datetime.utcnow()

            except Exception as e:
                logger.error(f"Error fetching trades for {fund_code}: {e}")
                continue

    await db.commit()
    logger.info(f"Added {trades_added} ARK trades and {changes_added} holdings changes")


@celery_app.task(bind=True, max_retries=3)
def check_13f_filings(self):
    """Check for new 13F filings on SEC EDGAR."""
    import asyncio
    asyncio.run(_check_13f_filings_async())


async def _check_13f_filings_async():
    """Async implementation of 13F filing check."""
    logger.info("Checking for new 13F filings")

    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        result = await db.execute(
            select(Investor)
            .join(DisclosureSource)
            .where(
                DisclosureSource.source_type == DisclosureSourceType.SEC_13F,
                Investor.is_active == True,
            )
            .options(selectinload(Investor.disclosure_sources))
        )
        investors = result.scalars().all()
        
        for investor in investors:
            try:
                await check_investor_13f(db, investor)
            except Exception as e:
                logger.error(f"Error checking 13F for {investor.name}: {e}")


async def check_investor_13f(db, investor: Investor):
    """Check for new 13F filing for an investor."""
    # Get CIK from the 13F disclosure source config
    sec_source = next(
        (ds for ds in investor.disclosure_sources
         if ds.source_type == DisclosureSourceType.SEC_13F and ds.source_config),
        None,
    )
    if not sec_source or not sec_source.source_config.get("cik"):
        logger.warning(f"No CIK configured for {investor.name}")
        return
    cik = sec_source.source_config["cik"].lstrip("0").zfill(10)  # CIK must be 10 digits

    # SEC EDGAR API endpoint for filings
    url = f"https://data.sec.gov/submissions/CIK{cik}.json"

    async with httpx.AsyncClient(follow_redirects=True) as client:
        client.headers["User-Agent"] = "WhyTheyBuy holdings@example.com"
        response = await client.get(url, timeout=30.0)
        response.raise_for_status()
        data = response.json()

    # Find 13F-HR filings
    filings = data.get("filings", {}).get("recent", {})
    forms = filings.get("form", [])
    accession_numbers = filings.get("accessionNumber", [])
    filing_dates = filings.get("filingDate", [])

    # Check if we have any existing snapshots for this investor
    existing_count = await db.execute(
        select(HoldingsSnapshot).where(
            HoldingsSnapshot.investor_id == investor.id,
        )
    )
    has_existing_data = existing_count.scalar_one_or_none() is not None

    # Collect 13F filings to process
    filings_to_process = []
    for i, form in enumerate(forms):
        if form not in ["13F-HR", "13F-HR/A"]:
            continue

        filing_date_str = filing_dates[i]
        filing_date = datetime.strptime(filing_date_str, "%Y-%m-%d").date()

        # Check if we already have this filing
        existing = await db.execute(
            select(HoldingsSnapshot).where(
                HoldingsSnapshot.investor_id == investor.id,
                HoldingsSnapshot.filing_date == filing_date,
            )
        )
        if existing.scalar_one_or_none():
            continue

        filings_to_process.append({
            "filing_date": filing_date,
            "accession": accession_numbers[i].replace("-", ""),
        })

        # If we have existing data, only process the newest filing
        # If no existing data, process 2 filings to compute initial diffs
        if has_existing_data:
            break
        elif len(filings_to_process) >= 2:
            break

    # Process filings in reverse chronological order (oldest first) to build history
    for filing_info in reversed(filings_to_process):
        logger.info(f"New 13F filing found for {investor.name}: {filing_info['filing_date']}")
        await ingest_13f_filing(
            db, investor, cik,
            filing_info["accession"],
            filing_info["filing_date"]
        )


async def ingest_13f_filing(
    db,
    investor: Investor,
    cik: str,
    accession: str,
    filing_date: date,
):
    """Ingest a 13F filing."""
    headers = {"User-Agent": "WhyTheyBuy holdings@example.com"}

    # Discover the correct XML info table URL from the filing index
    index_url = f"https://www.sec.gov/Archives/edgar/data/{cik}/{accession}/index.json"
    async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
        idx_resp = await client.get(index_url, timeout=30.0)
        idx_resp.raise_for_status()
        idx_data = idx_resp.json()

    # Find the info table XML — look for the file containing "infotable" or ending with .xml
    xml_filename = None
    for item in idx_data.get("directory", {}).get("item", []):
        name_lower = item.get("name", "").lower()
        if "infotable" in name_lower and name_lower.endswith(".xml"):
            xml_filename = item["name"]
            break
    if not xml_filename:
        # Fallback: any XML file that's not the primary doc
        for item in idx_data.get("directory", {}).get("item", []):
            name_lower = item.get("name", "").lower()
            if name_lower.endswith(".xml") and "primary" not in name_lower:
                xml_filename = item["name"]
                break
    if not xml_filename:
        xml_filename = "primary_doc.xml"

    xml_url = f"https://www.sec.gov/Archives/edgar/data/{cik}/{accession}/{xml_filename}"
    logger.info(f"Fetching 13F XML from {xml_url}")

    async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
        response = await client.get(xml_url, timeout=60.0)
        response.raise_for_status()
        xml_content = response.text

    # Parse XML
    soup = BeautifulSoup(xml_content, "lxml-xml")
    info_tables = soup.find_all("infoTable")
    
    holdings = []
    for info in info_tables:
        ticker = info.find("titleOfClass")
        cusip = info.find("cusip")
        name = info.find("nameOfIssuer")
        value = info.find("value")
        shares = info.find("sshPrnamt")
        
        if cusip:
            holdings.append({
                "ticker": ticker.text if ticker else "",
                "company_name": name.text if name else "",
                "cusip": cusip.text if cusip else "",
                "shares": Decimal(shares.text.replace(",", "")) if shares else None,
                "market_value": Decimal(value.text.replace(",", "")) if value else None,
            })
    
    if not holdings:
        logger.warning(f"No holdings parsed from 13F for {investor.name}")
        return
    
    # Get period end date from filing (usually end of quarter)
    period_end = soup.find("periodOfReport")
    period_end_date = None
    if period_end:
        try:
            period_end_date = datetime.strptime(period_end.text, "%m-%d-%Y").date()
        except ValueError:
            try:
                period_end_date = datetime.strptime(period_end.text, "%Y-%m-%d").date()
            except ValueError:
                pass
    
    period_end_date = period_end_date or filing_date
    
    # Get previous snapshot for diff
    prev_result = await db.execute(
        select(HoldingsSnapshot)
        .options(selectinload(HoldingsSnapshot.records))
        .where(HoldingsSnapshot.investor_id == investor.id)
        .order_by(HoldingsSnapshot.snapshot_date.desc())
        .limit(1)
    )
    prev_snapshot = prev_result.scalar_one_or_none()
    
    # Create snapshot
    snapshot = HoldingsSnapshot(
        investor_id=investor.id,
        snapshot_date=period_end_date,
        source=SnapshotSource.SEC_13F,
        filing_date=filing_date,
        period_end_date=period_end_date,
        total_positions=len(holdings),
        total_value=sum(h.get("market_value") or Decimal(0) for h in holdings),
        raw_data_url=xml_url,
        is_processed=True,
        processed_at=datetime.utcnow(),
    )
    db.add(snapshot)
    await db.flush()
    
    # Add holding records
    for holding in holdings:
        record = HoldingRecord(
            snapshot_id=snapshot.id,
            ticker=holding["ticker"],
            company_name=holding["company_name"],
            cusip=holding["cusip"],
            shares=holding["shares"],
            market_value=holding["market_value"],
        )
        db.add(record)
    
    # Compute diffs
    if prev_snapshot and prev_snapshot.records:
        old_holdings = {
            r.cusip or r.ticker: {
                "ticker": r.ticker,
                "company_name": r.company_name,
                "shares": r.shares,
                "market_value": r.market_value,
            }
            for r in prev_snapshot.records
        }
        
        new_holdings = {
            h["cusip"] or h["ticker"]: h for h in holdings
        }
        
        diffs = compute_holdings_diff(old_holdings, new_holdings)
        
        for diff in diffs:
            # Get quarterly price range
            from_date = prev_snapshot.period_end_date or prev_snapshot.snapshot_date
            price_low, price_high = await get_price_range(
                diff.ticker, from_date, period_end_date
            )
            
            change = diff_to_db_model(
                diff,
                investor_id=investor.id,
                from_date=from_date,
                to_date=period_end_date,
                price_range_low=price_low,
                price_range_high=price_high,
            )
            db.add(change)
        
        if diffs:
            investor.last_change_detected = datetime.utcnow()
            from app.tasks.notifications import notify_holdings_change
            notify_holdings_change.delay(str(investor.id), period_end_date.isoformat())
    
    investor.last_data_fetch = datetime.utcnow()
    await db.commit()
    
    logger.info(f"Ingested 13F with {len(holdings)} holdings for {investor.name}")


@celery_app.task
def ingest_single_investor(investor_id: str):
    """Manually trigger ingestion for a single investor."""
    import asyncio
    asyncio.run(_ingest_single_investor_async(investor_id))


async def _ingest_single_investor_async(investor_id: str):
    """Async implementation of single investor ingestion."""
    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        result = await db.execute(
            select(Investor)
            .where(Investor.id == investor_id)
            .options(selectinload(Investor.disclosure_sources))
        )
        investor = result.scalar_one_or_none()
        
        if not investor:
            logger.error(f"Investor not found: {investor_id}")
            return
        
        # Get primary disclosure source
        primary_source = investor.get_primary_disclosure()
        if not primary_source:
            logger.error(f"No disclosure source configured for investor: {investor.name}")
            return
        
        if primary_source.source_type == DisclosureSourceType.ETF_HOLDINGS:
            await ingest_ark_fund(db, investor)
        elif primary_source.source_type == DisclosureSourceType.SEC_13F:
            await check_investor_13f(db, investor)
