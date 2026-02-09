"""Holdings diff computation service."""
from datetime import date
from decimal import Decimal
from typing import Optional
from dataclasses import dataclass

from app.models.holdings import ChangeType, HoldingsChange


@dataclass
class DiffResult:
    """Result of a holdings diff computation."""
    ticker: str
    company_name: Optional[str]
    change_type: ChangeType
    shares_before: Optional[Decimal]
    shares_after: Optional[Decimal]
    shares_delta: Optional[Decimal]
    shares_delta_percent: Optional[Decimal]
    weight_before: Optional[Decimal]
    weight_after: Optional[Decimal]
    weight_delta: Optional[Decimal]
    value_before: Optional[Decimal]
    value_after: Optional[Decimal]
    value_delta: Optional[Decimal]


def compute_holdings_diff(
    old_holdings: dict[str, dict],
    new_holdings: dict[str, dict],
) -> list[DiffResult]:
    """
    Compute the diff between two holdings snapshots.
    
    Args:
        old_holdings: Dict mapping ticker to holding data for the older snapshot
        new_holdings: Dict mapping ticker to holding data for the newer snapshot
        
    Each holding dict should have: ticker, company_name, shares, weight_percent, market_value
    
    Returns:
        List of DiffResult objects representing the changes
    """
    diffs = []
    
    all_tickers = set(old_holdings.keys()) | set(new_holdings.keys())
    
    for ticker in all_tickers:
        old = old_holdings.get(ticker)
        new = new_holdings.get(ticker)
        
        if old is None and new is not None:
            # New position
            diffs.append(DiffResult(
                ticker=ticker,
                company_name=new.get("company_name"),
                change_type=ChangeType.NEW,
                shares_before=None,
                shares_after=Decimal(str(new.get("shares", 0))) if new.get("shares") else None,
                shares_delta=Decimal(str(new.get("shares", 0))) if new.get("shares") else None,
                shares_delta_percent=None,
                weight_before=None,
                weight_after=Decimal(str(new.get("weight_percent", 0))) if new.get("weight_percent") else None,
                weight_delta=Decimal(str(new.get("weight_percent", 0))) if new.get("weight_percent") else None,
                value_before=None,
                value_after=Decimal(str(new.get("market_value", 0))) if new.get("market_value") else None,
                value_delta=Decimal(str(new.get("market_value", 0))) if new.get("market_value") else None,
            ))
        
        elif old is not None and new is None:
            # Sold out
            diffs.append(DiffResult(
                ticker=ticker,
                company_name=old.get("company_name"),
                change_type=ChangeType.SOLD_OUT,
                shares_before=Decimal(str(old.get("shares", 0))) if old.get("shares") else None,
                shares_after=None,
                shares_delta=-Decimal(str(old.get("shares", 0))) if old.get("shares") else None,
                shares_delta_percent=Decimal("-100"),
                weight_before=Decimal(str(old.get("weight_percent", 0))) if old.get("weight_percent") else None,
                weight_after=None,
                weight_delta=-Decimal(str(old.get("weight_percent", 0))) if old.get("weight_percent") else None,
                value_before=Decimal(str(old.get("market_value", 0))) if old.get("market_value") else None,
                value_after=None,
                value_delta=-Decimal(str(old.get("market_value", 0))) if old.get("market_value") else None,
            ))
        
        elif old is not None and new is not None:
            # Compare shares
            old_shares = Decimal(str(old.get("shares", 0))) if old.get("shares") else Decimal(0)
            new_shares = Decimal(str(new.get("shares", 0))) if new.get("shares") else Decimal(0)
            shares_delta = new_shares - old_shares
            
            # Calculate percent change
            if old_shares and old_shares > 0:
                shares_delta_percent = (shares_delta / old_shares) * 100
            else:
                shares_delta_percent = None
            
            # Skip if no meaningful change (less than 0.1%)
            if shares_delta_percent is not None and abs(shares_delta_percent) < Decimal("0.1"):
                continue
            
            # Weight change
            old_weight = Decimal(str(old.get("weight_percent", 0))) if old.get("weight_percent") else None
            new_weight = Decimal(str(new.get("weight_percent", 0))) if new.get("weight_percent") else None
            weight_delta = None
            if old_weight is not None and new_weight is not None:
                weight_delta = new_weight - old_weight
            
            # Value change
            old_value = Decimal(str(old.get("market_value", 0))) if old.get("market_value") else None
            new_value = Decimal(str(new.get("market_value", 0))) if new.get("market_value") else None
            value_delta = None
            if old_value is not None and new_value is not None:
                value_delta = new_value - old_value
            
            # Determine change type
            if shares_delta > 0:
                change_type = ChangeType.ADDED
            else:
                change_type = ChangeType.REDUCED
            
            diffs.append(DiffResult(
                ticker=ticker,
                company_name=new.get("company_name") or old.get("company_name"),
                change_type=change_type,
                shares_before=old_shares if old_shares else None,
                shares_after=new_shares if new_shares else None,
                shares_delta=shares_delta if shares_delta else None,
                shares_delta_percent=shares_delta_percent,
                weight_before=old_weight,
                weight_after=new_weight,
                weight_delta=weight_delta,
                value_before=old_value,
                value_after=new_value,
                value_delta=value_delta,
            ))
    
    # Sort by absolute weight delta (most significant changes first)
    diffs.sort(
        key=lambda d: abs(d.weight_delta) if d.weight_delta else Decimal(0),
        reverse=True
    )
    
    return diffs


def diff_to_db_model(
    diff: DiffResult,
    investor_id,
    from_date: date,
    to_date: date,
    price_range_low: Optional[Decimal] = None,
    price_range_high: Optional[Decimal] = None,
) -> HoldingsChange:
    """Convert a DiffResult to a HoldingsChange database model."""
    return HoldingsChange(
        investor_id=investor_id,
        ticker=diff.ticker,
        company_name=diff.company_name,
        change_type=diff.change_type,
        from_date=from_date,
        to_date=to_date,
        shares_before=diff.shares_before,
        shares_after=diff.shares_after,
        shares_delta=diff.shares_delta,
        shares_delta_percent=diff.shares_delta_percent,
        weight_before=diff.weight_before,
        weight_after=diff.weight_after,
        weight_delta=diff.weight_delta,
        value_before=diff.value_before,
        value_after=diff.value_after,
        value_delta=diff.value_delta,
        price_range_low=price_range_low,
        price_range_high=price_range_high,
    )
