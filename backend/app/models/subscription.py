"""
Subscription and billing models with three-tier membership system.

TIERS:
- FREE: Basic access, 1 investor, weekly digest
- PRO: Enhanced access, 10 investors, daily digest + alerts
- PRO_PLUS (Research): Full access, 20+ investors, real-time alerts

IMPORTANT PRINCIPLES:
- Do NOT sell performance or outcomes
- Do NOT promise better returns
- Sell depth of understanding and risk awareness
"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Enum as SQLEnum, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from app.database import Base


class SubscriptionTier(str, enum.Enum):
    """
    Subscription tier types.
    
    Each tier gates access to features, NOT performance claims.
    """
    FREE = "free"
    PRO = "pro"
    PRO_PLUS = "pro_plus"  # Research tier


class BillingCycle(str, enum.Enum):
    """Billing cycle options."""
    MONTHLY = "monthly"
    YEARLY = "yearly"


class SubscriptionStatus(str, enum.Enum):
    """Subscription status."""
    ACTIVE = "active"
    CANCELED = "canceled"
    PAST_DUE = "past_due"
    TRIALING = "trialing"
    INCOMPLETE = "incomplete"
    PAUSED = "paused"


class NotificationFrequency(str, enum.Enum):
    """Notification frequency options."""
    WEEKLY_DIGEST = "weekly_digest"
    DAILY_DIGEST = "daily_digest"
    IMPORTANT_ALERTS = "important_alerts"  # Significant changes only
    REAL_TIME = "real_time"  # Where applicable (daily disclosures)


# =============================================================================
# DEFAULT INVESTOR CONFIGURATION
# =============================================================================

# Default investor slug - always free for all users (Berkshire Hathaway)
DEFAULT_FREE_INVESTOR_SLUG = "berkshire-hathaway"


# =============================================================================
# TIER ENTITLEMENTS CONFIGURATION
# =============================================================================

class TierEntitlements:
    """
    Feature entitlements by tier.
    
    This is the source of truth for what each tier can access.
    Features are about UNDERSTANDING, not trading advantage.
    """
    
    ENTITLEMENTS = {
        SubscriptionTier.FREE: {
            # Monitoring limits
            "max_monitored_investors": 2,  # Berkshire (default) + 1 user-selected
            "max_email_recipients": 1,

            # Notification options
            "allowed_notifications": [NotificationFrequency.WEEKLY_DIGEST],
            "can_instant_alerts": False,
            "can_daily_digest": False,

            # Transparency features (UNDERSTANDING, not performance)
            "transparency_label_only": True,  # Only High/Medium/Low
            "transparency_score_visible": False,  # No numeric score
            "transparency_explanation_visible": False,
            "transparency_dimensions_visible": False,

            # AI features
            "ai_summary_enabled": True,
            "ai_summary_hypotheses_count": 1,  # Single high-level summary
            "ai_evidence_panel_enabled": False,  # No evidence panel
            "ai_company_rationale_enabled": False,
            "ai_cross_investor_insights": False,
            "ai_reasoning_top_n_limit": 5,  # Top 5 buys + Top 5 sells only

            # History & Export
            "history_days": 7,  # Last 7 days only
            "export_enabled": False,

            # UI features
            "evidence_panel_visible": False,
            "evidence_panel_auto_expand": False,
        },
        
        SubscriptionTier.PRO: {
            # Monitoring limits
            "max_monitored_investors": 10,
            "max_email_recipients": 3,
            
            # Notification options
            "allowed_notifications": [
                NotificationFrequency.WEEKLY_DIGEST,
                NotificationFrequency.DAILY_DIGEST,
                NotificationFrequency.IMPORTANT_ALERTS,
            ],
            "can_instant_alerts": False,  # Not real-time, but important changes
            "can_daily_digest": True,
            
            # Transparency features
            "transparency_label_only": False,
            "transparency_score_visible": True,  # Full 0-100 score
            "transparency_explanation_visible": True,
            "transparency_dimensions_visible": False,  # No dimension breakdown
            
            # AI features
            "ai_summary_enabled": True,
            "ai_summary_hypotheses_count": 3,  # Multiple hypotheses
            "ai_evidence_panel_enabled": True,  # Evidence panel visible
            "ai_company_rationale_enabled": True,  # Company-level AI
            "ai_cross_investor_insights": False,
            "ai_reasoning_top_n_limit": -1,  # Unlimited AI reasoning

            # History & Export
            "history_days": 90,  # Last 90 days
            "export_enabled": False,
            
            # UI features
            "evidence_panel_visible": True,
            "evidence_panel_auto_expand": False,  # Collapsed by default
        },
        
        SubscriptionTier.PRO_PLUS: {
            # Monitoring limits
            "max_monitored_investors": -1,  # Unlimited
            "max_email_recipients": 10,
            
            # Notification options
            "allowed_notifications": [
                NotificationFrequency.WEEKLY_DIGEST,
                NotificationFrequency.DAILY_DIGEST,
                NotificationFrequency.IMPORTANT_ALERTS,
                NotificationFrequency.REAL_TIME,
            ],
            "can_instant_alerts": True,  # Real-time where applicable
            "can_daily_digest": True,
            
            # Transparency features (FULL ACCESS)
            "transparency_label_only": False,
            "transparency_score_visible": True,
            "transparency_explanation_visible": True,
            "transparency_dimensions_visible": True,  # Full breakdown
            
            # AI features (FULL ACCESS)
            "ai_summary_enabled": True,
            "ai_summary_hypotheses_count": 5,  # Maximum hypotheses
            "ai_evidence_panel_enabled": True,
            "ai_company_rationale_enabled": True,
            "ai_cross_investor_insights": True,  # Cross-investor analysis
            "ai_reasoning_top_n_limit": -1,  # Unlimited AI reasoning

            # History & Export (FULL ACCESS)
            "history_days": -1,  # Unlimited
            "export_enabled": True,
            
            # UI features
            "evidence_panel_visible": True,
            "evidence_panel_auto_expand": True,  # Expanded by default
        },
    }
    
    @classmethod
    def get_entitlements(cls, tier: SubscriptionTier) -> dict:
        """Get entitlements for a tier."""
        return cls.ENTITLEMENTS.get(tier, cls.ENTITLEMENTS[SubscriptionTier.FREE])
    
    @classmethod
    def check_entitlement(cls, tier: SubscriptionTier, entitlement: str) -> bool | int | list:
        """Check a specific entitlement for a tier."""
        entitlements = cls.get_entitlements(tier)
        return entitlements.get(entitlement)


# =============================================================================
# PRICING CONFIGURATION
# =============================================================================

class TierPricing:
    """
    Pricing configuration for subscription tiers.
    
    NOTE: These are display prices. Actual prices are managed in Stripe.
    """
    
    PRICING = {
        SubscriptionTier.FREE: {
            "monthly_price": 0,
            "yearly_price": 0,
            "stripe_price_id_monthly": None,
            "stripe_price_id_yearly": None,
        },
        SubscriptionTier.PRO: {
            "monthly_price": 19.99,
            "yearly_price": 179.88,  # ~$14.99/month
            "stripe_price_id_monthly": "price_pro_monthly",  # Replace with actual Stripe ID
            "stripe_price_id_yearly": "price_pro_yearly",
        },
        SubscriptionTier.PRO_PLUS: {
            "monthly_price": 49.99,
            "yearly_price": 449.88,  # ~$37.49/month
            "stripe_price_id_monthly": "price_pro_plus_monthly",
            "stripe_price_id_yearly": "price_pro_plus_yearly",
        },
    }
    
    @classmethod
    def get_pricing(cls, tier: SubscriptionTier) -> dict:
        """Get pricing for a tier."""
        return cls.PRICING.get(tier, cls.PRICING[SubscriptionTier.FREE])


# =============================================================================
# SUBSCRIPTION MODEL
# =============================================================================

class Subscription(Base):
    """
    User subscription model.
    
    Manages subscription state and links to Stripe for billing.
    """
    __tablename__ = "subscriptions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    
    # Subscription details
    tier = Column(SQLEnum(SubscriptionTier), default=SubscriptionTier.FREE)
    billing_cycle = Column(SQLEnum(BillingCycle), nullable=True)  # None for free tier
    status = Column(SQLEnum(SubscriptionStatus), default=SubscriptionStatus.ACTIVE)
    
    # Stripe integration
    stripe_customer_id = Column(String(255), nullable=True, unique=True)
    stripe_subscription_id = Column(String(255), nullable=True, unique=True)
    stripe_price_id = Column(String(255), nullable=True)
    
    # Billing period
    current_period_start = Column(DateTime, nullable=True)
    current_period_end = Column(DateTime, nullable=True)
    cancel_at_period_end = Column(Boolean, default=False)
    
    # Trial
    trial_start = Column(DateTime, nullable=True)
    trial_end = Column(DateTime, nullable=True)
    
    # Usage tracking
    monitored_investors_count = Column(Integer, default=0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="subscription")
    
    # ==========================================================================
    # TIER PROPERTIES
    # ==========================================================================
    
    @property
    def is_active(self) -> bool:
        """Check if subscription is active."""
        return self.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]
    
    @property
    def is_paid(self) -> bool:
        """Check if this is a paid tier."""
        return self.tier in [SubscriptionTier.PRO, SubscriptionTier.PRO_PLUS]
    
    @property
    def is_pro(self) -> bool:
        """Check if user has Pro or higher."""
        return (
            self.tier in [SubscriptionTier.PRO, SubscriptionTier.PRO_PLUS]
            and self.is_active
        )
    
    @property
    def is_pro_plus(self) -> bool:
        """Check if user has Pro+ tier."""
        return self.tier == SubscriptionTier.PRO_PLUS and self.is_active
    
    @property
    def entitlements(self) -> dict:
        """Get all entitlements for current tier."""
        return TierEntitlements.get_entitlements(self.tier)
    
    # ==========================================================================
    # ENTITLEMENT HELPERS
    # ==========================================================================
    
    @property
    def max_monitored_investors(self) -> int:
        """Maximum number of monitored investors."""
        return TierEntitlements.check_entitlement(self.tier, "max_monitored_investors")
    
    @property
    def can_add_investor(self) -> bool:
        """Check if user can add another investor to watchlist."""
        if self.max_monitored_investors == -1:
            return True  # Unlimited
        return self.monitored_investors_count < self.max_monitored_investors
    
    @property
    def can_instant_alerts(self) -> bool:
        """Check if user can receive instant/real-time alerts."""
        return TierEntitlements.check_entitlement(self.tier, "can_instant_alerts")
    
    @property
    def can_daily_digest(self) -> bool:
        """Check if user can receive daily digest."""
        return TierEntitlements.check_entitlement(self.tier, "can_daily_digest")
    
    @property
    def evidence_panel_enabled(self) -> bool:
        """Check if evidence panel is enabled."""
        return TierEntitlements.check_entitlement(self.tier, "ai_evidence_panel_enabled")
    
    @property
    def ai_hypotheses_count(self) -> int:
        """Number of AI hypotheses to generate."""
        return TierEntitlements.check_entitlement(self.tier, "ai_summary_hypotheses_count")
    
    @property
    def transparency_score_visible(self) -> bool:
        """Check if full transparency score is visible."""
        return TierEntitlements.check_entitlement(self.tier, "transparency_score_visible")
    
    @property
    def history_days(self) -> int:
        """Number of days of history accessible (-1 for unlimited)."""
        return TierEntitlements.check_entitlement(self.tier, "history_days")
    
    @property
    def export_enabled(self) -> bool:
        """Check if export is enabled."""
        return TierEntitlements.check_entitlement(self.tier, "export_enabled")

    @property
    def ai_reasoning_limit(self) -> int:
        """AI reasoning limit (-1 for unlimited)."""
        return TierEntitlements.check_entitlement(self.tier, "ai_reasoning_top_n_limit")

    def can_access_ai_reasoning(self, rank: int) -> bool:
        """Check if user can access AI reasoning for a transaction at given rank."""
        limit = self.ai_reasoning_limit
        if limit == -1:
            return True
        return rank <= limit

    def get_entitlement(self, key: str):
        """Get a specific entitlement value."""
        return TierEntitlements.check_entitlement(self.tier, key)
    
    def check_notification_allowed(self, frequency: NotificationFrequency) -> bool:
        """Check if a notification frequency is allowed."""
        allowed = TierEntitlements.check_entitlement(self.tier, "allowed_notifications")
        return frequency in allowed


# =============================================================================
# LEGACY COMPATIBILITY
# =============================================================================

# Keep old enum for migration compatibility
class SubscriptionPlan(str, enum.Enum):
    """Legacy subscription plan types - use SubscriptionTier instead."""
    FREE = "free"
    PRO_MONTHLY = "pro_monthly"
    PRO_YEARLY = "pro_yearly"
