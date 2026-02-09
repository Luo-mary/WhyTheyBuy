"""
Initialize database tables.

Usage:
    python -m scripts.init_db
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.database import engine, Base

# Import all models to register them with Base
from app.models.user import User, UserEmail, PasswordResetToken
from app.models.investor import Investor, DisclosureSource, StrategyNote
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange
from app.models.company import Company, MarketPrice
from app.models.watchlist import Watchlist, WatchlistItem
from app.models.report import Report, AICompanyReport
from app.models.subscription import Subscription, SubscriptionPlan


async def init_db():
    """Create all database tables."""
    print("🗄️  Creating database tables...")

    async with engine.begin() as conn:
        # Create all tables
        await conn.run_sync(Base.metadata.create_all)

    print("✅ Database tables created successfully!")


async def drop_db():
    """Drop all database tables (use with caution!)."""
    print("⚠️  Dropping all database tables...")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    print("✅ All tables dropped!")


async def main():
    """Main entry point."""
    await init_db()


if __name__ == "__main__":
    asyncio.run(main())
