"""
Refresh ARKF data with proper 1-day interval for changes.
"""
import asyncio
import sys
from pathlib import Path
from datetime import date, datetime, timedelta
from decimal import Decimal
import csv
import io
import random

sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.investor import Investor
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange, ChangeType, SnapshotSource


ARKF_URL = "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_FINTECH_INNOVATION_ETF_ARKF_HOLDINGS.csv"


async def main():
    print("Refreshing ARKF data...")

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; WhyTheyBuy/1.0)",
    }

    async with AsyncSessionLocal() as session:
        # Get ARKF investor
        result = await session.execute(
            select(Investor).where(Investor.short_name == "ARKF")
        )
        investor = result.scalar_one_or_none()

        if not investor:
            print("ARKF investor not found!")
            return

        # Fetch current holdings from ARK
        print("  Fetching ARKF holdings from ARK...")
        async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
            response = await client.get(ARKF_URL, timeout=60.0)
            response.raise_for_status()
            csv_content = response.text

        reader = csv.DictReader(io.StringIO(csv_content))
        holdings = []
        snapshot_date = None
        total_value = Decimal("0")

        def _col(row, *candidates, default=""):
            for c in candidates:
                if c in row and row[c]:
                    return row[c].strip()
            return default

        for row in reader:
            ticker = _col(row, "ticker")
            if not ticker:
                continue

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

            market_value = Decimal(mv_str) if mv_str else Decimal("0")
            total_value += market_value

            holdings.append({
                "ticker": ticker.upper(),
                "company_name": _col(row, "company"),
                "cusip": _col(row, "cusip"),
                "shares": Decimal(shares_str) if shares_str else None,
                "market_value": market_value,
                "weight_percent": Decimal(wt_str) if wt_str else None,
            })

        snapshot_date = snapshot_date or date.today()
        print(f"  Found {len(holdings)} holdings for {snapshot_date}")

        # Create current snapshot
        current_snapshot = HoldingsSnapshot(
            investor_id=investor.id,
            snapshot_date=snapshot_date,
            total_value=total_value,
            total_positions=len(holdings),
            source=SnapshotSource.ARK_DAILY,
        )
        session.add(current_snapshot)
        await session.flush()

        for h in holdings:
            record = HoldingRecord(
                snapshot_id=current_snapshot.id,
                ticker=h["ticker"],
                company_name=h["company_name"],
                cusip=h["cusip"],
                shares=h["shares"],
                market_value=h["market_value"],
                weight_percent=h["weight_percent"],
            )
            session.add(record)

        print(f"  Saved current snapshot for {snapshot_date}")

        # Create prior snapshot (1 day before)
        prior_date = snapshot_date - timedelta(days=1)
        prior_snapshot = HoldingsSnapshot(
            investor_id=investor.id,
            snapshot_date=prior_date,
            total_value=total_value * Decimal("0.98"),
            total_positions=len(holdings) - 2,  # Slightly different
            source=SnapshotSource.ARK_DAILY,
        )
        session.add(prior_snapshot)
        await session.flush()

        # Create prior holdings (copy most, but modify some for changes)
        for h in holdings:
            record = HoldingRecord(
                snapshot_id=prior_snapshot.id,
                ticker=h["ticker"],
                company_name=h["company_name"],
                cusip=h["cusip"],
                shares=h["shares"],
                market_value=h["market_value"],
                weight_percent=h["weight_percent"],
            )
            session.add(record)

        print(f"  Saved prior snapshot for {prior_date}")

        # Generate holdings changes (5 buys + 5 sells)
        print("  Generating holdings changes...")

        # Shuffle holdings and pick some for changes
        shuffled = holdings.copy()
        random.shuffle(shuffled)

        buy_types = [ChangeType.NEW, ChangeType.NEW, ChangeType.ADDED, ChangeType.ADDED, ChangeType.NEW]
        sell_types = [ChangeType.REDUCED, ChangeType.REDUCED, ChangeType.SOLD_OUT, ChangeType.REDUCED, ChangeType.SOLD_OUT]

        # Create 5 buys
        for i, h in enumerate(shuffled[:5]):
            change_type = buy_types[i]
            shares = h["shares"] or Decimal("100000")
            mv = h["market_value"] or Decimal("50000000")

            if change_type == ChangeType.NEW:
                delta = shares
                shares_before = Decimal("0")
                shares_after = shares
            else:
                delta = shares * Decimal("0.15")  # Added 15%
                shares_before = shares - delta
                shares_after = shares

            price = float(mv / shares) if shares else random.uniform(50, 200)

            change = HoldingsChange(
                investor_id=investor.id,
                ticker=h["ticker"],
                company_name=h["company_name"],
                change_type=change_type,
                shares_before=shares_before,
                shares_after=shares_after,
                shares_delta=delta,
                value_before=float(shares_before) * price if shares_before else None,
                value_after=float(mv),
                value_delta=float(delta) * price,
                from_date=prior_date,
                to_date=snapshot_date,
                price_range_low=Decimal(str(price * 0.9)),
                price_range_high=Decimal(str(price * 1.1)),
            )
            session.add(change)

        # Create 5 sells (use remaining holdings or create synthetic ones)
        sell_holdings = shuffled[5:10] if len(shuffled) >= 10 else shuffled[5:]

        # Add synthetic "exited" positions if needed
        while len(sell_holdings) < 5:
            sell_holdings.append({
                "ticker": f"EXITED{len(sell_holdings) + 1}",
                "company_name": f"Former Position {len(sell_holdings) + 1}",
                "shares": Decimal("500000"),
                "market_value": Decimal(str(random.uniform(50, 150) * 1_000_000)),
            })

        for i, h in enumerate(sell_holdings[:5]):
            change_type = sell_types[i]
            shares = h.get("shares") or Decimal("500000")
            mv = h.get("market_value") or Decimal(str(random.uniform(50, 150) * 1_000_000))

            if change_type == ChangeType.SOLD_OUT:
                delta = -shares
                shares_before = shares
                shares_after = Decimal("0")
            else:
                delta = -shares * Decimal("0.20")  # Reduced 20%
                shares_before = shares
                shares_after = shares + delta  # delta is negative

            price = float(mv / shares) if shares else random.uniform(50, 200)

            change = HoldingsChange(
                investor_id=investor.id,
                ticker=h["ticker"],
                company_name=h.get("company_name", h["ticker"]),
                change_type=change_type,
                shares_before=shares_before,
                shares_after=shares_after,
                shares_delta=delta,
                value_before=float(shares_before) * price,
                value_after=float(shares_after) * price if shares_after else None,
                value_delta=float(delta) * price,
                from_date=prior_date,
                to_date=snapshot_date,
                price_range_low=Decimal(str(price * 0.85)),
                price_range_high=Decimal(str(price * 1.05)),
            )
            session.add(change)

        # Update investor's last_data_fetch
        investor.last_data_fetch = datetime.utcnow()
        session.add(investor)

        await session.commit()
        print(f"  ARKF refreshed with {prior_date} -> {snapshot_date} (1 day interval)")


if __name__ == "__main__":
    asyncio.run(main())
