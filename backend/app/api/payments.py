"""
Payments API routes for three-tier subscription system.

TIERS: FREE, PRO, PRO+ (Research)

IMPORTANT PRINCIPLES:
- Do NOT sell performance or outcomes
- Do NOT promise better returns
- Sell depth of understanding and risk awareness
"""
from datetime import datetime
from fastapi import APIRouter, HTTPException, status, Request, Header
from sqlalchemy import select, func
import stripe

from app.api.deps import DB, CurrentUser, UserSubscription
from app.models.watchlist import Watchlist, WatchlistItem
from app.config import settings
from app.models.user import User
from app.models.subscription import (
    Subscription,
    SubscriptionTier,
    SubscriptionStatus,
    BillingCycle,
    TierPricing,
    TierEntitlements,
    DEFAULT_FREE_INVESTOR_SLUG,
)
from app.schemas.subscription import (
    SubscriptionResponse,
    SubscriptionDetailResponse,
    EntitlementsResponse,
    CheckoutRequest,
    CheckoutSessionResponse,
    BillingPortalResponse,
    PricingResponse,
    UpgradePreviewResponse,
    get_all_pricing,
)
from app.services.entitlements import EntitlementsService

router = APIRouter()

# Initialize Stripe
if settings.stripe_secret_key:
    stripe.api_key = settings.stripe_secret_key


# =============================================================================
# SUBSCRIPTION ENDPOINTS
# =============================================================================

@router.get("/subscription", response_model=SubscriptionDetailResponse)
async def get_subscription(subscription: UserSubscription, user: CurrentUser, db: DB):
    """Get current user's subscription with full entitlements."""
    entitlements = TierEntitlements.get_entitlements(subscription.tier)

    # Calculate actual monitored investors count from watchlist
    watchlist_result = await db.execute(
        select(Watchlist).where(
            Watchlist.user_id == user.id,
            Watchlist.is_default == True
        )
    )
    watchlist = watchlist_result.scalar_one_or_none()

    monitored_count = 0
    if watchlist:
        count_result = await db.scalar(
            select(func.count())
            .select_from(WatchlistItem)
            .where(WatchlistItem.watchlist_id == watchlist.id)
        )
        monitored_count = count_result or 0

    # Determine if user can add more investors
    max_allowed = subscription.max_monitored_investors
    can_add = max_allowed == -1 or monitored_count < max_allowed
    
    return SubscriptionDetailResponse(
        id=subscription.id,
        user_id=subscription.user_id,
        tier=subscription.tier,
        billing_cycle=subscription.billing_cycle,
        status=subscription.status,
        # Computed properties
        is_active=subscription.is_active,
        is_paid=subscription.is_paid,
        is_pro=subscription.is_pro,
        is_pro_plus=subscription.is_pro_plus,
        # Key entitlements summary
        max_monitored_investors=subscription.max_monitored_investors,
        monitored_investors_count=monitored_count,
        can_add_investor=can_add,
        can_instant_alerts=subscription.can_instant_alerts,
        can_daily_digest=subscription.can_daily_digest,
        evidence_panel_enabled=subscription.evidence_panel_enabled,
        transparency_score_visible=subscription.transparency_score_visible,
        history_days=subscription.history_days,
        export_enabled=subscription.export_enabled,
        ai_reasoning_limit=subscription.ai_reasoning_limit,
        default_investor_slug=DEFAULT_FREE_INVESTOR_SLUG,
        # Billing info
        current_period_start=subscription.current_period_start,
        current_period_end=subscription.current_period_end,
        cancel_at_period_end=subscription.cancel_at_period_end,
        trial_start=subscription.trial_start,
        trial_end=subscription.trial_end,
        # Full entitlements
        entitlements=EntitlementsResponse(
            max_monitored_investors=entitlements["max_monitored_investors"],
            max_email_recipients=entitlements["max_email_recipients"],
            allowed_notifications=[n.value for n in entitlements["allowed_notifications"]],
            can_instant_alerts=entitlements["can_instant_alerts"],
            can_daily_digest=entitlements["can_daily_digest"],
            transparency_label_only=entitlements["transparency_label_only"],
            transparency_score_visible=entitlements["transparency_score_visible"],
            transparency_explanation_visible=entitlements["transparency_explanation_visible"],
            transparency_dimensions_visible=entitlements["transparency_dimensions_visible"],
            ai_summary_enabled=entitlements["ai_summary_enabled"],
            ai_summary_hypotheses_count=entitlements["ai_summary_hypotheses_count"],
            ai_evidence_panel_enabled=entitlements["ai_evidence_panel_enabled"],
            ai_company_rationale_enabled=entitlements["ai_company_rationale_enabled"],
            ai_cross_investor_insights=entitlements["ai_cross_investor_insights"],
            ai_reasoning_top_n_limit=entitlements["ai_reasoning_top_n_limit"],
            history_days=entitlements["history_days"],
            export_enabled=entitlements["export_enabled"],
            evidence_panel_visible=entitlements["evidence_panel_visible"],
            evidence_panel_auto_expand=entitlements["evidence_panel_auto_expand"],
        ),
    )


@router.get("/entitlements", response_model=EntitlementsResponse)
async def get_entitlements(subscription: UserSubscription):
    """Get current user's feature entitlements."""
    entitlements = TierEntitlements.get_entitlements(subscription.tier)
    
    return EntitlementsResponse(
        max_monitored_investors=entitlements["max_monitored_investors"],
        max_email_recipients=entitlements["max_email_recipients"],
        allowed_notifications=[n.value for n in entitlements["allowed_notifications"]],
        can_instant_alerts=entitlements["can_instant_alerts"],
        can_daily_digest=entitlements["can_daily_digest"],
        transparency_label_only=entitlements["transparency_label_only"],
        transparency_score_visible=entitlements["transparency_score_visible"],
        transparency_explanation_visible=entitlements["transparency_explanation_visible"],
        transparency_dimensions_visible=entitlements["transparency_dimensions_visible"],
        ai_summary_enabled=entitlements["ai_summary_enabled"],
        ai_summary_hypotheses_count=entitlements["ai_summary_hypotheses_count"],
        ai_evidence_panel_enabled=entitlements["ai_evidence_panel_enabled"],
        ai_company_rationale_enabled=entitlements["ai_company_rationale_enabled"],
        ai_cross_investor_insights=entitlements["ai_cross_investor_insights"],
        ai_reasoning_top_n_limit=entitlements["ai_reasoning_top_n_limit"],
        history_days=entitlements["history_days"],
        export_enabled=entitlements["export_enabled"],
        evidence_panel_visible=entitlements["evidence_panel_visible"],
        evidence_panel_auto_expand=entitlements["evidence_panel_auto_expand"],
    )


# =============================================================================
# PRICING ENDPOINTS
# =============================================================================

@router.get("/pricing", response_model=PricingResponse)
async def get_pricing():
    """
    Get pricing information for all tiers.
    
    IMPORTANT: Language emphasizes understanding, NOT trading advantage.
    """
    return get_all_pricing()


@router.get("/upgrade-preview/{target_tier}", response_model=UpgradePreviewResponse)
async def preview_upgrade(
    target_tier: SubscriptionTier,
    user: CurrentUser,
    subscription: UserSubscription,
    db: DB,
):
    """
    Preview what upgrading to a tier would provide.
    
    Shows new features (understanding, not performance).
    """
    if target_tier == SubscriptionTier.FREE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot upgrade to Free tier",
        )
    
    if subscription.tier == target_tier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already on this tier",
        )
    
    service = EntitlementsService(db)
    new_features = service.get_upgrade_benefits(user.id, target_tier)
    
    # Calculate price difference
    current_pricing = TierPricing.get_pricing(subscription.tier)
    target_pricing = TierPricing.get_pricing(target_tier)
    
    price_diff = target_pricing["monthly_price"] - current_pricing["monthly_price"]
    
    return UpgradePreviewResponse(
        current_tier=subscription.tier,
        target_tier=target_tier,
        new_features=new_features,
        price_difference=price_diff,
        proration_amount=None,  # Would be calculated from Stripe
    )


# =============================================================================
# CHECKOUT ENDPOINTS
# =============================================================================

@router.post("/checkout", response_model=CheckoutSessionResponse)
async def create_checkout_session(
    request: CheckoutRequest,
    user: CurrentUser,
    subscription: UserSubscription,
    db: DB,
):
    """Create Stripe checkout session for subscription."""
    if not settings.stripe_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments are not configured",
        )
    
    # Validate tier
    if request.tier == SubscriptionTier.FREE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot checkout for free tier",
        )
    
    # Check if already on higher tier
    tier_order = {
        SubscriptionTier.FREE: 0,
        SubscriptionTier.PRO: 1,
        SubscriptionTier.PRO_PLUS: 2,
    }
    
    if tier_order.get(subscription.tier, 0) >= tier_order.get(request.tier, 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Already on {subscription.tier.value} tier or higher",
        )
    
    # Get price ID
    pricing = TierPricing.get_pricing(request.tier)
    price_id = (
        pricing["stripe_price_id_yearly"]
        if request.billing_cycle == BillingCycle.YEARLY
        else pricing["stripe_price_id_monthly"]
    )
    
    if not price_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Price not configured for this tier",
        )
    
    # Get or create Stripe customer
    if not subscription.stripe_customer_id:
        customer = stripe.Customer.create(
            email=user.email,
            name=user.name,
            metadata={"user_id": str(user.id)},
        )
        subscription.stripe_customer_id = customer.id
        db.commit()
    
    # Create checkout session with trial
    session = stripe.checkout.Session.create(
        customer=subscription.stripe_customer_id,
        payment_method_types=["card"],
        line_items=[{"price": price_id, "quantity": 1}],
        mode="subscription",
        subscription_data={
            "trial_period_days": 7,  # 7-day free trial
            "metadata": {
                "user_id": str(user.id),
                "tier": request.tier.value,
            },
        },
        success_url=request.success_url,
        cancel_url=request.cancel_url,
        metadata={
            "user_id": str(user.id),
            "tier": request.tier.value,
            "billing_cycle": request.billing_cycle.value,
        },
    )
    
    return CheckoutSessionResponse(
        checkout_url=session.url,
        session_id=session.id,
    )


@router.post("/billing-portal", response_model=BillingPortalResponse)
async def create_billing_portal(
    user: CurrentUser,
    subscription: UserSubscription,
):
    """Create Stripe billing portal session."""
    if not settings.stripe_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments are not configured",
        )
    
    if not subscription.stripe_customer_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No billing information found",
        )
    
    session = stripe.billing_portal.Session.create(
        customer=subscription.stripe_customer_id,
        return_url=f"{settings.app_url}/settings",
    )
    
    return BillingPortalResponse(portal_url=session.url)


# =============================================================================
# WEBHOOK HANDLER
# =============================================================================

@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    db: DB,
    stripe_signature: str = Header(None),
):
    """Handle Stripe webhook events."""
    if not settings.stripe_webhook_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Webhook not configured",
        )
    
    payload = await request.body()
    
    try:
        event = stripe.Webhook.construct_event(
            payload,
            stripe_signature,
            settings.stripe_webhook_secret,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")
    
    # Handle events
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        await handle_checkout_completed(session, db)
    
    elif event["type"] == "customer.subscription.updated":
        subscription_data = event["data"]["object"]
        await handle_subscription_updated(subscription_data, db)
    
    elif event["type"] == "customer.subscription.deleted":
        subscription_data = event["data"]["object"]
        await handle_subscription_deleted(subscription_data, db)
    
    elif event["type"] == "invoice.payment_failed":
        invoice = event["data"]["object"]
        await handle_payment_failed(invoice, db)
    
    return {"status": "success"}


# =============================================================================
# WEBHOOK HANDLERS
# =============================================================================

async def handle_checkout_completed(session: dict, db):
    """Handle successful checkout."""
    customer_id = session.get("customer")
    subscription_id = session.get("subscription")
    metadata = session.get("metadata", {})
    
    result = db.execute(
        select(Subscription).where(Subscription.stripe_customer_id == customer_id)
    )
    subscription = result.scalar_one_or_none()
    
    if subscription:
        # Get subscription details from Stripe
        stripe_sub = stripe.Subscription.retrieve(subscription_id)
        
        # Determine tier from metadata or price ID
        tier_str = metadata.get("tier", "pro")
        billing_str = metadata.get("billing_cycle", "monthly")
        
        tier = SubscriptionTier(tier_str) if tier_str else SubscriptionTier.PRO
        billing = BillingCycle(billing_str) if billing_str else BillingCycle.MONTHLY
        
        subscription.stripe_subscription_id = subscription_id
        subscription.stripe_price_id = stripe_sub["items"]["data"][0]["price"]["id"]
        subscription.tier = tier
        subscription.billing_cycle = billing
        subscription.status = (
            SubscriptionStatus.TRIALING
            if stripe_sub.get("status") == "trialing"
            else SubscriptionStatus.ACTIVE
        )
        subscription.current_period_start = datetime.fromtimestamp(stripe_sub["current_period_start"])
        subscription.current_period_end = datetime.fromtimestamp(stripe_sub["current_period_end"])
        
        # Trial dates
        if stripe_sub.get("trial_start"):
            subscription.trial_start = datetime.fromtimestamp(stripe_sub["trial_start"])
        if stripe_sub.get("trial_end"):
            subscription.trial_end = datetime.fromtimestamp(stripe_sub["trial_end"])
        
        db.commit()


async def handle_subscription_updated(subscription_data: dict, db):
    """Handle subscription update."""
    subscription_id = subscription_data.get("id")
    
    result = db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == subscription_id)
    )
    subscription = result.scalar_one_or_none()
    
    if subscription:
        status_map = {
            "active": SubscriptionStatus.ACTIVE,
            "past_due": SubscriptionStatus.PAST_DUE,
            "canceled": SubscriptionStatus.CANCELED,
            "trialing": SubscriptionStatus.TRIALING,
            "incomplete": SubscriptionStatus.INCOMPLETE,
            "paused": SubscriptionStatus.PAUSED,
        }
        
        subscription.status = status_map.get(
            subscription_data.get("status"),
            SubscriptionStatus.ACTIVE
        )
        subscription.cancel_at_period_end = subscription_data.get("cancel_at_period_end", False)
        subscription.current_period_start = datetime.fromtimestamp(
            subscription_data.get("current_period_start")
        )
        subscription.current_period_end = datetime.fromtimestamp(
            subscription_data.get("current_period_end")
        )
        
        db.commit()


async def handle_subscription_deleted(subscription_data: dict, db):
    """Handle subscription cancellation - downgrade to free."""
    subscription_id = subscription_data.get("id")
    
    result = db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == subscription_id)
    )
    subscription = result.scalar_one_or_none()
    
    if subscription:
        subscription.tier = SubscriptionTier.FREE
        subscription.billing_cycle = None
        subscription.status = SubscriptionStatus.CANCELED
        subscription.stripe_subscription_id = None
        subscription.stripe_price_id = None
        
        db.commit()


async def handle_payment_failed(invoice: dict, db):
    """Handle failed payment."""
    customer_id = invoice.get("customer")
    
    result = db.execute(
        select(Subscription).where(Subscription.stripe_customer_id == customer_id)
    )
    subscription = result.scalar_one_or_none()
    
    if subscription:
        subscription.status = SubscriptionStatus.PAST_DUE
        db.commit()
