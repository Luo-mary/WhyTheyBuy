"""
Initialize Cloud SQL database with all tables.
Run this once for a fresh database before running migrations.
"""
import os
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine, text
from app.database import Base

# Import all models to register them with Base
from app.models.user import User, UserEmail, PasswordResetToken
from app.models.investor import Investor, InvestorType, StrategyNote, DisclosureSource
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange, InvestorAction
from app.models.company import Company, MarketPrice
from app.models.watchlist import Watchlist, WatchlistItem
from app.models.report import Report, AICompanyReport
from app.models.subscription import Subscription, SubscriptionPlan


def init_database():
    """Create all tables in the database."""
    database_url = os.environ.get("DATABASE_URL")

    if not database_url:
        print("ERROR: DATABASE_URL environment variable not set")
        print("Usage: DATABASE_URL='postgresql://...' python scripts/init_cloud_db.py")
        sys.exit(1)

    # Ensure sync driver
    if "+asyncpg" in database_url:
        database_url = database_url.replace("+asyncpg", "")

    print(f"Connecting to database...")
    engine = create_engine(database_url, echo=True)

    # Test connection
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version()"))
        version = result.scalar()
        print(f"Connected to: {version}")

    print("\nCreating all tables...")
    Base.metadata.create_all(engine)

    print("\nTables created successfully!")

    # List created tables
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT tablename FROM pg_tables
            WHERE schemaname = 'public'
            ORDER BY tablename
        """))
        tables = [row[0] for row in result]
        print(f"\nCreated {len(tables)} tables:")
        for table in tables:
            print(f"  - {table}")

    print("\nNext step: Run 'alembic stamp head' to mark migrations as applied")


if __name__ == "__main__":
    init_database()
