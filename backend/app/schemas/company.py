"""Company schemas."""
from datetime import datetime, date
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel


class CompanyResponse(BaseModel):
    """Company profile response."""
    id: UUID
    ticker: str
    name: str
    exchange: str | None
    currency: str
    sector: str | None
    industry: str | None
    description: str | None
    website: str | None
    logo_url: str | None
    market_cap: Decimal | None
    shares_outstanding: Decimal | None
    ipo_date: date | None
    profile_last_updated: datetime | None
    
    class Config:
        from_attributes = True


class MarketPriceResponse(BaseModel):
    """Market price response."""
    ticker: str
    price_date: date
    open_price: Decimal | None
    high_price: Decimal | None
    low_price: Decimal | None
    close_price: Decimal | None
    volume: Decimal | None
    adj_close: Decimal | None
    
    class Config:
        from_attributes = True


class PriceRangeResponse(BaseModel):
    """Price range response for a period."""
    ticker: str
    from_date: date
    to_date: date
    period_low: Decimal | None
    period_high: Decimal | None
    period_open: Decimal | None
    period_close: Decimal | None
    average_volume: Decimal | None


class PriceHistoryResponse(BaseModel):
    """Price history response."""
    ticker: str
    prices: list[MarketPriceResponse]
    
    class Config:
        from_attributes = True


class CompanyActivityResponse(BaseModel):
    """Company activity by an investor."""
    ticker: str
    investor_id: UUID
    investor_name: str
    actions: list  # InvestorActionResponse
    changes: list  # HoldingsChangeResponse
