"""
Create test user for WhyTheyBuy.

Usage:
    python -m scripts.create_test_user
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.user import User
from app.services.auth import hash_password


async def create_test_user():
    """Create a test user for development."""
    async with AsyncSessionLocal() as db:
        # Check if user already exists
        result = await db.execute(
            select(User).where(User.email == "test@example.com")
        )
        existing_user = result.scalar_one_or_none()
        
        if existing_user:
            print("✅ Test user already exists!")
            print(f"   Email: test@example.com")
            print(f"   Password: password123")
            return
        
        # Create test user
        test_user = User(
            email="test@example.com",
            hashed_password=hash_password("password123"),
            name="Test User",
            is_active=True,
            email_verified=True,
        )
        
        db.add(test_user)
        await db.commit()
        
        print("✅ Test user created successfully!")
        print(f"   Email: test@example.com")
        print(f"   Password: password123")


async def main():
    """Main entry point."""
    await create_test_user()


if __name__ == "__main__":
    asyncio.run(main())
