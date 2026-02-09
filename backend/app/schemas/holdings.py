"""Holdings schemas."""
from datetime import datetime, date
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel, field_validator

from app.models.holdings import ChangeType, ActionType
from app.services.cusip_lookup import get_ticker_from_cusip_sync


def _resolve_ticker_if_cusip(ticker: str, company_name: str | None = None) -> str:
    """
    Resolve ticker if it looks like a CUSIP.

    13F filings use CUSIPs instead of tickers. This helper converts
    common CUSIPs to readable ticker symbols for better UX.
    """
    if not ticker or len(ticker) < 6:
        return ticker

    # Check if it looks like a CUSIP (mostly numeric, 6-9 chars)
    digit_count = sum(1 for c in ticker if c.isdigit())
    if digit_count >= 5 and len(ticker) >= 6:
        # Try to resolve from cache
        resolved = get_ticker_from_cusip_sync(ticker)
        if resolved:
            return resolved

    return ticker


class HoldingRecordResponse(BaseModel):
    """Individual holding record response."""
    id: UUID
    ticker: str
    company_name: str | None
    cusip: str | None
    shares: Decimal | None
    market_value: Decimal | None
    weight_percent: Decimal | None
    share_price: Decimal | None

    @field_validator("ticker", mode="before")
    @classmethod
    def resolve_cusip_to_ticker(cls, v, info):
        """Resolve CUSIP to ticker symbol if possible."""
        company_name = info.data.get("company_name") if info.data else None
        return _resolve_ticker_if_cusip(v, company_name)

    class Config:
        from_attributes = True


class SectorAllocationResponse(BaseModel):
    """Sector allocation breakdown."""
    sector: str
    weight_percent: float
    num_positions: int


class HoldingsChangeResponse(BaseModel):
    """Holdings change response."""
    id: UUID
    investor_id: UUID
    ticker: str
    company_name: str | None
    change_type: ChangeType
    from_date: date
    to_date: date
    shares_before: Decimal | None
    shares_after: Decimal | None
    shares_delta: Decimal | None
    shares_delta_percent: Decimal | None
    weight_before: Decimal | None
    weight_after: Decimal | None
    weight_delta: Decimal | None
    value_before: Decimal | None
    value_after: Decimal | None
    value_delta: Decimal | None
    price_range_low: Decimal | None
    price_range_high: Decimal | None

    @field_validator("ticker", mode="before")
    @classmethod
    def resolve_cusip_to_ticker(cls, v, info):
        """Resolve CUSIP to ticker symbol if possible."""
        company_name = info.data.get("company_name") if info.data else None
        return _resolve_ticker_if_cusip(v, company_name)

    class Config:
        from_attributes = True


class HoldingsSnapshotResponse(BaseModel):
    """Holdings snapshot response."""
    id: UUID
    investor_id: UUID
    snapshot_date: date
    filing_date: date | None
    period_end_date: date | None
    total_positions: int
    total_value: Decimal | None
    records: list[HoldingRecordResponse] | None = None
    sector_allocation: list[SectorAllocationResponse] | None = None
    top_changes: list[HoldingsChangeResponse] | None = None
    
    class Config:
        from_attributes = True


class InvestorActionResponse(BaseModel):
    """Investor action/trade response."""
    id: UUID
    investor_id: UUID
    action_type: ActionType
    ticker: str
    company_name: str | None
    trade_date: date
    shares: Decimal | None
    estimated_value: Decimal | None
    weight_percent: Decimal | None
    price_range_low: Decimal | None
    price_range_high: Decimal | None
    fund_name: str | None
    
    class Config:
        from_attributes = True


class HoldingsChangesListResponse(BaseModel):
    """Holdings changes list response."""
    changes: list[HoldingsChangeResponse]
    total: int
    from_date: date | None
    to_date: date | None


class InvestorActionsListResponse(BaseModel):
    """Investor actions list response."""
    actions: list[InvestorActionResponse]
    total: int
    from_date: date | None
    to_date: date | None
    # Note for 13F filers - trade data not available
    note: str | None = None