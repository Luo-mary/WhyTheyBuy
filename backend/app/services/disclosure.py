"""
Pluggable Disclosure Service.

This module implements a framework for fetching and normalizing data from
ANY disclosure source, not just ARK or 13F.

The core abstraction:
- DisclosureAdapter: Base class for fetching data from a specific source
- DisclosureService: Orchestrates adapters and normalizes data
- NormalizedHolding: Common schema for all disclosure types
"""
import abc
import logging
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Optional
from uuid import UUID

from app.models.investor import (
    Investor,
    DisclosureSource,
    DisclosureSourceType,
    DataGranularity,
)

logger = logging.getLogger(__name__)


# =============================================================================
# NORMALIZED DATA SCHEMAS
# =============================================================================

@dataclass
class NormalizedHolding:
    """
    Normalized holding data from ANY disclosure source.
    
    This is the common internal schema that all adapters produce.
    Fields may be None if not available from the specific source.
    """
    # Required fields
    ticker: str
    company_name: str
    
    # Quantity (at least one should be present)
    shares: Decimal | None = None
    market_value: Decimal | None = None
    portfolio_weight: Decimal | None = None
    
    # Date context
    as_of_date: date | None = None  # Date the data represents
    trade_date: date | None = None  # Specific trade date (if available)
    filing_date: date | None = None  # Date of disclosure filing
    
    # Additional context
    cusip: str | None = None
    sedol: str | None = None
    isin: str | None = None
    exchange: str | None = None
    sector: str | None = None
    
    # Source metadata
    source_type: DisclosureSourceType | None = None
    source_record_id: str | None = None  # ID from source for deduplication
    
    # Trade-specific (ETF daily trades)
    action_type: str | None = None  # "buy", "sell", None for holdings
    
    # Raw source data for debugging
    raw_data: dict | None = field(default=None, repr=False)


@dataclass
class NormalizedDisclosure:
    """
    A complete disclosure fetch result.
    """
    investor_id: UUID
    source_type: DisclosureSourceType
    
    # The holdings
    holdings: list[NormalizedHolding]
    
    # Metadata
    disclosure_date: date  # Date this disclosure represents
    fetch_timestamp: datetime  # When we fetched it
    
    # Source info
    source_url: str | None = None
    source_document_id: str | None = None
    
    # Data completeness indicators
    has_shares: bool = False
    has_values: bool = False
    has_weights: bool = False
    has_trade_dates: bool = False
    
    # Limitations to display
    limitations: list[str] = field(default_factory=list)


# =============================================================================
# BASE ADAPTER CLASS
# =============================================================================

class DisclosureAdapter(abc.ABC):
    """
    Abstract base class for disclosure source adapters.
    
    Each adapter knows how to:
    1. Fetch data from a specific source
    2. Parse the raw data
    3. Normalize it to NormalizedHolding format
    
    To add a new disclosure source, create a subclass and implement:
    - fetch_raw_data()
    - parse_and_normalize()
    """
    
    source_type: DisclosureSourceType
    
    def __init__(self, disclosure_source: DisclosureSource):
        """Initialize with the disclosure source configuration."""
        self.disclosure_source = disclosure_source
        self.config = disclosure_source.source_config or {}
    
    @abc.abstractmethod
    async def fetch_raw_data(self) -> Any:
        """
        Fetch raw data from the disclosure source.
        
        Returns whatever format the source provides (CSV, JSON, HTML, etc.)
        """
        pass
    
    @abc.abstractmethod
    async def parse_and_normalize(self, raw_data: Any) -> NormalizedDisclosure:
        """
        Parse raw data and normalize to common schema.
        
        Returns a NormalizedDisclosure with list of NormalizedHolding objects.
        """
        pass
    
    async def fetch(self) -> NormalizedDisclosure:
        """
        Main entry point: fetch and normalize data.
        """
        try:
            raw_data = await self.fetch_raw_data()
            return await self.parse_and_normalize(raw_data)
        except Exception as e:
            logger.error(f"Error fetching disclosure from {self.source_type}: {e}")
            raise
    
    def get_limitations(self) -> list[str]:
        """Get known limitations for this source."""
        return self.disclosure_source.known_limitations or []


# =============================================================================
# ETF HOLDINGS ADAPTER
# =============================================================================

class ETFHoldingsAdapter(DisclosureAdapter):
    """
    Adapter for ETF daily holdings disclosures (ARK-style).
    
    Configuration expects:
    - csv_url: URL to fetch CSV data
    - fund_ticker: The ETF ticker (e.g., "ARKK")
    """
    
    source_type = DisclosureSourceType.ETF_HOLDINGS
    
    async def fetch_raw_data(self) -> str:
        """Fetch CSV data from the configured URL."""
        import aiohttp
        
        url = self.config.get("csv_url")
        if not url:
            raise ValueError("ETF adapter requires 'csv_url' in config")
        
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as response:
                response.raise_for_status()
                return await response.text()
    
    async def parse_and_normalize(self, raw_data: str) -> NormalizedDisclosure:
        """Parse ARK-style CSV and normalize."""
        import csv
        from io import StringIO
        
        holdings = []
        reader = csv.DictReader(StringIO(raw_data))
        
        has_shares = False
        has_values = False
        has_weights = False
        
        for row in reader:
            # Handle different CSV column names
            ticker = row.get("ticker") or row.get("Ticker") or row.get("TICKER", "")
            company = row.get("company") or row.get("Company") or row.get("COMPANY", "")
            
            shares_str = row.get("shares") or row.get("Shares") or row.get("SHARES")
            value_str = row.get("market value($)") or row.get("Market Value") or row.get("VALUE")
            weight_str = row.get("weight(%)") or row.get("Weight") or row.get("WEIGHT")
            
            # Parse values
            shares = self._parse_decimal(shares_str)
            value = self._parse_decimal(value_str)
            weight = self._parse_decimal(weight_str)
            
            if shares:
                has_shares = True
            if value:
                has_values = True
            if weight:
                has_weights = True
            
            if ticker:  # Skip empty rows
                holdings.append(NormalizedHolding(
                    ticker=ticker.strip().upper(),
                    company_name=company.strip(),
                    shares=shares,
                    market_value=value,
                    portfolio_weight=weight,
                    as_of_date=date.today(),
                    source_type=self.source_type,
                    cusip=row.get("cusip") or row.get("CUSIP"),
                    raw_data=dict(row),
                ))
        
        return NormalizedDisclosure(
            investor_id=self.disclosure_source.investor_id,
            source_type=self.source_type,
            holdings=holdings,
            disclosure_date=date.today(),
            fetch_timestamp=datetime.utcnow(),
            source_url=self.config.get("csv_url"),
            has_shares=has_shares,
            has_values=has_values,
            has_weights=has_weights,
            has_trade_dates=False,
            limitations=self.get_limitations() or ["Execution prices unknown"],
        )
    
    def _parse_decimal(self, value: str | None) -> Decimal | None:
        """Parse a string to Decimal, handling common formats."""
        if not value:
            return None
        try:
            # Remove common formatting
            cleaned = value.replace(",", "").replace("$", "").replace("%", "").strip()
            if cleaned:
                return Decimal(cleaned)
        except:
            pass
        return None


# =============================================================================
# SEC 13F ADAPTER
# =============================================================================

class SEC13FAdapter(DisclosureAdapter):
    """
    Adapter for SEC Form 13F filings.
    
    Configuration expects:
    - cik: SEC CIK number
    - filer_name: Name of the filer
    """
    
    source_type = DisclosureSourceType.SEC_13F
    
    async def fetch_raw_data(self) -> dict:
        """Fetch 13F data from SEC EDGAR."""
        import aiohttp
        
        cik = self.config.get("cik", "").lstrip("0")
        if not cik:
            raise ValueError("13F adapter requires 'cik' in config")
        
        # SEC EDGAR API for filings
        url = f"https://data.sec.gov/submissions/CIK{cik.zfill(10)}.json"
        
        headers = {
            "User-Agent": "WhyTheyBuy info@whytheybuy.com",
            "Accept-Encoding": "gzip, deflate",
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers) as response:
                response.raise_for_status()
                return await response.json()
    
    async def parse_and_normalize(self, raw_data: dict) -> NormalizedDisclosure:
        """Parse 13F filing data and normalize."""
        # This is a simplified parser - production would need full XML parsing
        holdings = []
        
        filings = raw_data.get("filings", {}).get("recent", {})
        forms = filings.get("form", [])
        
        # Find most recent 13F-HR
        latest_13f_index = None
        for i, form in enumerate(forms):
            if form in ["13F-HR", "13F-HR/A"]:
                latest_13f_index = i
                break
        
        if latest_13f_index is None:
            return NormalizedDisclosure(
                investor_id=self.disclosure_source.investor_id,
                source_type=self.source_type,
                holdings=[],
                disclosure_date=date.today(),
                fetch_timestamp=datetime.utcnow(),
                limitations=["No recent 13F filing found"],
            )
        
        # Get filing details
        filing_date_str = filings.get("filingDate", [])[latest_13f_index]
        report_date_str = filings.get("reportDate", [])[latest_13f_index]
        accession = filings.get("accessionNumber", [])[latest_13f_index]
        
        # Parse dates
        filing_date = self._parse_date(filing_date_str)
        report_date = self._parse_date(report_date_str)
        
        # In production, we would fetch and parse the actual 13F XML here
        # For now, return metadata with empty holdings (to be filled by actual parser)
        
        return NormalizedDisclosure(
            investor_id=self.disclosure_source.investor_id,
            source_type=self.source_type,
            holdings=holdings,
            disclosure_date=report_date or date.today(),
            fetch_timestamp=datetime.utcnow(),
            source_document_id=accession,
            has_shares=True,
            has_values=True,
            has_weights=False,
            has_trade_dates=False,
            limitations=self.get_limitations() or [
                "No exact trade dates",
                "No execution prices",
                "45-day reporting delay",
                "Quarter-end snapshot only",
            ],
        )
    
    def _parse_date(self, date_str: str | None) -> date | None:
        """Parse SEC date format."""
        if not date_str:
            return None
        try:
            return datetime.strptime(date_str, "%Y-%m-%d").date()
        except:
            return None


# =============================================================================
# ADAPTER REGISTRY
# =============================================================================

class AdapterRegistry:
    """
    Registry of available disclosure adapters.
    
    To add a new disclosure source:
    1. Create a new adapter class extending DisclosureAdapter
    2. Register it here
    """
    
    _adapters: dict[DisclosureSourceType, type[DisclosureAdapter]] = {
        DisclosureSourceType.ETF_HOLDINGS: ETFHoldingsAdapter,
        DisclosureSourceType.SEC_13F: SEC13FAdapter,
    }
    
    @classmethod
    def register(cls, source_type: DisclosureSourceType, adapter_class: type[DisclosureAdapter]):
        """Register a new adapter."""
        cls._adapters[source_type] = adapter_class
    
    @classmethod
    def get_adapter(cls, disclosure_source: DisclosureSource) -> DisclosureAdapter | None:
        """Get an adapter instance for a disclosure source."""
        adapter_class = cls._adapters.get(disclosure_source.source_type)
        if adapter_class:
            return adapter_class(disclosure_source)
        return None
    
    @classmethod
    def get_supported_types(cls) -> list[DisclosureSourceType]:
        """Get list of supported disclosure types."""
        return list(cls._adapters.keys())


# =============================================================================
# DISCLOSURE SERVICE
# =============================================================================

class DisclosureService:
    """
    Main service for fetching and processing disclosures.
    
    This service:
    1. Selects the appropriate adapter for each disclosure source
    2. Fetches and normalizes data
    3. Computes diffs against previous snapshots
    """
    
    def __init__(self):
        self.registry = AdapterRegistry
    
    async def fetch_disclosure(
        self,
        disclosure_source: DisclosureSource,
    ) -> NormalizedDisclosure | None:
        """
        Fetch disclosure data from a source.
        
        Returns normalized data or None if adapter not available.
        """
        adapter = self.registry.get_adapter(disclosure_source)
        if not adapter:
            logger.warning(f"No adapter for source type: {disclosure_source.source_type}")
            return None
        
        return await adapter.fetch()
    
    async def fetch_all_disclosures(
        self,
        investor: Investor,
    ) -> list[NormalizedDisclosure]:
        """
        Fetch all active disclosure sources for an investor.
        """
        results = []
        
        for source in investor.disclosure_sources:
            if not source.is_active:
                continue
            
            try:
                disclosure = await self.fetch_disclosure(source)
                if disclosure:
                    results.append(disclosure)
            except Exception as e:
                logger.error(f"Error fetching {source.source_type} for {investor.name}: {e}")
        
        return results
    
    def get_data_confidence_score(self, investor: Investor) -> int:
        """
        Calculate data confidence score (0-100) based on disclosure sources.
        
        Higher scores for:
        - More frequent data (daily > quarterly)
        - More complete data (shares + values + weights)
        - Lower reporting delays
        """
        if not investor.disclosure_sources:
            return 10
        
        # Get primary source
        primary = investor.get_primary_disclosure()
        if not primary:
            return 20
        
        # Base score by granularity
        granularity_scores = {
            DataGranularity.REAL_TIME: 100,
            DataGranularity.DAILY: 90,
            DataGranularity.WEEKLY: 75,
            DataGranularity.MONTHLY: 60,
            DataGranularity.QUARTERLY: 45,
            DataGranularity.SEMI_ANNUAL: 30,
            DataGranularity.ANNUAL: 20,
            DataGranularity.IRREGULAR: 15,
        }
        
        score = granularity_scores.get(primary.data_granularity, 30)
        
        # Adjust for available fields
        fields = primary.available_fields or []
        if "shares" in fields:
            score += 5
        if "value" in fields:
            score += 5
        if "weight" in fields:
            score += 5
        
        # Penalize for delays
        delay = primary.reporting_delay_days or 0
        if delay > 30:
            score -= 10
        elif delay > 7:
            score -= 5
        
        return max(10, min(100, score))
    
    def get_disclosure_summary(self, investor: Investor) -> dict:
        """
        Get a summary of disclosure information for UI display.
        """
        primary = investor.get_primary_disclosure()
        
        return {
            "investor_type": investor.investor_type.value,
            "primary_disclosure": primary.source_type.value if primary else None,
            "update_frequency": investor.expected_update_frequency.value,
            "typical_delay_days": investor.typical_reporting_delay_days,
            "data_confidence": investor.data_confidence_score,
            "supported_features": investor.supported_features,
            "disclosure_sources": [
                {
                    "type": s.source_type.value,
                    "name": s.source_name,
                    "granularity": s.data_granularity.value,
                    "limitations": s.known_limitations,
                }
                for s in investor.disclosure_sources
            ],
        }
