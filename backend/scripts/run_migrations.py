#!/usr/bin/env python3
"""
Script to run database migrations.
Can be used as a Cloud Run Job or locally.

Usage:
    python scripts/run_migrations.py

For Cloud Run Jobs:
    gcloud run jobs create migrate-db \
        --image=gcr.io/PROJECT_ID/whytheybuy-api:latest \
        --command=python \
        --args=scripts/run_migrations.py \
        --region=us-central1 \
        --set-cloudsql-instances=PROJECT_ID:REGION:INSTANCE \
        --set-env-vars=DATABASE_URL=...
"""

import os
import sys
import subprocess
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def run_migrations():
    """Run Alembic migrations."""
    # Ensure we're in the right directory
    backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(backend_dir)

    logger.info("Starting database migrations...")
    logger.info(f"Working directory: {os.getcwd()}")

    # Check if DATABASE_URL is set
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        logger.error("DATABASE_URL environment variable is not set!")
        sys.exit(1)

    # Run alembic upgrade
    try:
        result = subprocess.run(
            ["alembic", "upgrade", "head"],
            check=True,
            capture_output=True,
            text=True,
        )
        logger.info("Migration output:")
        logger.info(result.stdout)
        if result.stderr:
            logger.warning(result.stderr)
        logger.info("Migrations completed successfully!")
    except subprocess.CalledProcessError as e:
        logger.error(f"Migration failed with return code {e.returncode}")
        logger.error(f"stdout: {e.stdout}")
        logger.error(f"stderr: {e.stderr}")
        sys.exit(1)


if __name__ == "__main__":
    run_migrations()
