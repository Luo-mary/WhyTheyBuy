"""Notification tasks."""
import logging
from datetime import date, datetime, timedelta
from uuid import UUID

from app.worker import celery_app
from app.tasks.ingestion import _make_task_session_factory
from app.models.user import User, UserEmail
from app.models.investor import Investor
from app.models.watchlist import Watchlist, WatchlistItem, NotificationFrequency
from app.models.holdings import HoldingsChange
from app.models.report import Report, ReportType
from app.models.subscription import Subscription
from app.services.ai import generate_investor_summary
from app.services.email import send_holdings_change_alert, send_weekly_digest
from app.config import settings
from sqlalchemy import select
from sqlalchemy.orm import selectinload

logger = logging.getLogger(__name__)


@celery_app.task
def notify_holdings_change(investor_id: str, change_date: str):
    """
    Notify users about holdings changes for an investor.
    
    This task:
    1. Finds all users watching this investor
    2. Generates AI summary
    3. Creates report records
    4. Sends emails based on user preferences
    """
    import asyncio
    asyncio.run(_notify_holdings_change_async(investor_id, change_date))


async def _notify_holdings_change_async(investor_id: str, change_date: str):
    """Async implementation of holdings change notification."""
    logger.info(f"Processing notifications for investor {investor_id}")
    
    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        # Get investor
        result = await db.execute(
            select(Investor).where(Investor.id == investor_id)
        )
        investor = result.scalar_one_or_none()
        
        if not investor:
            logger.error(f"Investor not found: {investor_id}")
            return
        
        # Get recent changes
        change_date_obj = date.fromisoformat(change_date)
        changes_result = await db.execute(
            select(HoldingsChange)
            .where(
                HoldingsChange.investor_id == investor_id,
                HoldingsChange.to_date == change_date_obj,
            )
            .order_by(HoldingsChange.weight_delta.desc().nullslast())
        )
        changes = changes_result.scalars().all()
        
        if not changes:
            logger.info(f"No changes found for {investor.name} on {change_date}")
            return
        
        # Generate AI summary
        try:
            summary = await generate_investor_summary(investor, changes)
            summary_dict = summary.model_dump()
        except Exception as e:
            logger.error(f"Error generating AI summary: {e}")
            summary_dict = {
                "headline": f"{investor.name} Holdings Update",
                "what_changed": [f"{len(changes)} position changes detected"],
                "top_buys": [],
                "top_sells": [],
                "notable_moves": [],
                "one_paragraph_insight": "Summary generation failed. Please review the changes manually.",
                "risk_note": "Not financial advice.",
            }
        
        # Find all users watching this investor
        watchlist_items_result = await db.execute(
            select(WatchlistItem)
            .join(Watchlist)
            .options(selectinload(WatchlistItem.watchlist))
            .where(
                WatchlistItem.investor_id == investor_id,
                WatchlistItem.email_enabled == True,
            )
        )
        watchlist_items = watchlist_items_result.scalars().all()
        
        for item in watchlist_items:
            user_id = item.watchlist.user_id
            
            # Get user
            user_result = await db.execute(
                select(User).where(User.id == user_id, User.is_active == True)
            )
            user = user_result.scalar_one_or_none()
            
            if not user:
                continue
            
            # Check subscription for instant alerts
            if item.notification_frequency == NotificationFrequency.INSTANT:
                sub_result = await db.execute(
                    select(Subscription).where(Subscription.user_id == user_id)
                )
                subscription = sub_result.scalar_one_or_none()
                
                if not subscription or not subscription.can_instant_alerts:
                    continue
            elif item.notification_frequency == NotificationFrequency.WEEKLY:
                # Will be handled by weekly digest
                continue
            elif item.notification_frequency == NotificationFrequency.DAILY:
                # Will be handled by daily digest
                continue
            
            # Create report record
            report = Report(
                user_id=user_id,
                investor_id=investor.id,
                report_type=ReportType.INVESTOR_CHANGE,
                report_date=change_date_obj,
                title=summary_dict.get("headline", f"{investor.name} Holdings Update"),
                summary_json=summary_dict,
            )
            db.add(report)
            await db.flush()
            
            # Send email
            report_url = f"{settings.app_url}/reports/{report.id}"
            
            # Get user's notification emails
            emails_result = await db.execute(
                select(UserEmail).where(
                    UserEmail.user_id == user_id,
                    UserEmail.is_verified == True,
                    UserEmail.receive_notifications == True,
                )
            )
            user_emails = emails_result.scalars().all()
            
            # If no additional emails, use primary email
            email_addresses = [e.email for e in user_emails] if user_emails else [user.email]
            
            for email_addr in email_addresses:
                success = await send_holdings_change_alert(
                    to_email=email_addr,
                    investor_name=investor.name,
                    summary=summary_dict,
                    report_url=report_url,
                )
                
                if success:
                    report.email_sent = True
                    report.email_sent_at = datetime.utcnow()
                    report.email_recipient = email_addr
        
        await db.commit()
        logger.info(f"Notifications processed for {investor.name}")


@celery_app.task
def send_daily_digest():
    """Send daily digest emails to Pro users."""
    import asyncio
    asyncio.run(_send_daily_digest_async())


async def _send_daily_digest_async():
    """Async implementation of daily digest."""
    logger.info("Sending daily digests")
    
    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        # Get Pro users with daily digest preference
        result = await db.execute(
            select(User)
            .join(Subscription)
            .where(
                User.is_active == True,
                Subscription.plan.in_(["pro_monthly", "pro_yearly"]),
                Subscription.status == "active",
            )
        )
        users = result.scalars().all()
        
        yesterday = date.today() - timedelta(days=1)
        
        for user in users:
            # Get user's watchlist items with daily frequency
            items_result = await db.execute(
                select(WatchlistItem)
                .join(Watchlist)
                .where(
                    Watchlist.user_id == user.id,
                    WatchlistItem.notification_frequency == NotificationFrequency.DAILY,
                    WatchlistItem.email_enabled == True,
                )
            )
            items = items_result.scalars().all()
            
            if not items:
                continue
            
            # Gather changes for watched investors
            investor_summaries = []
            for item in items:
                changes_result = await db.execute(
                    select(HoldingsChange)
                    .join(Investor)
                    .where(
                        HoldingsChange.investor_id == item.investor_id,
                        HoldingsChange.to_date == yesterday,
                    )
                )
                changes = changes_result.scalars().all()
                
                if changes:
                    investor_result = await db.execute(
                        select(Investor).where(Investor.id == item.investor_id)
                    )
                    investor = investor_result.scalar_one()
                    
                    investor_summaries.append({
                        "name": investor.name,
                        "summary": f"{len(changes)} position changes",
                        "buys": sum(1 for c in changes if c.change_type.value in ["new", "added"]),
                        "sells": sum(1 for c in changes if c.change_type.value in ["reduced", "sold_out"]),
                    })
            
            if investor_summaries:
                # Create report
                report = Report(
                    user_id=user.id,
                    report_type=ReportType.DAILY_DIGEST,
                    report_date=yesterday,
                    title=f"Daily Digest - {yesterday}",
                    summary_json={"investors": investor_summaries},
                )
                db.add(report)
                
                # Would send email here - similar to weekly digest
        
        await db.commit()
        logger.info("Daily digests sent")


@celery_app.task
def send_weekly_digest():
    """Send weekly digest emails."""
    import asyncio
    asyncio.run(_send_weekly_digest_async())


async def _send_weekly_digest_async():
    """Async implementation of weekly digest."""
    logger.info("Sending weekly digests")
    
    TaskSession = _make_task_session_factory()
    async with TaskSession() as db:
        # Get all active users with weekly digest preference
        today = date.today()
        week_start = today - timedelta(days=7)
        week_label = f"{week_start.strftime('%b %d')} - {today.strftime('%b %d, %Y')}"
        
        # Get users with weekly digest items
        result = await db.execute(
            select(User)
            .where(User.is_active == True)
        )
        users = result.scalars().all()
        
        for user in users:
            items_result = await db.execute(
                select(WatchlistItem)
                .join(Watchlist)
                .where(
                    Watchlist.user_id == user.id,
                    WatchlistItem.notification_frequency == NotificationFrequency.WEEKLY,
                    WatchlistItem.email_enabled == True,
                )
            )
            items = items_result.scalars().all()
            
            if not items:
                continue
            
            # Gather changes for watched investors
            investor_summaries = []
            for item in items:
                changes_result = await db.execute(
                    select(HoldingsChange)
                    .join(Investor)
                    .where(
                        HoldingsChange.investor_id == item.investor_id,
                        HoldingsChange.to_date >= week_start,
                        HoldingsChange.to_date <= today,
                    )
                )
                changes = changes_result.scalars().all()
                
                investor_result = await db.execute(
                    select(Investor).where(Investor.id == item.investor_id)
                )
                investor = investor_result.scalar_one()
                
                investor_summaries.append({
                    "name": investor.name,
                    "summary": f"{len(changes)} position changes this week" if changes else "No changes this week",
                    "buys": sum(1 for c in changes if c.change_type.value in ["new", "added"]),
                    "sells": sum(1 for c in changes if c.change_type.value in ["reduced", "sold_out"]),
                })
            
            # Create report
            report = Report(
                user_id=user.id,
                report_type=ReportType.WEEKLY_DIGEST,
                report_date=today,
                title=f"Weekly Digest - {week_label}",
                summary_json={"investors": investor_summaries, "week_label": week_label},
            )
            db.add(report)
            await db.flush()
            
            # Send email
            digest_data = {
                "week_label": week_label,
                "investors": investor_summaries,
            }
            
            success = await send_weekly_digest(
                to_email=user.email,
                digest_data=digest_data,
            )
            
            if success:
                report.email_sent = True
                report.email_sent_at = datetime.utcnow()
                report.email_recipient = user.email
        
        await db.commit()
        logger.info("Weekly digests sent")
