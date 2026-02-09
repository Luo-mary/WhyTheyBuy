"""
Reset database and load ONLY real data.

This script:
1. Clears all existing holdings, investors, and related data
2. Runs setup_real_data.py to fetch fresh real data

Usage:
    python -m scripts.reset_to_real_data
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from app.database import AsyncSessionLocal


async def clear_all_data():
    """Clear all holdings and investor data from the database."""
    print("Clearing existing data...")

    async with AsyncSessionLocal() as session:
        # Order matters due to foreign key constraints
        tables_to_clear = [
            "ai_company_reports",
            "holdings_changes",
            "holding_records",
            "holdings_snapshots",
            "watchlist_items",
            "strategy_notes",
            "disclosure_sources",
            "investors",
        ]

        for table in tables_to_clear:
            try:
                await session.execute(text(f"DELETE FROM {table}"))
                print(f"  Cleared: {table}")
            except Exception as e:
                print(f"  Warning: Could not clear {table}: {e}")

        await session.commit()

    print("Data cleared!\n")


async def main():
    """Main entry point."""
    print("=" * 60)
    print("WhyTheyBuy - Reset to Real Data Only")
    print("=" * 60)
    print("\nThis will:")
    print("  1. Delete ALL existing investor and holdings data")
    print("  2. Fetch fresh real data from ARK and SEC EDGAR")
    print()

    # Ask for confirmation
    confirm = input("Continue? (yes/no): ").strip().lower()
    if confirm != "yes":
        print("Cancelled.")
        return

    print()

    # Clear existing data
    await clear_all_data()

    # Import and run real data setup
    from scripts.setup_real_data import main as setup_real_data
    await setup_real_data()


if __name__ == "__main__":
    asyncio.run(main())
