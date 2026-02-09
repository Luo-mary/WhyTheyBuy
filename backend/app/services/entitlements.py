"""
Entitlements service for feature gating based on subscription tier.

This service is the central authority for checking what features
a user can access based on their subscription.

IMPORTANT PRINCIPLES:
- Do NOT gate features in a way that implies trading advantage
- Higher tiers provide UNDERSTANDING, not performance
- Always be clear about limitations
"""
import logging
from typing import Optional
from uuid import UUID
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models.subscription import (
    Subscription,
    SubscriptionTier,
    TierEntitlements,
    NotificationFrequency,
)
from app.models.user import User

logger = logging.getLogger(__name__)


class EntitlementError(Exception):
    """Base exception for entitlement errors."""
    pass


class FeatureNotAvailableError(EntitlementError):
    """Raised when a feature is not available for the user's tier."""
    def __init__(
        self,
        feature: str,
        current_tier: SubscriptionTier,
        required_tier: SubscriptionTier,
        message: str | None = None,
    ):
        self.feature = feature
        self.current_tier = current_tier
        self.required_tier = required_tier
        self.message = message or f"Feature '{feature}' requires {required_tier.value} tier"
        super().__init__(self.message)


class LimitExceededError(EntitlementError):
    """Raised when a usage limit is exceeded."""
    def __init__(
        self,
        limit_name: str,
        current_usage: int,
        max_allowed: int,
        message: str | None = None,
    ):
        self.limit_name = limit_name
        self.current_usage = current_usage
        self.max_allowed = max_allowed
        self.message = message or f"Limit exceeded: {limit_name} ({current_usage}/{max_allowed})"
        super().__init__(self.message)


class EntitlementsService:
    """
    Service for checking and enforcing feature entitlements.
    
    Usage:
        service = EntitlementsService(db)
        if service.check_feature(user_id, "ai_evidence_panel_enabled"):
            # Show evidence panel
        
        # Or raise exception if not allowed:
        service.require_feature(user_id, "ai_evidence_panel_enabled")
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_subscription(self, user_id: UUID) -> Subscription | None:
        """Get user's subscription, creating free tier if needed."""
        subscription = self.db.query(Subscription).filter(
            Subscription.user_id == user_id
        ).first()
        
        # Auto-create free subscription if none exists
        if not subscription:
            subscription = Subscription(
                user_id=user_id,
                tier=SubscriptionTier.FREE,
            )
            self.db.add(subscription)
            self.db.commit()
            self.db.refresh(subscription)
        
        return subscription
    
    def get_tier(self, user_id: UUID) -> SubscriptionTier:
        """Get user's current subscription tier."""
        subscription = self.get_subscription(user_id)
        return subscription.tier if subscription else SubscriptionTier.FREE
    
    def get_entitlements(self, user_id: UUID) -> dict:
        """Get all entitlements for a user."""
        tier = self.get_tier(user_id)
        return TierEntitlements.get_entitlements(tier)
    
    # ==========================================================================
    # FEATURE CHECKS
    # ==========================================================================
    
    def check_feature(self, user_id: UUID, feature: str) -> bool:
        """
        Check if a feature is enabled for the user.
        
        Returns True/False without raising exceptions.
        """
        entitlements = self.get_entitlements(user_id)
        value = entitlements.get(feature, False)
        
        if isinstance(value, bool):
            return value
        elif isinstance(value, int):
            return value > 0
        elif isinstance(value, list):
            return len(value) > 0
        
        return bool(value)
    
    def require_feature(
        self,
        user_id: UUID,
        feature: str,
        required_tier: SubscriptionTier | None = None,
    ) -> None:
        """
        Require that a feature is enabled, raising HTTPException if not.
        
        Use this in API endpoints to gate access.
        """
        if not self.check_feature(user_id, feature):
            tier = self.get_tier(user_id)
            
            # Determine which tier is required
            if required_tier is None:
                # Find the minimum tier that has this feature
                for check_tier in [SubscriptionTier.PRO, SubscriptionTier.PRO_PLUS]:
                    if TierEntitlements.check_entitlement(check_tier, feature):
                        required_tier = check_tier
                        break
                else:
                    required_tier = SubscriptionTier.PRO_PLUS
            
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail={
                    "error": "feature_not_available",
                    "feature": feature,
                    "current_tier": tier.value,
                    "required_tier": required_tier.value,
                    "message": f"This feature requires a {required_tier.value} subscription",
                    "upgrade_url": "/settings/subscription",
                },
            )
    
    def get_feature_value(self, user_id: UUID, feature: str):
        """Get the value of a feature entitlement."""
        entitlements = self.get_entitlements(user_id)
        return entitlements.get(feature)
    
    # ==========================================================================
    # LIMIT CHECKS
    # ==========================================================================
    
    def check_investor_limit(self, user_id: UUID) -> tuple[int, int, bool]:
        """
        Check investor monitoring limit.

        Returns: (current_count, max_allowed, can_add_more)
        max_allowed is -1 for unlimited.
        """
        subscription = self.get_subscription(user_id)
        max_allowed = subscription.max_monitored_investors
        current_count = subscription.monitored_investors_count

        # -1 means unlimited
        can_add = max_allowed == -1 or current_count < max_allowed
        return current_count, max_allowed, can_add
    
    def require_investor_limit(self, user_id: UUID) -> None:
        """Require that user can add another investor."""
        current, max_allowed, can_add = self.check_investor_limit(user_id)
        
        if not can_add:
            tier = self.get_tier(user_id)
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail={
                    "error": "limit_exceeded",
                    "limit_name": "monitored_investors",
                    "current_usage": current,
                    "max_allowed": max_allowed,
                    "current_tier": tier.value,
                    "message": f"You've reached your limit of {max_allowed} monitored investors",
                    "upgrade_url": "/settings/subscription",
                },
            )
    
    def increment_investor_count(self, user_id: UUID) -> None:
        """Increment the monitored investors count."""
        subscription = self.get_subscription(user_id)
        subscription.monitored_investors_count += 1
        self.db.commit()
    
    def decrement_investor_count(self, user_id: UUID) -> None:
        """Decrement the monitored investors count."""
        subscription = self.get_subscription(user_id)
        if subscription.monitored_investors_count > 0:
            subscription.monitored_investors_count -= 1
            self.db.commit()
    
    def check_history_access(self, user_id: UUID, days_back: int) -> bool:
        """Check if user can access history from N days ago."""
        history_days = self.get_feature_value(user_id, "history_days")
        
        if history_days == -1:  # Unlimited
            return True
        
        return days_back <= history_days
    
    def get_history_limit_days(self, user_id: UUID) -> int:
        """Get the number of days of history the user can access."""
        return self.get_feature_value(user_id, "history_days")
    
    # ==========================================================================
    # NOTIFICATION CHECKS
    # ==========================================================================
    
    def check_notification_allowed(
        self,
        user_id: UUID,
        frequency: NotificationFrequency,
    ) -> bool:
        """Check if a notification frequency is allowed for the user."""
        allowed = self.get_feature_value(user_id, "allowed_notifications")
        return frequency in allowed
    
    def get_allowed_notifications(self, user_id: UUID) -> list[NotificationFrequency]:
        """Get list of allowed notification frequencies."""
        return self.get_feature_value(user_id, "allowed_notifications")
    
    # ==========================================================================
    # AI FEATURE CHECKS
    # ==========================================================================
    
    def get_ai_hypotheses_count(self, user_id: UUID) -> int:
        """Get the number of AI hypotheses to generate for the user."""
        return self.get_feature_value(user_id, "ai_summary_hypotheses_count")
    
    def check_evidence_panel_enabled(self, user_id: UUID) -> bool:
        """Check if evidence panel is enabled for the user."""
        return self.check_feature(user_id, "ai_evidence_panel_enabled")
    
    def check_evidence_panel_auto_expand(self, user_id: UUID) -> bool:
        """Check if evidence panel should auto-expand."""
        return self.get_feature_value(user_id, "evidence_panel_auto_expand")
    
    def check_company_rationale_enabled(self, user_id: UUID) -> bool:
        """Check if company-level AI rationale is enabled."""
        return self.check_feature(user_id, "ai_company_rationale_enabled")
    
    def check_cross_investor_insights(self, user_id: UUID) -> bool:
        """Check if cross-investor insights are enabled."""
        return self.check_feature(user_id, "ai_cross_investor_insights")

    def get_ai_reasoning_limit(self, user_id: UUID) -> int:
        """
        Get AI reasoning limit for a user.

        Returns -1 for unlimited, or the max rank that can access AI reasoning.
        """
        return self.get_feature_value(user_id, "ai_reasoning_top_n_limit")

    def check_ai_reasoning_access(
        self,
        user_id: UUID,
        transaction_rank: int,
    ) -> tuple[bool, str | None]:
        """
        Check if user can access AI reasoning for a transaction at given rank.

        Args:
            user_id: The user ID
            transaction_rank: 1-indexed position in sorted list (e.g., 1 = top buy/sell)

        Returns:
            Tuple of (can_access, upgrade_reason).
            upgrade_reason is None if can access, or a reason string if not.
        """
        limit = self.get_ai_reasoning_limit(user_id)

        # -1 means unlimited
        if limit == -1:
            return (True, None)

        # Check if rank is within limit
        if transaction_rank <= limit:
            return (True, None)

        return (False, "exceeds_ai_reasoning_limit")

    # ==========================================================================
    # TRANSPARENCY FEATURE CHECKS
    # ==========================================================================
    
    def get_transparency_features(self, user_id: UUID) -> dict:
        """
        Get transparency feature flags for the user.
        
        Returns a dict controlling what transparency info to show.
        """
        entitlements = self.get_entitlements(user_id)
        
        return {
            "label_only": entitlements.get("transparency_label_only", True),
            "score_visible": entitlements.get("transparency_score_visible", False),
            "explanation_visible": entitlements.get("transparency_explanation_visible", False),
            "dimensions_visible": entitlements.get("transparency_dimensions_visible", False),
        }
    
    # ==========================================================================
    # TIER COMPARISON
    # ==========================================================================
    
    def get_upgrade_benefits(
        self,
        user_id: UUID,
        target_tier: SubscriptionTier,
    ) -> list[str]:
        """
        Get list of new features user would get by upgrading.
        
        IMPORTANT: Frame benefits as understanding, not performance.
        """
        current_tier = self.get_tier(user_id)
        current_entitlements = TierEntitlements.get_entitlements(current_tier)
        target_entitlements = TierEntitlements.get_entitlements(target_tier)
        
        benefits = []

        # Investor limit (handle -1 as unlimited)
        target_investors = target_entitlements["max_monitored_investors"]
        current_investors = current_entitlements["max_monitored_investors"]
        if target_investors == -1 and current_investors != -1:
            benefits.append("Monitor unlimited investors")
        elif target_investors != -1 and current_investors != -1 and target_investors > current_investors:
            benefits.append(f"Monitor up to {target_investors} investors")
        
        # Evidence panel
        if target_entitlements["ai_evidence_panel_enabled"] and not current_entitlements["ai_evidence_panel_enabled"]:
            benefits.append("See exactly what evidence AI uses (Evidence Panel)")
        
        # Transparency
        if target_entitlements["transparency_score_visible"] and not current_entitlements["transparency_score_visible"]:
            benefits.append("Full transparency scores with explanations")
        
        if target_entitlements["transparency_dimensions_visible"] and not current_entitlements["transparency_dimensions_visible"]:
            benefits.append("Complete transparency dimension breakdown")
        
        # AI features
        if target_entitlements["ai_summary_hypotheses_count"] > current_entitlements["ai_summary_hypotheses_count"]:
            benefits.append(
                f"Up to {target_entitlements['ai_summary_hypotheses_count']} AI hypotheses (deeper analysis)"
            )
        
        if target_entitlements["ai_company_rationale_enabled"] and not current_entitlements["ai_company_rationale_enabled"]:
            benefits.append("Company-level AI analysis")
        
        if target_entitlements["ai_cross_investor_insights"] and not current_entitlements["ai_cross_investor_insights"]:
            benefits.append("Cross-investor insights (see who else holds the same stocks)")
        
        # Notifications
        if target_entitlements["can_instant_alerts"] and not current_entitlements["can_instant_alerts"]:
            benefits.append("Real-time alerts for daily disclosure investors")
        
        if target_entitlements["can_daily_digest"] and not current_entitlements["can_daily_digest"]:
            benefits.append("Daily digest emails")
        
        # History & Export
        target_history = target_entitlements["history_days"]
        current_history = current_entitlements["history_days"]
        if target_history == -1 and current_history != -1:
            benefits.append("Unlimited historical data access")
        elif target_history > current_history:
            benefits.append(f"{target_history} days of historical data")
        
        if target_entitlements["export_enabled"] and not current_entitlements["export_enabled"]:
            benefits.append("Export data for your own analysis")
        
        return benefits


# =============================================================================
# DEPENDENCY INJECTION
# =============================================================================

def get_entitlements_service(db: Session) -> EntitlementsService:
    """Factory function for dependency injection."""
    return EntitlementsService(db)
