"""
Subscription schemas for the three-tier membership system.

TIERS: FREE, PRO, PRO+ (Research)

IMPORTANT PRINCIPLES:
- Do NOT sell performance or outcomes
- Do NOT promise better returns
- Sell depth of understanding and risk awareness
"""
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field

from app.models.subscription import (
    SubscriptionTier,
    SubscriptionStatus,
    BillingCycle,
    NotificationFrequency,
    TierEntitlements,
    TierPricing,
    DEFAULT_FREE_INVESTOR_SLUG,
)


# =============================================================================
# ENTITLEMENT SCHEMAS
# =============================================================================

class EntitlementsResponse(BaseModel):
    """
    User's current entitlements based on subscription tier.
    
    These control what features are accessible.
    """
    # Monitoring limits
    max_monitored_investors: int = Field(description="Maximum investors in watchlist")
    max_email_recipients: int = Field(description="Maximum email recipients")
    
    # Notification options
    allowed_notifications: list[str] = Field(description="Allowed notification frequencies")
    can_instant_alerts: bool = Field(description="Can receive real-time alerts")
    can_daily_digest: bool = Field(description="Can receive daily digest")
    
    # Transparency features (about UNDERSTANDING, not performance)
    transparency_label_only: bool = Field(
        description="Only show High/Medium/Low labels (no numeric score)"
    )
    transparency_score_visible: bool = Field(
        description="Show full 0-100 transparency score"
    )
    transparency_explanation_visible: bool = Field(
        description="Show transparency score explanation"
    )
    transparency_dimensions_visible: bool = Field(
        description="Show breakdown by transparency dimension"
    )
    
    # AI features
    ai_summary_enabled: bool
    ai_summary_hypotheses_count: int = Field(
        description="Number of AI hypotheses to generate"
    )
    ai_evidence_panel_enabled: bool = Field(
        description="Show evidence panel with AI analysis"
    )
    ai_company_rationale_enabled: bool = Field(
        description="Access to company-level AI rationale"
    )
    ai_cross_investor_insights: bool = Field(
        description="Cross-investor analysis for companies"
    )
    ai_reasoning_top_n_limit: int = Field(
        description="AI reasoning limit for transactions (-1 = unlimited)"
    )

    # History & Export
    history_days: int = Field(description="Days of history accessible (-1 = unlimited)")
    export_enabled: bool = Field(description="Can export data")
    
    # UI features
    evidence_panel_visible: bool
    evidence_panel_auto_expand: bool


# =============================================================================
# SUBSCRIPTION RESPONSE SCHEMAS
# =============================================================================

class SubscriptionResponse(BaseModel):
    """Subscription response schema."""
    id: UUID
    user_id: UUID
    tier: SubscriptionTier
    billing_cycle: BillingCycle | None
    status: SubscriptionStatus
    
    # Computed properties
    is_active: bool
    is_paid: bool
    is_pro: bool
    is_pro_plus: bool
    
    # Key entitlements (summary)
    max_monitored_investors: int
    monitored_investors_count: int
    can_add_investor: bool
    can_instant_alerts: bool
    can_daily_digest: bool
    evidence_panel_enabled: bool
    transparency_score_visible: bool
    history_days: int
    export_enabled: bool
    ai_reasoning_limit: int = Field(
        description="AI reasoning limit (-1 for unlimited, or max rank for free tier)"
    )
    default_investor_slug: str = Field(
        default=DEFAULT_FREE_INVESTOR_SLUG,
        description="Default investor that is always free for all users"
    )

    # Billing info
    current_period_start: datetime | None
    current_period_end: datetime | None
    cancel_at_period_end: bool
    trial_start: datetime | None
    trial_end: datetime | None
    
    class Config:
        from_attributes = True


class SubscriptionDetailResponse(SubscriptionResponse):
    """Detailed subscription response with full entitlements."""
    entitlements: EntitlementsResponse


# =============================================================================
# PRICING SCHEMAS
# =============================================================================

class TierFeature(BaseModel):
    """A feature included in a tier."""
    name: str
    description: str
    included: bool
    highlight: bool = False  # Whether to highlight this feature


class TierInfo(BaseModel):
    """
    Complete information about a subscription tier.
    
    IMPORTANT: Features emphasize understanding and risk awareness,
    NOT trading advantage or performance claims.
    """
    tier: SubscriptionTier
    name: str = Field(description="Display name")
    tagline: str = Field(description="Short description")
    description: str = Field(description="Full description")
    
    # Pricing
    price_monthly: float
    price_yearly: float
    price_display: str = Field(description="Formatted price for display")
    savings_yearly: str | None = Field(description="Savings message for yearly")
    
    # Stripe integration
    stripe_price_id_monthly: str | None
    stripe_price_id_yearly: str | None
    
    # Features
    features: list[TierFeature]
    
    # Limits (summary)
    max_investors: int
    max_hypotheses: int
    history_days: int
    
    # Flags
    is_popular: bool = False
    is_best_value: bool = False


class PricingResponse(BaseModel):
    """Complete pricing information for all tiers."""
    tiers: list[TierInfo]
    currency: str = "USD"
    
    # Messaging
    value_proposition: str = Field(
        default="Understand investor disclosures with depth and clarity"
    )
    disclaimer: str = Field(
        default="WhyTheyBuy helps you understand public disclosures. "
        "It does not provide investment advice or predict performance."
    )


# =============================================================================
# CHECKOUT SCHEMAS
# =============================================================================

class CheckoutRequest(BaseModel):
    """Request to create a checkout session."""
    tier: SubscriptionTier
    billing_cycle: BillingCycle
    success_url: str
    cancel_url: str


class CheckoutSessionResponse(BaseModel):
    """Stripe checkout session response."""
    checkout_url: str
    session_id: str


class BillingPortalResponse(BaseModel):
    """Stripe billing portal response."""
    portal_url: str


class UpgradePreviewResponse(BaseModel):
    """Preview of what upgrading will provide."""
    current_tier: SubscriptionTier
    target_tier: SubscriptionTier
    new_features: list[str]
    price_difference: float
    proration_amount: float | None


# =============================================================================
# TIER INFO BUILDER
# =============================================================================

def build_tier_info(tier: SubscriptionTier) -> TierInfo:
    """
    Build complete tier information.
    
    IMPORTANT: Language emphasizes understanding and risk awareness,
    NOT trading advantage or performance promises.
    """
    entitlements = TierEntitlements.get_entitlements(tier)
    pricing = TierPricing.get_pricing(tier)
    
    if tier == SubscriptionTier.FREE:
        return TierInfo(
            tier=tier,
            name="Free",
            tagline="Get started with disclosure monitoring",
            description=(
                "Track one investor's public disclosures. "
                "Receive weekly summaries of holdings changes."
            ),
            price_monthly=0,
            price_yearly=0,
            price_display="Free",
            savings_yearly=None,
            stripe_price_id_monthly=None,
            stripe_price_id_yearly=None,
            features=[
                TierFeature(
                    name="Monitor 1 Investor",
                    description="Track holdings changes for one investor",
                    included=True,
                ),
                TierFeature(
                    name="Weekly Digest",
                    description="Receive a weekly summary of changes",
                    included=True,
                ),
                TierFeature(
                    name="Basic Holdings View",
                    description="See what changed in holdings",
                    included=True,
                ),
                TierFeature(
                    name="Transparency Labels",
                    description="High/Medium/Low disclosure transparency",
                    included=True,
                ),
                TierFeature(
                    name="AI Summary",
                    description="Single high-level AI-generated summary",
                    included=True,
                ),
                TierFeature(
                    name="Evidence Panel",
                    description="See what evidence AI used",
                    included=False,
                ),
                TierFeature(
                    name="Company Analysis",
                    description="AI rationale for specific companies",
                    included=False,
                ),
            ],
            max_investors=1,
            max_hypotheses=1,
            history_days=7,
            is_popular=False,
            is_best_value=False,
        )
    
    elif tier == SubscriptionTier.PRO:
        monthly = pricing["monthly_price"]
        yearly = pricing["yearly_price"]
        monthly_if_yearly = yearly / 12
        savings = ((monthly * 12) - yearly) / (monthly * 12) * 100
        
        return TierInfo(
            tier=tier,
            name="Pro",
            tagline="Deeper understanding of investor activity",
            description=(
                "Track multiple investors with detailed transparency insights. "
                "Understand the limitations and confidence levels of each analysis."
            ),
            price_monthly=monthly,
            price_yearly=yearly,
            price_display=f"${monthly:.2f}/mo",
            savings_yearly=f"Save {savings:.0f}% with yearly",
            stripe_price_id_monthly=pricing["stripe_price_id_monthly"],
            stripe_price_id_yearly=pricing["stripe_price_id_yearly"],
            features=[
                TierFeature(
                    name="Monitor 10 Investors",
                    description="Track holdings changes for up to 10 investors",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Daily Digest + Alerts",
                    description="Daily summaries plus important change notifications",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Full Transparency Score",
                    description="See the complete 0-100 transparency score with explanation",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Evidence Panel",
                    description="See exactly what evidence AI used and what's unknown",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Multiple AI Hypotheses",
                    description="Get 3 possible interpretations with confidence levels",
                    included=True,
                ),
                TierFeature(
                    name="Company-Level Analysis",
                    description="AI rationale for specific company positions",
                    included=True,
                ),
                TierFeature(
                    name="90-Day History",
                    description="Access 90 days of historical changes",
                    included=True,
                ),
                TierFeature(
                    name="Cross-Investor Insights",
                    description="See which investors hold the same companies",
                    included=False,
                ),
                TierFeature(
                    name="Data Export",
                    description="Export data for your own analysis",
                    included=False,
                ),
            ],
            max_investors=10,
            max_hypotheses=3,
            history_days=90,
            is_popular=True,
            is_best_value=False,
        )
    
    else:  # PRO_PLUS
        monthly = pricing["monthly_price"]
        yearly = pricing["yearly_price"]
        savings = ((monthly * 12) - yearly) / (monthly * 12) * 100
        
        return TierInfo(
            tier=tier,
            name="Pro+ Research",
            tagline="Institutional-grade disclosure analysis",
            description=(
                "Full access to all features including cross-investor analysis, "
                "complete transparency breakdowns, and data exports. "
                "Designed for those who need to understand every limitation."
            ),
            price_monthly=monthly,
            price_yearly=yearly,
            price_display=f"${monthly:.2f}/mo",
            savings_yearly=f"Save {savings:.0f}% with yearly",
            stripe_price_id_monthly=pricing["stripe_price_id_monthly"],
            stripe_price_id_yearly=pricing["stripe_price_id_yearly"],
            features=[
                TierFeature(
                    name="Unlimited Investors",
                    description="Track holdings changes for unlimited investors",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Real-Time Alerts",
                    description="Instant notifications for daily disclosure investors",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Full Transparency Breakdown",
                    description="See all 4 transparency dimensions with full explanation",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Evidence Panel (Auto-Expanded)",
                    description="Evidence panel expanded by default - see all signals",
                    included=True,
                ),
                TierFeature(
                    name="Maximum AI Hypotheses",
                    description="Get up to 5 possible interpretations",
                    included=True,
                ),
                TierFeature(
                    name="Cross-Investor Insights",
                    description="See which investors hold the same companies and their actions",
                    included=True,
                    highlight=True,
                ),
                TierFeature(
                    name="Unlimited History",
                    description="Access complete historical data",
                    included=True,
                ),
                TierFeature(
                    name="Data Export",
                    description="Export holdings changes and AI analyses",
                    included=True,
                    highlight=True,
                ),
            ],
            max_investors=-1,  # Unlimited
            max_hypotheses=5,
            history_days=-1,
            is_popular=False,
            is_best_value=True,
        )


def get_all_pricing() -> PricingResponse:
    """Get complete pricing information for all tiers."""
    return PricingResponse(
        tiers=[
            build_tier_info(SubscriptionTier.FREE),
            build_tier_info(SubscriptionTier.PRO),
            build_tier_info(SubscriptionTier.PRO_PLUS),
        ],
        currency="USD",
        value_proposition=(
            "Understand investor disclosures with depth and clarity. "
            "Know exactly what's disclosed, what's unknown, and what limitations exist."
        ),
        disclaimer=(
            "WhyTheyBuy helps you understand public disclosures. "
            "It does not provide investment advice, predict performance, "
            "or promise better trading outcomes. "
            "Higher tiers provide deeper analysis of limitations, not trading advantages."
        ),
    )
