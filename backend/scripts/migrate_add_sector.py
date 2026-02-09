"""
Add sector column to holding_records table.

This script:
1. Drops the old holding_records table (and dependent tables)
2. Recreates the table with sector column
3. Reseeds the data
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.database import AsyncSessionLocal, engine
from app.models import (
    HoldingsSnapshot,
    HoldingRecord,
    HoldingsChange,
    InvestorAction,
)


async def main():
    """Migrate database schema and reseed data."""
    print("🔧 Migrating database schema...\n")
    
    # Get a regular (non-async) connection to run raw SQL
    from sqlalchemy.pool import StaticPool
    from sqlalchemy import create_engine
    import os
    
    db_url = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@localhost/whytheybuy")
    # Convert async URL to sync
    db_url_sync = db_url.replace("postgresql+asyncpg://", "postgresql://")
    
    sync_engine = create_engine(db_url_sync)
    
    try:
        with sync_engine.connect() as conn:
            print("🗑️  Dropping dependent tables...")
            conn.execute(text("DROP TABLE IF EXISTS investor_actions CASCADE"))
            conn.execute(text("DROP TABLE IF EXISTS holdings_changes CASCADE"))
            conn.execute(text("DROP TABLE IF EXISTS holding_records CASCADE"))
            conn.execute(text("DROP TABLE IF EXISTS holdings_snapshots CASCADE"))
            conn.commit()
            print("✅ Dropped old tables\n")
            
        print("🏗️  Recreating tables with updated schema...\n")
        # Create all tables from models
        from sqlalchemy.orm import declarative_base
        from app.database import Base
        
        # Create sync version of metadata
        Base.metadata.create_all(sync_engine)
        print("✅ Tables recreated\n")
        
    finally:
        sync_engine.dispose()
    
    # Now reseed the data using async
    print("📊 Reseeding holdings data with sector information...\n")
    from scripts.seed_data import seed_investors, seed_holdings
    
    await seed_investors()
    await seed_holdings()
    
    print("\n✅ Migration and reseed complete!")


if __name__ == "__main__":
    asyncio.run(main())
