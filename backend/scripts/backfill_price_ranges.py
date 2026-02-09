"""
Backfill price range data for existing holdings changes.
Fetches historical prices from Yahoo Finance and updates the database.
"""
import asyncio
import sys
from pathlib import Path
from datetime import date, timedelta
from decimal import Decimal

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select, update
from app.database import AsyncSessionLocal
from app.models.holdings import HoldingsChange


# Rate limit delay to avoid hitting Yahoo Finance limits
RATE_LIMIT_DELAY = 0.5  # seconds between API calls


async def fetch_yahoo_price_range(ticker: str, from_date: date, to_date: date):
    """Fetch price range from Yahoo Finance."""
    import yfinance as yf

    try:
        # Add buffer days to ensure we get data
        start = from_date - timedelta(days=5)
        end = to_date + timedelta(days=1)

        stock = yf.Ticker(ticker)
        df = stock.history(start=start.isoformat(), end=end.isoformat())

        if df.empty:
            return None, None

        # Filter to actual date range
        df = df[(df.index.date >= from_date) & (df.index.date <= to_date)]

        if df.empty:
            # If no data in exact range, use all available data
            stock = yf.Ticker(ticker)
            df = stock.history(start=start.isoformat(), end=end.isoformat())
            if df.empty:
                return None, None

        low = Decimal(str(round(df["Low"].min(), 2)))
        high = Decimal(str(round(df["High"].max(), 2)))

        return low, high

    except Exception as e:
        print(f"    Error: {e}")
        return None, None


async def backfill_prices():
    print("Backfilling price ranges for holdings changes using Yahoo Finance...")
    print()

    async with AsyncSessionLocal() as session:
        # Get all changes without price data
        result = await session.execute(
            select(HoldingsChange)
            .where(HoldingsChange.price_range_low.is_(None))
            .order_by(HoldingsChange.to_date.desc())
        )
        changes = result.scalars().all()

        print(f"Found {len(changes)} changes without price data")
        print()

        # Cache of ticker prices to avoid duplicate API calls
        ticker_prices = {}  # (ticker, from_date, to_date) -> (low, high)

        updated_count = 0
        skipped_count = 0
        error_count = 0

        for i, change in enumerate(changes):
            ticker = change.ticker
            from_date = change.from_date
            to_date = change.to_date

            # Skip if no valid dates
            if not from_date or not to_date:
                skipped_count += 1
                continue

            # Skip special tickers that won't have price data
            # - Tickers starting with * are CUSIP-derived placeholders
            # - Tickers with numbers or special chars
            # - Very long tickers
            if (ticker.startswith('*') or
                not ticker.replace('.', '').replace('-', '').isalnum() or
                len(ticker) > 6):
                skipped_count += 1
                continue

            # Check cache first
            cache_key = (ticker, from_date, to_date)
            if cache_key in ticker_prices:
                low, high = ticker_prices[cache_key]
            else:
                # Fetch price data
                print(f"[{i+1}/{len(changes)}] {ticker} ({from_date} to {to_date})...", end=" ")

                low, high = await fetch_yahoo_price_range(ticker, from_date, to_date)
                ticker_prices[cache_key] = (low, high)

                if low is None or high is None:
                    print("No data")
                    skipped_count += 1
                    continue

                print(f"${low} - ${high}")

                # Rate limiting
                await asyncio.sleep(RATE_LIMIT_DELAY)

            # Update the database
            if low is not None and high is not None:
                await session.execute(
                    update(HoldingsChange)
                    .where(HoldingsChange.id == change.id)
                    .values(
                        price_range_low=low,
                        price_range_high=high
                    )
                )
                updated_count += 1

            # Commit in batches
            if updated_count > 0 and updated_count % 20 == 0:
                await session.commit()
                print(f"  --- Committed {updated_count} updates ---")

        # Final commit
        await session.commit()

        print()
        print("=" * 50)
        print(f"Done!")
        print(f"  Updated: {updated_count}")
        print(f"  Skipped: {skipped_count}")
        print(f"  Errors: {error_count}")


if __name__ == "__main__":
    asyncio.run(backfill_prices())
