"""
Seed script for WhyTheyBuy database.

This script populates the database with diverse example investors demonstrating
the generic investor framework - NOT limited to ARK or 13F filers.

Usage:
    python -m scripts.seed_data
"""
import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from datetime import timedelta
from app.database import AsyncSessionLocal
from app.models.user import User
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange, ChangeType
from app.models.report import AICompanyReport
from app.models.investor import (
    Investor,
    DisclosureSource,
    StrategyNote,
    InvestorType,
    DisclosureSourceType,
    DataGranularity,
    AlertFrequency,
    SupportedFeature,
    SourceReliabilityLevel,
    DataGranularityLevel,
    TransparencyScorer,
    update_investor_transparency,
    get_default_features_for_disclosure,
    get_default_alert_frequencies,
)

# =============================================================================
# DIVERSE INVESTOR EXAMPLES
# =============================================================================

INVESTORS = [
    # =========================================================================
    # ETF MANAGERS (Daily/Periodic Disclosure)
    # =========================================================================
    {
        "name": "ARK Innovation ETF (ARKK)",
        "slug": "ark-arkk",
        "short_name": "ARKK",
        "description": (
            "ARK Innovation ETF is an actively managed ETF that seeks long-term growth "
            "of capital by investing in companies relevant to disruptive innovation."
        ),
        "investor_type": InvestorType.ETF_MANAGER,
        "expected_update_frequency": DataGranularity.DAILY,
        "typical_reporting_delay_days": 1,
        # Transparency fields
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
        "aum_billions": "~$8B",
        "website_url": "https://ark-invest.com",
        "is_featured": True,
        "supported_features": [
            SupportedFeature.HOLDINGS_DIFF.value,
            SupportedFeature.TRADE_HISTORY.value,
            SupportedFeature.AI_SUMMARY.value,
            SupportedFeature.AI_RATIONALE.value,
            SupportedFeature.INSTANT_ALERTS.value,
            SupportedFeature.WEIGHT_TRACKING.value,
        ],
        "supported_alert_frequencies": [
            AlertFrequency.INSTANT.value,
            AlertFrequency.DAILY_DIGEST.value,
            AlertFrequency.WEEKLY_DIGEST.value,
        ],
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.ETF_HOLDINGS,
                "source_name": "ARK Daily Holdings CSV",
                "is_primary": True,
                "data_granularity": DataGranularity.DAILY,
                "reporting_delay_days": 1,
                "source_config": {
                    "csv_url": "https://ark-funds.com/wp-content/uploads/funds-etf-csv/ARK_INNOVATION_ETF_ARKK_HOLDINGS.csv",
                    "fund_ticker": "ARKK",
                },
                "available_fields": ["shares", "weight", "value"],
                "known_limitations": ["Execution prices not disclosed"],
            }
        ],
        "strategy_notes": [
            {
                "snippet_id": "ARK-001",
                "text": "We invest in companies we believe are leading and benefiting from cross-sector innovation.",
                "source_title": "ARK Investment Philosophy",
                "source_url": "https://ark-invest.com/investment-process",
                "topic": "innovation",
            },
            {
                "snippet_id": "ARK-002",
                "text": "We focus on five innovation platforms: AI, robotics, energy storage, DNA sequencing, and blockchain.",
                "source_title": "ARK Big Ideas 2024",
                "source_url": "https://ark-invest.com/big-ideas-2024",
                "topic": "sector_focus",
            },
        ],
    },
    {
        "name": "ARK Genomic Revolution ETF (ARKG)",
        "slug": "ark-arkg",
        "short_name": "ARKG",
        "description": (
            "ARK Genomic Revolution ETF focuses on companies expected to benefit from "
            "extending and enhancing the quality of human and other life."
        ),
        "investor_type": InvestorType.ETF_MANAGER,
        "expected_update_frequency": DataGranularity.DAILY,
        "typical_reporting_delay_days": 1,
        "data_confidence_score": 90,
        "aum_billions": "~$2B",
        "website_url": "https://ark-invest.com",
        "is_featured": True,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.ETF_HOLDINGS,
                "source_name": "ARK Daily Holdings CSV",
                "is_primary": True,
                "data_granularity": DataGranularity.DAILY,
                "source_config": {
                    "csv_url": "https://ark-funds.com/wp-content/uploads/funds-etf-csv/ARK_GENOMIC_REVOLUTION_ETF_ARKG_HOLDINGS.csv",
                    "fund_ticker": "ARKG",
                },
                "available_fields": ["shares", "weight", "value"],
                "known_limitations": ["Execution prices not disclosed"],
            }
        ],
    },
    
    # =========================================================================
    # 13F FILERS (Quarterly Disclosure)
    # =========================================================================
    {
        "name": "Berkshire Hathaway Inc.",
        "slug": "berkshire-hathaway",
        "short_name": "Berkshire",
        "description": (
            "Berkshire Hathaway is a multinational conglomerate led by Warren Buffett, "
            "known for its long-term value investing approach."
        ),
        "investor_type": InvestorType.INDIVIDUAL_INVESTOR,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 45,
        "aum_billions": "~$350B",
        "website_url": "https://berkshirehathaway.com",
        "is_featured": True,
        "supported_features": [
            SupportedFeature.HOLDINGS_DIFF.value,
            SupportedFeature.AI_SUMMARY.value,
            SupportedFeature.AI_RATIONALE.value,
            SupportedFeature.VALUE_TRACKING.value,
        ],
        "supported_alert_frequencies": [
            AlertFrequency.WEEKLY_DIGEST.value,
            AlertFrequency.ON_DISCLOSURE.value,
        ],
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001067983",
                    "filer_name": "BERKSHIRE HATHAWAY INC",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "45-day reporting delay",
                    "Quarter-end snapshot only",
                ],
            },
            {
                "source_type": DisclosureSourceType.ANNUAL_LETTER,
                "source_name": "Annual Shareholder Letter",
                "is_primary": False,
                "data_granularity": DataGranularity.ANNUAL,
                "reporting_delay_days": 60,
                "source_config": {
                    "url_pattern": "https://berkshirehathaway.com/letters/",
                },
                "available_fields": ["commentary"],
                "known_limitations": ["Selective disclosure", "Annual only"],
            },
        ],
        "strategy_notes": [
            {
                "snippet_id": "BRK-001",
                "text": "We are partial to businesses that can deploy additional capital at high rates of return.",
                "source_title": "2023 Shareholder Letter",
                "source_url": "https://berkshirehathaway.com/letters/2023ltr.pdf",
                "topic": "capital_allocation",
            },
            {
                "snippet_id": "BRK-002",
                "text": "Our favorite holding period is forever.",
                "source_title": "1988 Shareholder Letter",
                "source_url": "https://berkshirehathaway.com/letters/1988.html",
                "topic": "holding_period",
            },
        ],
    },
    {
        "name": "Bridgewater Associates",
        "slug": "bridgewater-associates",
        "short_name": "Bridgewater",
        "description": (
            "Bridgewater Associates is one of the world's largest hedge funds, "
            "known for its systematic, global macro investment approach."
        ),
        "investor_type": InvestorType.HEDGE_FUND,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 40,
        "aum_billions": "~$150B",
        "website_url": "https://bridgewater.com",
        "is_featured": True,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001350694",
                    "filer_name": "BRIDGEWATER ASSOCIATES, LP",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "45-day reporting delay",
                    "Only shows long equity positions",
                ],
            },
        ],
        "strategy_notes": [
            {
                "snippet_id": "BW-001",
                "text": "We use a systematic approach based on understanding cause-effect relationships in the economy.",
                "source_title": "Bridgewater Principles",
                "source_url": "https://principles.com",
                "topic": "systematic",
            },
        ],
    },
    {
        "name": "Renaissance Technologies",
        "slug": "renaissance-technologies",
        "short_name": "RenTech",
        "description": (
            "Renaissance Technologies is a quantitative hedge fund known for its "
            "Medallion Fund and systematic trading strategies."
        ),
        "investor_type": InvestorType.HEDGE_FUND,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 35,
        "aum_billions": "~$100B",
        "is_featured": False,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001037389",
                    "filer_name": "RENAISSANCE TECHNOLOGIES LLC",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "High turnover not fully visible",
                    "Only shows quarter-end snapshot",
                ],
            },
        ],
    },
    
    # =========================================================================
    # FAMILY OFFICES
    # =========================================================================
    {
        "name": "Soros Fund Management",
        "slug": "soros-fund-management",
        "short_name": "Soros",
        "description": (
            "Soros Fund Management is a family office managing George Soros's personal "
            "fortune, known for macro and event-driven strategies."
        ),
        "investor_type": InvestorType.FAMILY_OFFICE,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 40,
        "aum_billions": "~$25B",
        "is_featured": True,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001029160",
                    "filer_name": "SOROS FUND MANAGEMENT LLC",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "45-day reporting delay",
                ],
            },
        ],
    },
    {
        "name": "Duquesne Family Office",
        "slug": "duquesne-family-office",
        "short_name": "Duquesne",
        "description": (
            "Duquesne Family Office manages Stanley Druckenmiller's personal capital, "
            "known for macro trading and concentrated positions."
        ),
        "investor_type": InvestorType.FAMILY_OFFICE,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 40,
        "aum_billions": "~$15B",
        "is_featured": False,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001536411",
                    "filer_name": "DUQUESNE FAMILY OFFICE LLC",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "45-day reporting delay",
                ],
            },
        ],
    },
    
    # =========================================================================
    # MUTUAL FUNDS
    # =========================================================================
    {
        "name": "Fidelity Contrafund",
        "slug": "fidelity-contrafund",
        "short_name": "Contrafund",
        "description": (
            "Fidelity Contrafund is one of the largest actively managed mutual funds, "
            "seeking capital appreciation by investing in growth companies."
        ),
        "investor_type": InvestorType.MUTUAL_FUND,
        "expected_update_frequency": DataGranularity.MONTHLY,
        "typical_reporting_delay_days": 60,
        "data_confidence_score": 55,
        "aum_billions": "~$130B",
        "website_url": "https://fidelity.com",
        "is_featured": False,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.NPORT,
                "source_name": "SEC Form N-PORT",
                "is_primary": True,
                "data_granularity": DataGranularity.MONTHLY,
                "reporting_delay_days": 60,
                "source_config": {
                    "fund_name": "Fidelity Contrafund",
                    "ticker": "FCNTX",
                },
                "available_fields": ["shares", "value", "weight"],
                "known_limitations": [
                    "60-day reporting delay",
                    "Monthly snapshot only",
                    "No trade-level detail",
                ],
            },
        ],
    },
    
    # =========================================================================
    # PUBLIC INSTITUTIONS
    # =========================================================================
    {
        "name": "California Public Employees' Retirement System (CalPERS)",
        "slug": "calpers",
        "short_name": "CalPERS",
        "description": (
            "CalPERS is the largest public pension fund in the US, managing retirement "
            "benefits for California public employees."
        ),
        "investor_type": InvestorType.PUBLIC_INSTITUTION,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 45,
        "aum_billions": "~$450B",
        "website_url": "https://calpers.ca.gov",
        "is_featured": False,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0000016143",
                    "filer_name": "CALIFORNIA PUBLIC EMPLOYEES RETIREMENT SYSTEM",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                    "Diversified portfolio",
                ],
            },
        ],
    },
    
    # =========================================================================
    # ACTIVIST INVESTORS
    # =========================================================================
    {
        "name": "Pershing Square Capital Management",
        "slug": "pershing-square",
        "short_name": "Pershing Square",
        "description": (
            "Pershing Square is an activist hedge fund led by Bill Ackman, known for "
            "concentrated positions and public campaigns."
        ),
        "investor_type": InvestorType.HEDGE_FUND,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "typical_reporting_delay_days": 45,
        "data_confidence_score": 50,
        "aum_billions": "~$16B",
        "website_url": "https://pershingsquareholdings.com",
        "is_featured": True,
        "disclosure_sources": [
            {
                "source_type": DisclosureSourceType.SEC_13F,
                "source_name": "SEC Form 13F-HR",
                "is_primary": True,
                "data_granularity": DataGranularity.QUARTERLY,
                "reporting_delay_days": 45,
                "source_config": {
                    "cik": "0001336528",
                    "filer_name": "PERSHING SQUARE CAPITAL MANAGEMENT, L.P.",
                },
                "available_fields": ["shares", "value"],
                "known_limitations": [
                    "No exact trade dates",
                    "No execution prices",
                ],
            },
            {
                "source_type": DisclosureSourceType.SEC_13D_G,
                "source_name": "SEC Form 13D/13G",
                "is_primary": False,
                "data_granularity": DataGranularity.IRREGULAR,
                "reporting_delay_days": 10,
                "available_fields": ["stake_percentage", "intent"],
                "known_limitations": ["Only for >5% stakes"],
            },
        ],
        "strategy_notes": [
            {
                "snippet_id": "PS-001",
                "text": "We invest in a small number of large-cap, investment-grade companies.",
                "source_title": "Pershing Square Investment Approach",
                "source_url": "https://pershingsquareholdings.com",
                "topic": "concentration",
            },
        ],
    },
]


async def seed_investors():
    """Seed the database with diverse investor examples."""
    async with AsyncSessionLocal() as session:
        for investor_data in INVESTORS:
            # Check if investor exists
            result = await session.execute(
                select(Investor).where(Investor.slug == investor_data["slug"])
            )
            existing = result.scalar_one_or_none()
            
            if existing:
                print(f"Skipping existing investor: {investor_data['name']}")
                continue
            
            # Create investor
            investor = Investor(
                name=investor_data["name"],
                slug=investor_data["slug"],
                short_name=investor_data.get("short_name"),
                description=investor_data.get("description"),
                investor_type=investor_data["investor_type"],
                expected_update_frequency=investor_data.get("expected_update_frequency", DataGranularity.QUARTERLY),
                typical_reporting_delay_days=investor_data.get("typical_reporting_delay_days", 0),
                # Transparency fields
                source_reliability=investor_data.get("source_reliability", SourceReliabilityLevel.OFFICIAL_REGULATORY),
                data_granularity_level=investor_data.get("data_granularity_level", DataGranularityLevel.POSITION_LEVEL),
                aum_billions=investor_data.get("aum_billions"),
                website_url=investor_data.get("website_url"),
                is_featured=investor_data.get("is_featured", False),
                supported_features=investor_data.get("supported_features", [
                    SupportedFeature.HOLDINGS_DIFF.value,
                    SupportedFeature.AI_SUMMARY.value,
                ]),
                supported_alert_frequencies=investor_data.get("supported_alert_frequencies", [
                    AlertFrequency.WEEKLY_DIGEST.value,
                    AlertFrequency.ON_DISCLOSURE.value,
                ]),
            )
            
            # Compute transparency score
            update_investor_transparency(investor)
            session.add(investor)
            await session.flush()  # Get the ID
            
            # Create disclosure sources
            for source_data in investor_data.get("disclosure_sources", []):
                source = DisclosureSource(
                    investor_id=investor.id,
                    source_type=source_data["source_type"],
                    source_name=source_data["source_name"],
                    is_primary=source_data.get("is_primary", False),
                    data_granularity=source_data.get("data_granularity", DataGranularity.QUARTERLY),
                    reporting_delay_days=source_data.get("reporting_delay_days", 0),
                    source_config=source_data.get("source_config", {}),
                    available_fields=source_data.get("available_fields", []),
                    known_limitations=source_data.get("known_limitations", []),
                )
                session.add(source)
            
            # Create strategy notes
            for note_data in investor_data.get("strategy_notes", []):
                note = StrategyNote(
                    investor_id=investor.id,
                    snippet_id=note_data["snippet_id"],
                    text=note_data["text"],
                    source_title=note_data.get("source_title"),
                    source_url=note_data.get("source_url"),
                    topic=note_data.get("topic"),
                )
                session.add(note)
            
            print(f"Created investor: {investor.name} ({investor.investor_type.value})")
        
        await session.commit()


async def seed_holdings():
    """Create sample holdings for featured investors with changes and AI reports."""
    from datetime import datetime
    from decimal import Decimal as D
    
    async with AsyncSessionLocal() as session:
        # Get or create seed user for AI reports
        result = await session.execute(select(User).where(User.email == "seed@whytheybuy.dev"))
        user = result.scalars().first()
        
        if not user:
            from app.services.auth import hash_password
            user = User(
                email="seed@whytheybuy.dev",
                hashed_password=hash_password("seed123"),
                name="Seed Data Generator",
                is_active=True,
                is_email_verified=True,
            )
            session.add(user)
            await session.flush()
        
        # Sample holdings data with sector info, price ranges, and previous state for computing changes
        # Price ranges represent estimated trading ranges during the reporting period
        holdings_map = {
            "berkshire-hathaway": {
                "date": datetime.utcnow().date(),
                "total_value": D("900000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "BAC", "company_name": "Bank of America", "sector": "Financials", "shares": 1023191881, "market_value": 45200000000, "weight_percent": 5.02, "price_low": 42.50, "price_high": 46.80},
                    {"ticker": "AXP", "company_name": "American Express", "sector": "Financials", "shares": 151610700, "market_value": 29850000000, "weight_percent": 3.31, "price_low": 192.30, "price_high": 205.60},
                    {"ticker": "KO", "company_name": "Coca-Cola", "sector": "Consumer Discretionary", "shares": 400000000, "market_value": 26000000000, "weight_percent": 2.89, "price_low": 62.10, "price_high": 67.40},
                    {"ticker": "TSLA", "company_name": "Tesla", "sector": "Technology", "shares": 100000000, "market_value": 30000000000, "weight_percent": 3.33, "price_low": 275.80, "price_high": 325.40},
                    {"ticker": "OXY", "company_name": "Occidental Petroleum", "sector": "Energy", "shares": 200000000, "market_value": 18000000000, "weight_percent": 2.00, "price_low": 85.20, "price_high": 94.60},
                ],
                "prev_records": [
                    {"ticker": "BAC", "company_name": "Bank of America", "sector": "Financials", "shares": 1000000000, "market_value": 44000000000, "weight_percent": 5.0},
                    {"ticker": "AXP", "company_name": "American Express", "sector": "Financials", "shares": 150000000, "market_value": 29000000000, "weight_percent": 3.3},
                    {"ticker": "KO", "company_name": "Coca-Cola", "sector": "Consumer Discretionary", "shares": 400000000, "market_value": 26000000000, "weight_percent": 2.95},
                ],
            },
            "ark-arkk": {
                "date": datetime.utcnow().date(),
                "total_value": D("8000000000"),
                "source": "ARK_DAILY",
                "records": [
                    {"ticker": "TSLA", "company_name": "Tesla Inc.", "sector": "Technology", "shares": 15000000, "market_value": 4500000000, "weight_percent": 56.25, "price_low": 285.50, "price_high": 312.80},
                    {"ticker": "COIN", "company_name": "Coinbase Global", "sector": "Financials", "shares": 8000000, "market_value": 1600000000, "weight_percent": 20.00, "price_low": 192.40, "price_high": 215.60},
                    {"ticker": "CRISPR", "company_name": "CRISPR Therapeutics", "sector": "Healthcare", "shares": 4000000, "market_value": 1200000000, "weight_percent": 15.00, "price_low": 285.20, "price_high": 315.80},
                    {"ticker": "ROKU", "company_name": "Roku Inc.", "sector": "Technology", "shares": 5000000, "market_value": 700000000, "weight_percent": 8.75, "price_low": 132.50, "price_high": 148.90},
                ],
                "prev_records": [
                    {"ticker": "TSLA", "company_name": "Tesla Inc.", "sector": "Technology", "shares": 14000000, "market_value": 4200000000, "weight_percent": 58.33},
                    {"ticker": "COIN", "company_name": "Coinbase Global", "sector": "Financials", "shares": 8000000, "market_value": 1600000000, "weight_percent": 22.22},
                ],
            },
            "pershing-square": {
                "date": datetime.utcnow().date(),
                "total_value": D("16000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "PSH", "company_name": "Pershing Square Holdings", "sector": "Financials", "shares": 100000000, "market_value": 8000000000, "weight_percent": 50.00, "price_low": 78.50, "price_high": 82.30},
                    {"ticker": "UMG", "company_name": "Universal Music Group", "sector": "Consumer Discretionary", "shares": 50000000, "market_value": 4000000000, "weight_percent": 25.00, "price_low": 76.80, "price_high": 84.20},
                    {"ticker": "GOOGL", "company_name": "Alphabet Inc.", "sector": "Technology", "shares": 5000000, "market_value": 4000000000, "weight_percent": 25.00, "price_low": 175.40, "price_high": 192.80},
                ],
                "prev_records": [],
            },
            "ark-arkg": {
                "date": datetime.utcnow().date(),
                "total_value": D("2000000000"),
                "source": "ARK_DAILY",
                "records": [
                    {"ticker": "CRSP", "company_name": "CRISPR Therapeutics", "sector": "Healthcare", "shares": 3500000, "market_value": 350000000, "weight_percent": 17.50, "price_low": 95.20, "price_high": 108.50},
                    {"ticker": "EXAS", "company_name": "Exact Sciences", "sector": "Healthcare", "shares": 4200000, "market_value": 280000000, "weight_percent": 14.00, "price_low": 62.30, "price_high": 71.80},
                    {"ticker": "TDOC", "company_name": "Teladoc Health", "sector": "Healthcare", "shares": 8500000, "market_value": 170000000, "weight_percent": 8.50, "price_low": 18.50, "price_high": 22.40},
                    {"ticker": "BEAM", "company_name": "Beam Therapeutics", "sector": "Healthcare", "shares": 5000000, "market_value": 150000000, "weight_percent": 7.50, "price_low": 28.20, "price_high": 32.60},
                    {"ticker": "NTLA", "company_name": "Intellia Therapeutics", "sector": "Healthcare", "shares": 4000000, "market_value": 120000000, "weight_percent": 6.00, "price_low": 28.50, "price_high": 33.20},
                ],
                "prev_records": [
                    {"ticker": "CRSP", "company_name": "CRISPR Therapeutics", "sector": "Healthcare", "shares": 3200000, "market_value": 320000000, "weight_percent": 16.00},
                    {"ticker": "EXAS", "company_name": "Exact Sciences", "sector": "Healthcare", "shares": 4500000, "market_value": 300000000, "weight_percent": 15.00},
                    {"ticker": "TDOC", "company_name": "Teladoc Health", "sector": "Healthcare", "shares": 9000000, "market_value": 180000000, "weight_percent": 9.00},
                ],
            },
            "bridgewater-associates": {
                "date": datetime.utcnow().date(),
                "total_value": D("150000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "SPY", "company_name": "SPDR S&P 500 ETF", "sector": "ETF", "shares": 25000000, "market_value": 12500000000, "weight_percent": 8.33, "price_low": 485.20, "price_high": 512.80},
                    {"ticker": "IVV", "company_name": "iShares Core S&P 500", "sector": "ETF", "shares": 20000000, "market_value": 10000000000, "weight_percent": 6.67, "price_low": 488.50, "price_high": 515.40},
                    {"ticker": "VWO", "company_name": "Vanguard Emerging Markets", "sector": "ETF", "shares": 80000000, "market_value": 3200000000, "weight_percent": 2.13, "price_low": 38.20, "price_high": 42.60},
                    {"ticker": "PG", "company_name": "Procter & Gamble", "sector": "Consumer Staples", "shares": 15000000, "market_value": 2400000000, "weight_percent": 1.60, "price_low": 155.20, "price_high": 168.80},
                    {"ticker": "JNJ", "company_name": "Johnson & Johnson", "sector": "Healthcare", "shares": 12000000, "market_value": 1800000000, "weight_percent": 1.20, "price_low": 145.60, "price_high": 158.40},
                ],
                "prev_records": [
                    {"ticker": "SPY", "company_name": "SPDR S&P 500 ETF", "sector": "ETF", "shares": 22000000, "market_value": 11000000000, "weight_percent": 7.50},
                    {"ticker": "IVV", "company_name": "iShares Core S&P 500", "sector": "ETF", "shares": 18000000, "market_value": 9000000000, "weight_percent": 6.00},
                ],
            },
            "soros-fund-management": {
                "date": datetime.utcnow().date(),
                "total_value": D("7000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "RIVN", "company_name": "Rivian Automotive", "sector": "Consumer Discretionary", "shares": 15000000, "market_value": 225000000, "weight_percent": 3.21, "price_low": 13.20, "price_high": 16.80},
                    {"ticker": "MSFT", "company_name": "Microsoft", "sector": "Technology", "shares": 500000, "market_value": 200000000, "weight_percent": 2.86, "price_low": 385.20, "price_high": 418.60},
                    {"ticker": "AMZN", "company_name": "Amazon", "sector": "Technology", "shares": 1000000, "market_value": 185000000, "weight_percent": 2.64, "price_low": 178.50, "price_high": 195.40},
                    {"ticker": "META", "company_name": "Meta Platforms", "sector": "Technology", "shares": 350000, "market_value": 175000000, "weight_percent": 2.50, "price_low": 480.20, "price_high": 525.60},
                ],
                "prev_records": [
                    {"ticker": "MSFT", "company_name": "Microsoft", "sector": "Technology", "shares": 600000, "market_value": 240000000, "weight_percent": 3.43},
                    {"ticker": "AMZN", "company_name": "Amazon", "sector": "Technology", "shares": 800000, "market_value": 148000000, "weight_percent": 2.11},
                ],
            },
            "renaissance-technologies": {
                "date": datetime.utcnow().date(),
                "total_value": D("80000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "NVDA", "company_name": "NVIDIA", "sector": "Technology", "shares": 2000000, "market_value": 1800000000, "weight_percent": 2.25, "price_low": 850.20, "price_high": 950.80},
                    {"ticker": "AAPL", "company_name": "Apple Inc.", "sector": "Technology", "shares": 8000000, "market_value": 1600000000, "weight_percent": 2.00, "price_low": 192.50, "price_high": 208.40},
                    {"ticker": "GOOGL", "company_name": "Alphabet", "sector": "Technology", "shares": 8500000, "market_value": 1500000000, "weight_percent": 1.88, "price_low": 168.20, "price_high": 185.60},
                    {"ticker": "TSLA", "company_name": "Tesla", "sector": "Technology", "shares": 4000000, "market_value": 1200000000, "weight_percent": 1.50, "price_low": 285.40, "price_high": 318.20},
                    {"ticker": "AMD", "company_name": "AMD", "sector": "Technology", "shares": 6000000, "market_value": 900000000, "weight_percent": 1.13, "price_low": 142.30, "price_high": 162.80},
                ],
                "prev_records": [
                    {"ticker": "NVDA", "company_name": "NVIDIA", "sector": "Technology", "shares": 1500000, "market_value": 1350000000, "weight_percent": 1.70},
                    {"ticker": "AAPL", "company_name": "Apple Inc.", "sector": "Technology", "shares": 9000000, "market_value": 1800000000, "weight_percent": 2.25},
                    {"ticker": "GOOGL", "company_name": "Alphabet", "sector": "Technology", "shares": 7000000, "market_value": 1225000000, "weight_percent": 1.53},
                ],
            },
            "duquesne-family-office": {
                "date": datetime.utcnow().date(),
                "total_value": D("3000000000"),
                "source": "SEC_13F",
                "records": [
                    {"ticker": "NVDA", "company_name": "NVIDIA", "sector": "Technology", "shares": 500000, "market_value": 450000000, "weight_percent": 15.00, "price_low": 850.20, "price_high": 950.80},
                    {"ticker": "MSFT", "company_name": "Microsoft", "sector": "Technology", "shares": 800000, "market_value": 320000000, "weight_percent": 10.67, "price_low": 385.20, "price_high": 418.60},
                    {"ticker": "AVGO", "company_name": "Broadcom", "sector": "Technology", "shares": 200000, "market_value": 280000000, "weight_percent": 9.33, "price_low": 1320.50, "price_high": 1485.20},
                    {"ticker": "LLY", "company_name": "Eli Lilly", "sector": "Healthcare", "shares": 300000, "market_value": 240000000, "weight_percent": 8.00, "price_low": 765.30, "price_high": 845.60},
                ],
                "prev_records": [
                    {"ticker": "NVDA", "company_name": "NVIDIA", "sector": "Technology", "shares": 400000, "market_value": 360000000, "weight_percent": 12.00},
                    {"ticker": "MSFT", "company_name": "Microsoft", "sector": "Technology", "shares": 900000, "market_value": 360000000, "weight_percent": 12.00},
                ],
            },
        }
        
        for slug, holdings_data in holdings_map.items():
            # Get investor
            result = await session.execute(
                select(Investor).where(Investor.slug == slug)
            )
            investor = result.scalar_one_or_none()
            
            if not investor:
                continue
            
            # Check if holdings already exist
            result = await session.execute(
                select(HoldingsSnapshot).where(HoldingsSnapshot.investor_id == investor.id)
            )
            if result.scalar_one_or_none():
                print(f"Skipping existing holdings for: {investor.name}")
                continue
            
            # Create snapshot
            snapshot = HoldingsSnapshot(
                investor_id=investor.id,
                snapshot_date=holdings_data["date"],
                source=holdings_data["source"],
                total_positions=len(holdings_data["records"]),
                total_value=holdings_data["total_value"],
            )
            session.add(snapshot)
            await session.flush()
            
            # Add holding records with sector info
            for rec_data in holdings_data["records"]:
                record = HoldingRecord(
                    snapshot_id=snapshot.id,
                    ticker=rec_data["ticker"],
                    company_name=rec_data["company_name"],
                    sector=rec_data.get("sector"),
                    shares=rec_data.get("shares"),
                    market_value=rec_data.get("market_value"),
                    weight_percent=rec_data.get("weight_percent"),
                )
                session.add(record)
            
            await session.flush()
            
            # Create holdings changes (comparing prev to current)
            prev_records_map = {r["ticker"]: r for r in holdings_data.get("prev_records", [])}
            current_records_map = {r["ticker"]: r for r in holdings_data["records"]}
            
            for ticker, curr_record in current_records_map.items():
                prev_record = prev_records_map.get(ticker)

                # Get price range if available
                price_low = curr_record.get("price_low")
                price_high = curr_record.get("price_high")

                if prev_record:
                    # Position size changed
                    shares_delta = int(curr_record["shares"]) - int(prev_record["shares"])
                    value_delta = float(curr_record["market_value"]) - float(prev_record["market_value"])
                    weight_delta = float(curr_record["weight_percent"]) - float(prev_record["weight_percent"])

                    if shares_delta > 0:
                        change_type = ChangeType.ADDED
                    elif shares_delta < 0:
                        change_type = ChangeType.REDUCED
                    else:
                        change_type = ChangeType.ADDED  # Default to ADDED if unclear

                    change = HoldingsChange(
                        investor_id=investor.id,
                        ticker=ticker,
                        company_name=curr_record["company_name"],
                        change_type=change_type,
                        from_date=holdings_data["date"] - timedelta(days=30),
                        to_date=holdings_data["date"],
                        shares_before=prev_record["shares"],
                        shares_after=curr_record["shares"],
                        shares_delta=shares_delta,
                        weight_before=prev_record["weight_percent"],
                        weight_after=curr_record["weight_percent"],
                        weight_delta=weight_delta,
                        value_before=prev_record["market_value"],
                        value_after=curr_record["market_value"],
                        value_delta=value_delta,
                        price_range_low=price_low,
                        price_range_high=price_high,
                    )
                    session.add(change)
                else:
                    # New position - shares_delta = total shares acquired
                    change = HoldingsChange(
                        investor_id=investor.id,
                        ticker=ticker,
                        company_name=curr_record["company_name"],
                        change_type=ChangeType.NEW,
                        from_date=holdings_data["date"] - timedelta(days=30),
                        to_date=holdings_data["date"],
                        shares_before=0,
                        shares_after=curr_record["shares"],
                        shares_delta=curr_record["shares"],  # Total shares for NEW positions
                        weight_after=curr_record["weight_percent"],
                        value_after=curr_record["market_value"],
                        price_range_low=price_low,
                        price_range_high=price_high,
                    )
                    session.add(change)
            
            await session.flush()
            
            # Create AI Company Reports for top changes/holdings with evidence-based reasoning
            top_holdings = sorted(
                holdings_data.get("records", []),
                key=lambda x: float(x.get("market_value", 0)),
                reverse=True
            )[:3]
            
            for rec in top_holdings:
                sector = rec.get("sector", "Unknown")
                weight_pct = float(rec.get("weight_percent", 0))
                
                # Determine position status based on weight
                if weight_pct > 5:
                    position_status = "core_holding"
                    position_desc = "significant core holding"
                elif weight_pct > 2:
                    position_status = "significant_position"
                    position_desc = "meaningful allocation"
                else:
                    position_status = "emerging"
                    position_desc = "emerging position"
                
                # Get change information if available
                position_change = None
                for change in [c for c in holdings_data.get("prev_records", []) if c["ticker"] == rec["ticker"]]:
                    position_change = change
                
                # Build evidence-based pillars
                reasoning_pillars = []
                
                # Pillar 1: Capital Allocation
                reasoning_pillars.append({
                    "name": "Capital Allocation Strategy",
                    "description": f"How {investor.name} weights this position in portfolio",
                    "evidence_signals": [{
                        "type": "position_size",
                        "source": "Holdings Data",
                        "observation": f"{rec['ticker']}: {weight_pct:.2f}% of {investor.name}'s portfolio"
                    }],
                    "confidence": "high",
                    "key_observation": f"This is a {position_desc} in {investor.name}'s disclosed holdings"
                })
                
                # Pillar 2: Position Changes (if applicable)
                if position_change:
                    shares_change = float(rec.get("shares", 0)) - float(position_change.get("shares", 0))
                    if shares_change != 0:
                        direction = "increased" if shares_change > 0 else "decreased"
                        reasoning_pillars.append({
                            "name": "Position Activity",
                            "description": "Recent changes to position size",
                            "evidence_signals": [{
                                "type": "holdings_change",
                                "source": f"Holdings comparison {position_change.get('snapshot_date', 'recent')} to {holdings_data['date'].isoformat()}",
                                "observation": f"{rec['ticker']} position {direction} by {abs(shares_change):,.0f} shares"
                            }],
                            "confidence": "high",
                            "key_observation": f"{investor.name} is actively {'building' if shares_change > 0 else 'reducing'} its {rec['ticker']} position"
                        })
                
                # Pillar 3: Sector Context
                reasoning_pillars.append({
                    "name": "Sector Positioning",
                    "description": f"Exposure to {sector} sector",
                    "evidence_signals": [{
                        "type": "sector_concentration",
                        "source": "Portfolio Composition",
                        "observation": f"{sector} sector position in {investor.name}'s portfolio"
                    }],
                    "confidence": "medium",
                    "key_observation": f"{rec['ticker']} is {investor.name}'s primary {sector} sector exposure in disclosed holdings"
                })
                
                ai_report = AICompanyReport(
                    user_id=user.id,
                    investor_id=investor.id,
                    ticker=rec["ticker"],
                    json_payload={
                        # Core position info
                        "company": rec["company_name"],
                        "sector": sector,
                        "current_weight": weight_pct,
                        "position_status": position_status,
                        "holding_date": holdings_data["date"].isoformat(),
                        
                        # Evidence-based reasoning (focused, not boilerplate)
                        "reasoning_pillars": reasoning_pillars,
                        
                        # Risk factors specific to this position
                        "risk_factors": [
                            f"Concentration risk if {sector} sector declines sharply",
                            "Liquidity changes in individual position",
                            "Changes in investor's rebalancing strategy",
                        ],
                        
                        # Evidence panel - what we know and don't know
                        "evidence": {
                            "disclosure_type": investor.investor_type.value if hasattr(investor.investor_type, 'value') else str(investor.investor_type),
                            "disclosure_frequency": "quarterly" if investor.investor_type == InvestorType.HEDGE_FUND else "periodic",
                            "data_availability": {
                                "position_data": "current",
                                "execution_details": "not_available",
                                "trading_rationale": "not_available",
                                "investor_conviction": "inferred",
                            },
                            "what_we_dont_know": [
                                "Exact execution prices and dates",
                                "Private reasoning behind position decisions",
                                "Time horizon (short-term vs long-term)",
                                "Whether position is core or tactical",
                                "Investor's current views (disclosure is historical)",
                            ]
                        },
                        
                        # Confidence and compliance
                        "confidence": "medium",
                        "confidence_basis": "Holdings data only; reasoning is inferred",
                        "key_insight": f"{investor.name} holds {rec['ticker']} as {position_desc} ({weight_pct:.2f}% weight), indicating this {sector} name meets their investment criteria",
                        
                        # Strict compliance disclaimers
                        "disclaimers": [
                            "Analysis based only on disclosed holdings data",
                            "Does not constitute investment advice",
                            "Reasoning about investor intent is speculative",
                            "Historical data; investor views may have changed",
                            "Use for research purposes only",
                        ]
                    }
                )
                session.add(ai_report)

            await session.flush()

            # Update investor's last_data_fetch and last_change_detected
            investor.last_data_fetch = datetime.utcnow()
            investor.last_change_detected = datetime.utcnow()
            session.add(investor)
            await session.flush()

            print(f"Created {len(holdings_data['records'])} holdings + {len(current_records_map)} changes + {min(3, len(top_holdings))} evidence-based AI reports for: {investor.name}")
        
        await session.commit()
        print("\n✅ Holdings seed data with evidence-based reasoning complete!")


async def main():
    """Main entry point."""
    print("🌱 Seeding WhyTheyBuy database with diverse investor examples...\n")
    await seed_investors()
    print("\n📊 Creating sample holdings data...\n")
    await seed_holdings()


if __name__ == "__main__":
    asyncio.run(main())
