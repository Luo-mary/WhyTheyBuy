"""Alembic environment configuration."""
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool, create_engine
from alembic import context

# this is the Alembic Config object
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Import all models so Alembic can detect them for autogenerate
from app.database import Base, get_sync_database_url
import app.models  # noqa: F401 - ensures all models are registered

target_metadata = Base.metadata


def get_url() -> str:
    """Get database URL from environment or config."""
    # Priority: DATABASE_URL env var > alembic.ini config
    url = os.environ.get("DATABASE_URL")
    if url:
        # Ensure it's a sync URL (not asyncpg)
        if "+asyncpg" in url:
            url = url.replace("+asyncpg", "")
        return url
    return config.get_main_option("sqlalchemy.url")


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    # Get URL from environment or config
    url = get_url()

    # Create engine directly with the URL
    connectable = create_engine(
        url,
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
