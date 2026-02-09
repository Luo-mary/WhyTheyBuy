"""
Reseed holdings with sector information.

This script deletes old holdings data and recreates it with sector classifications.
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select, delete
from app.database import AsyncSessionLocal
from app.models.investor import Investor
from app.models.holdings import HoldingsSnapshot, HoldingsChange


async def main():
    """Delete old holdings and reseed."""
    async with AsyncSessionLocal() as session:
        print("🗑️  Deleting old holdings snapshots...\n")
        
        # Delete all holdings snapshots (cascades to records and changes)
        await session.execute(delete(HoldingsSnapshot))
        await session.commit()
        
        print("✅ Deleted old holdings data\n")
        print("📊 Now reseeding with sector information...\n")
        
        # Import and run the seed_holdings function
        from scripts.seed_data import seed_holdings
        await seed_holdings()


if __name__ == "__main__":
    asyncio.run(main())
