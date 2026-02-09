"""
Fetch REAL ARK trade data from arkfunds.io API.
This is actual buy/sell data, not fabricated.
"""
import asyncio
import sys
from pathlib import Path
from datetime import datetime, timedelta
from decimal import Decimal

sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.investor import Investor
from app.models.holdings import HoldingsChange, ChangeType


ARK_ETFS = ['ARKK', 'ARKW', 'ARKG', 'ARKF', 'ARKQ']


async def fetch_real_trades():
    """Fetch real ARK trades from arkfunds.io API."""
    print("Fetching REAL ARK trade data from arkfunds.io...")

    headers = {'User-Agent': 'Mozilla/5.0 (compatible; WhyTheyBuy/1.0)'}

    # Get trades from last 30 days
    date_to = datetime.now().strftime('%Y-%m-%d')
    date_from = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')

    async with httpx.AsyncClient(headers=headers, timeout=30) as client:
        async with AsyncSessionLocal() as session:
            for etf in ARK_ETFS:
                print(f"\n  Fetching {etf} trades...")

                # Get investor
                result = await session.execute(
                    select(Investor).where(Investor.short_name == etf)
                )
                investor = result.scalar_one_or_none()

                if not investor:
                    print(f"    Investor not found for {etf}")
                    continue

                try:
                    # Fetch from arkfunds.io API
                    url = f"https://arkfunds.io/api/v2/etf/trades?symbol={etf}&date_from={date_from}&date_to={date_to}"
                    response = await client.get(url)
                    response.raise_for_status()
                    data = response.json()

                    trades = data.get('trades', [])
                    if not trades:
                        print(f"    No trades found for {etf}")
                        continue

                    print(f"    Found {len(trades)} real trades")

                    # Store each trade as a HoldingsChange
                    for trade in trades:
                        direction = trade.get('direction', '').lower()

                        if direction == 'buy':
                            change_type = ChangeType.ADDED
                            shares_delta = Decimal(str(trade.get('shares', 0)))
                        elif direction == 'sell':
                            change_type = ChangeType.REDUCED
                            shares_delta = -Decimal(str(trade.get('shares', 0)))
                        else:
                            continue

                        trade_date = datetime.strptime(trade['date'], '%Y-%m-%d').date()

                        # Check if this trade already exists
                        existing = await session.execute(
                            select(HoldingsChange).where(
                                HoldingsChange.investor_id == investor.id,
                                HoldingsChange.ticker == trade['ticker'],
                                HoldingsChange.to_date == trade_date,
                                HoldingsChange.shares_delta == shares_delta,
                            )
                        )
                        if existing.scalar_one_or_none():
                            continue  # Skip duplicate

                        change = HoldingsChange(
                            investor_id=investor.id,
                            ticker=trade['ticker'],
                            company_name=trade.get('company', trade['ticker']),
                            change_type=change_type,
                            from_date=trade_date,
                            to_date=trade_date,
                            shares_delta=shares_delta,
                            weight_delta=Decimal(str(trade.get('etf_percent', 0))) if direction == 'buy' else -Decimal(str(trade.get('etf_percent', 0))),
                        )
                        session.add(change)

                    await session.commit()
                    print(f"    Saved {etf} trades")

                except httpx.HTTPError as e:
                    print(f"    HTTP error: {e}")
                except Exception as e:
                    print(f"    Error: {e}")

    print("\nReal ARK trades fetched!")


async def main():
    # First, clear any existing (fake) ARK changes
    async with AsyncSessionLocal() as session:
        from sqlalchemy import text
        await session.execute(text("""
            DELETE FROM holdings_changes
            WHERE investor_id IN (
                SELECT id FROM investors WHERE short_name IN ('ARKK', 'ARKW', 'ARKG', 'ARKF', 'ARKQ')
            )
        """))
        await session.commit()
        print("Cleared old ARK changes")

    await fetch_real_trades()


if __name__ == "__main__":
    asyncio.run(main())
