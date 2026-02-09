"""
Seed script for sample holdings changes and trades.

Creates realistic holdings changes and investor actions for ARKK
so the AI summary and company rationale endpoints have data to work with.

Usage:
    python -m scripts.seed_holdings
"""
import asyncio
import sys
from pathlib import Path
from datetime import date, timedelta
from decimal import Decimal

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.investor import Investor
from app.models.holdings import (
    HoldingsChange,
    InvestorAction,
    ChangeType,
    ActionType,
)


ARKK_CHANGES = [
    {
        "ticker": "TSLA",
        "company_name": "Tesla Inc.",
        "change_type": ChangeType.ADDED,
        "days_ago": 3,
        "shares_before": 1_200_000,
        "shares_after": 1_350_000,
        "shares_delta": 150_000,
        "weight_before": 8.5,
        "weight_after": 9.2,
        "weight_delta": 0.7,
        "value_before": 300_000_000,
        "value_after": 345_000_000,
        "value_delta": 45_000_000,
        "price_range_low": 240.50,
        "price_range_high": 258.30,
        "trades": [
            {"action": ActionType.BUY, "shares": 80_000, "value": 19_600_000, "fund": "ARKK", "days_ago": 3},
            {"action": ActionType.BUY, "shares": 70_000, "value": 17_500_000, "fund": "ARKK", "days_ago": 2},
        ],
    },
    {
        "ticker": "COIN",
        "company_name": "Coinbase Global Inc.",
        "change_type": ChangeType.NEW,
        "days_ago": 5,
        "shares_before": 0,
        "shares_after": 85_000,
        "shares_delta": 85_000,
        "weight_before": 0,
        "weight_after": 0.3,
        "weight_delta": 0.3,
        "value_before": 0,
        "value_after": 19_550_000,
        "value_delta": 19_550_000,
        "price_range_low": 218.00,
        "price_range_high": 235.40,
        "trades": [
            {"action": ActionType.BUY, "shares": 85_000, "value": 19_550_000, "fund": "ARKK", "days_ago": 5},
        ],
    },
    {
        "ticker": "PLTR",
        "company_name": "Palantir Technologies Inc.",
        "change_type": ChangeType.ADDED,
        "days_ago": 4,
        "shares_before": 500_000,
        "shares_after": 560_000,
        "shares_delta": 60_000,
        "weight_before": 1.8,
        "weight_after": 2.1,
        "weight_delta": 0.3,
        "value_before": 35_000_000,
        "value_after": 42_000_000,
        "value_delta": 7_000_000,
        "price_range_low": 68.20,
        "price_range_high": 75.80,
        "trades": [
            {"action": ActionType.BUY, "shares": 60_000, "value": 4_200_000, "fund": "ARKK", "days_ago": 4},
        ],
    },
    {
        "ticker": "ROKU",
        "company_name": "Roku Inc.",
        "change_type": ChangeType.REDUCED,
        "days_ago": 2,
        "shares_before": 800_000,
        "shares_after": 650_000,
        "shares_delta": -150_000,
        "weight_before": 3.2,
        "weight_after": 2.5,
        "weight_delta": -0.7,
        "value_before": 56_000_000,
        "value_after": 44_200_000,
        "value_delta": -11_800_000,
        "price_range_low": 62.10,
        "price_range_high": 68.50,
        "trades": [
            {"action": ActionType.SELL, "shares": 150_000, "value": 9_750_000, "fund": "ARKK", "days_ago": 2},
        ],
    },
    {
        "ticker": "SQ",
        "company_name": "Block Inc.",
        "change_type": ChangeType.SOLD_OUT,
        "days_ago": 6,
        "shares_before": 250_000,
        "shares_after": 0,
        "shares_delta": -250_000,
        "weight_before": 0.8,
        "weight_after": 0,
        "weight_delta": -0.8,
        "value_before": 15_000_000,
        "value_after": 0,
        "value_delta": -15_000_000,
        "price_range_low": 58.20,
        "price_range_high": 62.40,
        "trades": [
            {"action": ActionType.SELL, "shares": 250_000, "value": 15_000_000, "fund": "ARKK", "days_ago": 6},
        ],
    },
    {
        "ticker": "RKLB",
        "company_name": "Rocket Lab USA Inc.",
        "change_type": ChangeType.ADDED,
        "days_ago": 1,
        "shares_before": 2_000_000,
        "shares_after": 2_300_000,
        "shares_delta": 300_000,
        "weight_before": 2.0,
        "weight_after": 2.4,
        "weight_delta": 0.4,
        "value_before": 40_000_000,
        "value_after": 48_300_000,
        "value_delta": 8_300_000,
        "price_range_low": 19.50,
        "price_range_high": 21.80,
        "trades": [
            {"action": ActionType.BUY, "shares": 200_000, "value": 4_100_000, "fund": "ARKK", "days_ago": 1},
            {"action": ActionType.BUY, "shares": 100_000, "value": 2_050_000, "fund": "ARKW", "days_ago": 1},
        ],
    },
    {
        "ticker": "PATH",
        "company_name": "UiPath Inc.",
        "change_type": ChangeType.REDUCED,
        "days_ago": 3,
        "shares_before": 1_500_000,
        "shares_after": 1_200_000,
        "shares_delta": -300_000,
        "weight_before": 1.5,
        "weight_after": 1.1,
        "weight_delta": -0.4,
        "value_before": 22_500_000,
        "value_after": 16_800_000,
        "value_delta": -5_700_000,
        "price_range_low": 13.20,
        "price_range_high": 14.80,
        "trades": [
            {"action": ActionType.SELL, "shares": 300_000, "value": 4_200_000, "fund": "ARKK", "days_ago": 3},
        ],
    },
]


async def seed_holdings():
    """Seed sample holdings changes for ARKK."""
    async with AsyncSessionLocal() as session:
        # Find ARKK investor
        result = await session.execute(
            select(Investor).where(Investor.slug == "ark-arkk")
        )
        arkk = result.scalar_one_or_none()

        if not arkk:
            print("ARKK investor not found. Run seed_data.py first.")
            return

        # Check if changes already exist
        existing = await session.execute(
            select(HoldingsChange).where(HoldingsChange.investor_id == arkk.id).limit(1)
        )
        if existing.scalar_one_or_none():
            print("Holdings changes already exist for ARKK. Skipping.")
            return

        today = date.today()

        for change_data in ARKK_CHANGES:
            to_date = today - timedelta(days=change_data["days_ago"])
            from_date = to_date - timedelta(days=1)

            change = HoldingsChange(
                investor_id=arkk.id,
                ticker=change_data["ticker"],
                company_name=change_data["company_name"],
                change_type=change_data["change_type"],
                from_date=from_date,
                to_date=to_date,
                shares_before=Decimal(str(change_data["shares_before"])),
                shares_after=Decimal(str(change_data["shares_after"])),
                shares_delta=Decimal(str(change_data["shares_delta"])),
                weight_before=Decimal(str(change_data["weight_before"])),
                weight_after=Decimal(str(change_data["weight_after"])),
                weight_delta=Decimal(str(change_data["weight_delta"])),
                value_before=Decimal(str(change_data["value_before"])),
                value_after=Decimal(str(change_data["value_after"])),
                value_delta=Decimal(str(change_data["value_delta"])),
                price_range_low=Decimal(str(change_data["price_range_low"])),
                price_range_high=Decimal(str(change_data["price_range_high"])),
            )
            session.add(change)

            # Create trades
            for trade_data in change_data["trades"]:
                trade_date = today - timedelta(days=trade_data["days_ago"])
                action = InvestorAction(
                    investor_id=arkk.id,
                    action_type=trade_data["action"],
                    ticker=change_data["ticker"],
                    company_name=change_data["company_name"],
                    trade_date=trade_date,
                    shares=Decimal(str(trade_data["shares"])),
                    estimated_value=Decimal(str(trade_data["value"])),
                    fund_name=trade_data["fund"],
                    price_range_low=Decimal(str(change_data["price_range_low"])),
                    price_range_high=Decimal(str(change_data["price_range_high"])),
                )
                session.add(action)

            print(f"  {change_data['change_type'].value.upper():>8} {change_data['ticker']:<6} {change_data['company_name']}")

        await session.commit()
        print(f"\nCreated {len(ARKK_CHANGES)} holdings changes for ARKK")


async def main():
    print("Seeding sample holdings changes for ARKK...\n")
    await seed_holdings()
    print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())
