"""Watchlist API routes."""
from uuid import UUID
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload

from app.api.deps import DB, CurrentUser, UserSubscription
from app.models.watchlist import Watchlist, WatchlistItem
from app.models.investor import Investor
from app.schemas.watchlist import (
    WatchlistResponse,
    WatchlistItemCreate,
    WatchlistItemUpdate,
    WatchlistItemResponse,
)

router = APIRouter()


@router.get("", response_model=WatchlistResponse)
async def get_watchlist(user: CurrentUser, db: DB):
    """Get user's default watchlist."""
    result = await db.execute(
        select(Watchlist)
        .options(
            selectinload(Watchlist.items)
        )
        .where(Watchlist.user_id == user.id, Watchlist.is_default == True)
    )
    watchlist = result.scalar_one_or_none()
    
    if not watchlist:
        # Create default watchlist
        watchlist = Watchlist(
            user_id=user.id,
            name="My Watchlist",
            is_default=True,
        )
        db.add(watchlist)
        await db.commit()
        await db.refresh(watchlist)
        watchlist.items = []
    
    # Load investor details for items
    if watchlist.items:
        investor_ids = [item.investor_id for item in watchlist.items]
        investors_result = await db.execute(
            select(Investor).where(Investor.id.in_(investor_ids))
        )
        investors = {i.id: i for i in investors_result.scalars().all()}
        
        for item in watchlist.items:
            item.investor = investors.get(item.investor_id)
    
    watchlist.items_count = len(watchlist.items)
    return watchlist


@router.post("/items", response_model=WatchlistItemResponse, status_code=status.HTTP_201_CREATED)
async def add_to_watchlist(
    request: WatchlistItemCreate,
    user: CurrentUser,
    subscription: UserSubscription,
    db: DB,
):
    """Add an investor to watchlist."""
    # Get or create default watchlist
    result = await db.execute(
        select(Watchlist)
        .options(selectinload(Watchlist.items))
        .where(Watchlist.user_id == user.id, Watchlist.is_default == True)
    )
    watchlist = result.scalar_one_or_none()
    
    if not watchlist:
        watchlist = Watchlist(
            user_id=user.id,
            name="My Watchlist",
            is_default=True,
        )
        db.add(watchlist)
        await db.flush()
    
    # Check subscription limits (skip if unlimited = -1)
    max_allowed = subscription.max_monitored_investors
    if max_allowed != -1:  # -1 means unlimited
        items_count = await db.scalar(
            select(func.count())
            .select_from(WatchlistItem)
            .where(WatchlistItem.watchlist_id == watchlist.id)
        )

        if items_count >= max_allowed:
            tier_name = subscription.tier.value if hasattr(subscription.tier, 'value') else str(subscription.tier)
            if tier_name == 'free':
                detail = f"Free users can track up to {max_allowed} investors. Upgrade to Pro to track up to 10 investors."
            elif tier_name == 'pro':
                detail = f"Pro users can track up to {max_allowed} investors. Upgrade to Pro+ for unlimited tracking."
            else:
                detail = f"Your plan allows monitoring up to {max_allowed} investors."

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=detail,
            )
    
    # Check if investor exists (support both UUID and slug)
    investor_id_str = str(request.investor_id)
    investor = None

    # Try to parse as UUID first
    try:
        investor_uuid = UUID(investor_id_str)
        investor_result = await db.execute(
            select(Investor).where(Investor.id == investor_uuid, Investor.is_active == True)
        )
        investor = investor_result.scalar_one_or_none()
    except (ValueError, TypeError):
        pass

    # If not found by UUID, try slug
    if not investor:
        investor_result = await db.execute(
            select(Investor).where(Investor.slug == investor_id_str, Investor.is_active == True)
        )
        investor = investor_result.scalar_one_or_none()

    if not investor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Investor not found",
        )
    
    # Check if already in watchlist (use resolved investor.id)
    existing = await db.execute(
        select(WatchlistItem).where(
            WatchlistItem.watchlist_id == watchlist.id,
            WatchlistItem.investor_id == investor.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Investor already in watchlist",
        )
    
    # Check notification frequency entitlement
    if request.notification_frequency.value == "instant" and not subscription.can_instant_alerts:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Instant alerts require Pro subscription",
        )
    
    # Add to watchlist (use resolved investor.id)
    item = WatchlistItem(
        watchlist_id=watchlist.id,
        investor_id=investor.id,
        notification_frequency=request.notification_frequency,
        email_enabled=request.email_enabled,
        user_notes=request.user_notes,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    
    item.investor = investor
    return item


@router.patch("/items/{item_id}", response_model=WatchlistItemResponse)
async def update_watchlist_item(
    item_id: UUID,
    request: WatchlistItemUpdate,
    user: CurrentUser,
    subscription: UserSubscription,
    db: DB,
):
    """Update watchlist item settings."""
    # Get the item
    result = await db.execute(
        select(WatchlistItem)
        .join(Watchlist)
        .where(WatchlistItem.id == item_id, Watchlist.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist item not found",
        )
    
    # Check notification frequency entitlement
    if request.notification_frequency and request.notification_frequency.value == "instant":
        if not subscription.can_instant_alerts:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Instant alerts require Pro subscription",
            )
    
    # Update fields
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(item, field, value)
    
    await db.commit()
    await db.refresh(item)
    
    # Load investor
    investor_result = await db.execute(
        select(Investor).where(Investor.id == item.investor_id)
    )
    item.investor = investor_result.scalar_one_or_none()
    
    return item


@router.delete("/items/{item_id}")
async def remove_from_watchlist(item_id: UUID, user: CurrentUser, db: DB):
    """Remove an investor from watchlist."""
    result = await db.execute(
        select(WatchlistItem)
        .join(Watchlist)
        .where(WatchlistItem.id == item_id, Watchlist.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist item not found",
        )
    
    await db.delete(item)
    await db.commit()
    
    return {"message": "Removed from watchlist"}


@router.get("/items/{item_id}", response_model=WatchlistItemResponse)
async def get_watchlist_item(item_id: UUID, user: CurrentUser, db: DB):
    """Get a specific watchlist item."""
    result = await db.execute(
        select(WatchlistItem)
        .join(Watchlist)
        .where(WatchlistItem.id == item_id, Watchlist.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist item not found",
        )
    
    # Load investor
    investor_result = await db.execute(
        select(Investor).where(Investor.id == item.investor_id)
    )
    item.investor = investor_result.scalar_one_or_none()
    
    return item
