"""Celery worker configuration and tasks."""
from celery import Celery
from celery.schedules import crontab

from app.config import settings

# Get Redis URL (supports both direct URL and component-based config)
redis_url = settings.get_redis_url()

# Create Celery app
celery_app = Celery(
    "whytheybuy",
    broker=redis_url,
    backend=redis_url,
    include=[
        "app.tasks.ingestion",
        "app.tasks.notifications",
        "app.tasks.market_data",
    ],
)

# Configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour max
    worker_prefetch_multiplier=1,
    task_acks_late=True,
)

# Beat schedule (periodic tasks)
celery_app.conf.beat_schedule = {
    # ARK daily ingestion at 23:00 UTC (after market close)
    "ingest-ark-daily": {
        "task": "app.tasks.ingestion.ingest_ark_holdings",
        "schedule": crontab(hour=23, minute=0),
    },
    # Check for new 13F filings daily at 08:00 UTC
    "check-13f-filings": {
        "task": "app.tasks.ingestion.check_13f_filings",
        "schedule": crontab(hour=8, minute=0),
    },
    # Send daily digest at 07:00 UTC
    "send-daily-digest": {
        "task": "app.tasks.notifications.send_daily_digest",
        "schedule": crontab(hour=7, minute=0),
    },
    # Send weekly digest on Sundays at 08:00 UTC
    "send-weekly-digest": {
        "task": "app.tasks.notifications.send_weekly_digest",
        "schedule": crontab(hour=8, minute=0, day_of_week=0),
    },
    # Refresh company profiles weekly
    "refresh-company-profiles": {
        "task": "app.tasks.market_data.refresh_company_profiles",
        "schedule": crontab(hour=6, minute=0, day_of_week=0),
    },
}


# For running with: celery -A app.worker worker --loglevel=info
