"""Database configuration and session management."""
import os
import logging
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy import event

from app.config import settings

logger = logging.getLogger(__name__)


def get_database_url() -> str:
    """
    Build the database URL based on configuration.
    Supports both direct URL and Cloud SQL Connector.
    """
    if settings.use_cloud_sql_connector and settings.cloud_sql_instance_connection_name:
        # For Cloud SQL with IAM auth or password auth via connector
        # The actual connection is handled by the connector, we use a placeholder
        db_user = settings.db_user or "postgres"
        db_pass = settings.db_pass or ""
        db_name = settings.db_name

        # When using Cloud SQL Connector, we construct URL differently
        # The connector handles the actual socket connection
        return f"postgresql+asyncpg://{db_user}:{db_pass}@/{db_name}"
    else:
        # Standard PostgreSQL URL
        database_url = settings.database_url
        if not database_url.startswith("postgresql+asyncpg://"):
            database_url = database_url.replace(
                "postgresql://", "postgresql+asyncpg://"
            )
        return database_url


def create_cloud_sql_engine():
    """Create engine with Cloud SQL Python Connector."""
    try:
        from google.cloud.sql.connector import Connector
        import asyncpg

        connector = Connector()

        async def getconn():
            conn = await connector.connect_async(
                settings.cloud_sql_instance_connection_name,
                "asyncpg",
                user=settings.db_user or "postgres",
                password=settings.db_pass or "",
                db=settings.db_name,
            )
            return conn

        engine = create_async_engine(
            "postgresql+asyncpg://",
            async_creator=getconn,
            echo=settings.debug,
            pool_pre_ping=True,
            pool_size=5,  # Cloud Run has limited connections
            max_overflow=10,
        )
        logger.info("Created Cloud SQL engine with connector")
        return engine

    except ImportError:
        logger.warning("Cloud SQL Connector not available, falling back to direct connection")
        return None
    except Exception as e:
        logger.error(f"Failed to create Cloud SQL engine: {e}")
        return None


def create_standard_engine():
    """Create standard PostgreSQL engine."""
    database_url = get_database_url()

    engine = create_async_engine(
        database_url,
        echo=settings.debug,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
    )
    logger.info("Created standard PostgreSQL engine")
    return engine


# Create the appropriate engine based on configuration
if settings.use_cloud_sql_connector and settings.cloud_sql_instance_connection_name:
    engine = create_cloud_sql_engine()
    if engine is None:
        engine = create_standard_engine()
else:
    engine = create_standard_engine()


AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

Base = declarative_base()


async def get_db() -> AsyncSession:
    """Dependency to get database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Sync engine for Alembic migrations
def get_sync_database_url() -> str:
    """Get synchronous database URL for Alembic."""
    url = os.environ.get("DATABASE_URL", settings.database_url)
    # Ensure it's a sync URL (not asyncpg)
    if "+asyncpg" in url:
        url = url.replace("+asyncpg", "")
    return url
