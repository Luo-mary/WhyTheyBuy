"""
Setup script that fetches REAL holdings data for ALL investors.

This script:
1. Creates investors (metadata only)
2. Fetches real ARK ETF holdings from their public CSV files
3. Fetches real 13F filings from SEC EDGAR for institutional investors
4. Does NOT create any fake/sample data

Usage:
    python -m scripts.setup_real_data
"""
import asyncio
import sys
from pathlib import Path
from datetime import date, datetime, timedelta
from decimal import Decimal
import csv
import io
import re
import xml.etree.ElementTree as ET

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import AsyncSessionLocal
from app.models.investor import (
    Investor,
    DisclosureSource,
    DisclosureSourceType,
    InvestorType,
    DataGranularity,
    StrategyNote,
    SourceReliabilityLevel,
    DataGranularityLevel,
    SupportedFeature,
    AlertFrequency,
    update_investor_transparency,
)
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange, ChangeType, SnapshotSource


# =============================================================================
# ARK ETF CONFIGURATIONS
# =============================================================================

ARK_FUNDS = {
    "ARKK": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_INNOVATION_ETF_ARKK_HOLDINGS.csv",
    "ARKW": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_NEXT_GENERATION_INTERNET_ETF_ARKW_HOLDINGS.csv",
    "ARKG": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_GENOMIC_REVOLUTION_ETF_ARKG_HOLDINGS.csv",
    "ARKF": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_FINTECH_INNOVATION_ETF_ARKF_HOLDINGS.csv",
    "ARKQ": "https://assets.ark-funds.com/fund-documents/funds-etf-csv/ARK_AUTONOMOUS_TECH._&_ROBOTICS_ETF_ARKQ_HOLDINGS.csv",
}

ARK_INVESTORS = [
    {
        "name": "ARK Innovation ETF (ARKK)",
        "slug": "ark-arkk",
        "short_name": "ARKK",
        "description": "ARK Innovation ETF focuses on disruptive innovation across multiple sectors including AI, robotics, and genomics.",
        "investor_type": InvestorType.ETF_MANAGER,
        "aum_billions": "~$8B",
        "headquarters": "New York, NY",
        "website_url": "https://ark-funds.com/arkk",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.DAILY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "ARK Next Generation Internet ETF (ARKW)",
        "slug": "ark-arkw",
        "short_name": "ARKW",
        "description": "ARK Next Generation Internet ETF focuses on companies benefiting from shifting technology infrastructure.",
        "investor_type": InvestorType.ETF_MANAGER,
        "aum_billions": "~$1.5B",
        "headquarters": "New York, NY",
        "website_url": "https://ark-funds.com/arkw",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.DAILY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "ARK Genomic Revolution ETF (ARKG)",
        "slug": "ark-arkg",
        "short_name": "ARKG",
        "description": "ARK Genomic Revolution ETF focuses on companies in genomics and healthcare innovation.",
        "investor_type": InvestorType.ETF_MANAGER,
        "aum_billions": "~$2B",
        "headquarters": "New York, NY",
        "website_url": "https://ark-funds.com/arkg",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.DAILY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "ARK Fintech Innovation ETF (ARKF)",
        "slug": "ark-arkf",
        "short_name": "ARKF",
        "description": "ARK Fintech Innovation ETF focuses on financial technology innovation.",
        "investor_type": InvestorType.ETF_MANAGER,
        "aum_billions": "~$1B",
        "headquarters": "New York, NY",
        "website_url": "https://ark-funds.com/arkf",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.DAILY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "ARK Autonomous Tech & Robotics ETF (ARKQ)",
        "slug": "ark-arkq",
        "short_name": "ARKQ",
        "description": "ARK Autonomous Technology & Robotics ETF focuses on autonomous vehicles and robotics.",
        "investor_type": InvestorType.ETF_MANAGER,
        "aum_billions": "~$1.2B",
        "headquarters": "New York, NY",
        "website_url": "https://ark-funds.com/arkq",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.DAILY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_VOLUNTARY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
]


# =============================================================================
# 13F FILER CONFIGURATIONS (SEC EDGAR)
# =============================================================================

SEC_13F_FILERS = [
    {
        "name": "Berkshire Hathaway Inc.",
        "slug": "berkshire-hathaway",
        "short_name": "Berkshire",
        "description": "Berkshire Hathaway is a multinational conglomerate led by Warren Buffett, known for its long-term value investing approach.",
        "investor_type": InvestorType.INDIVIDUAL_INVESTOR,
        "cik": "0001067983",
        "aum_billions": "~$350B",
        "website_url": "https://berkshirehathaway.com",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
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
        "description": "Bridgewater Associates is one of the world's largest hedge funds, known for its systematic, global macro investment approach.",
        "investor_type": InvestorType.HEDGE_FUND,
        "cik": "0001350694",
        "aum_billions": "~$150B",
        "website_url": "https://bridgewater.com",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
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
        "description": "Renaissance Technologies is a quantitative hedge fund known for its Medallion Fund and systematic trading strategies.",
        "investor_type": InvestorType.HEDGE_FUND,
        "cik": "0001037389",
        "aum_billions": "~$100B",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "Soros Fund Management",
        "slug": "soros-fund-management",
        "short_name": "Soros",
        "description": "Soros Fund Management is a family office managing George Soros's personal fortune, known for macro and event-driven strategies.",
        "investor_type": InvestorType.FAMILY_OFFICE,
        "cik": "0001029160",
        "aum_billions": "~$25B",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "Duquesne Family Office",
        "slug": "duquesne-family-office",
        "short_name": "Duquesne",
        "description": "Duquesne Family Office manages Stanley Druckenmiller's personal capital, known for macro trading and concentrated positions.",
        "investor_type": InvestorType.FAMILY_OFFICE,
        "cik": "0001536411",
        "aum_billions": "~$15B",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "Pershing Square Capital Management",
        "slug": "pershing-square",
        "short_name": "Pershing Square",
        "description": "Pershing Square is an activist hedge fund led by Bill Ackman, known for concentrated positions and public campaigns.",
        "investor_type": InvestorType.HEDGE_FUND,
        "cik": "0001336528",
        "aum_billions": "~$16B",
        "website_url": "https://pershingsquareholdings.com",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
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
    {
        "name": "Tiger Global Management",
        "slug": "tiger-global",
        "short_name": "Tiger Global",
        "description": "Tiger Global Management is a leading hedge fund and private equity firm known for technology investments globally.",
        "investor_type": InvestorType.HEDGE_FUND,
        "cik": "0001167483",
        "aum_billions": "~$50B",
        "website_url": "https://tigerglobal.com",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
    {
        "name": "Citadel Advisors",
        "slug": "citadel-advisors",
        "short_name": "Citadel",
        "description": "Citadel is one of the world's largest alternative investment managers, founded by Ken Griffin.",
        "investor_type": InvestorType.HEDGE_FUND,
        "cik": "0001423053",
        "aum_billions": "~$60B",
        "website_url": "https://citadel.com",
        "is_featured": True,
        "expected_update_frequency": DataGranularity.QUARTERLY,
        "source_reliability": SourceReliabilityLevel.OFFICIAL_REGULATORY,
        "data_granularity_level": DataGranularityLevel.POSITION_LEVEL,
    },
]


# =============================================================================
# SEC EDGAR API HELPERS
# =============================================================================

SEC_HEADERS = {
    "User-Agent": "WhyTheyBuy Research App contact@whytheybuy.com",
    "Accept-Encoding": "gzip, deflate",
}


async def fetch_latest_13f_filing(client: httpx.AsyncClient, cik: str) -> dict | None:
    """Fetch the latest 13F-HR filing for a given CIK from SEC EDGAR."""
    # Normalize CIK (remove leading zeros for API, keep for URL)
    cik_normalized = cik.lstrip("0")
    cik_padded = cik.zfill(10)

    # Get list of filings
    submissions_url = f"https://data.sec.gov/submissions/CIK{cik_padded}.json"

    try:
        response = await client.get(submissions_url, timeout=30.0)
        response.raise_for_status()
        data = response.json()

        # Find latest 13F-HR filing
        filings = data.get("filings", {}).get("recent", {})
        forms = filings.get("form", [])
        accession_numbers = filings.get("accessionNumber", [])
        filing_dates = filings.get("filingDate", [])
        primary_docs = filings.get("primaryDocument", [])

        for i, form in enumerate(forms):
            if form == "13F-HR":
                return {
                    "accession_number": accession_numbers[i],
                    "filing_date": filing_dates[i],
                    "primary_doc": primary_docs[i],
                    "cik": cik_padded,
                }

        return None

    except Exception as e:
        print(f"    Error fetching filings for CIK {cik}: {e}")
        return None


async def fetch_13f_holdings(client: httpx.AsyncClient, filing_info: dict) -> list[dict]:
    """Fetch and parse holdings from a 13F-HR filing."""
    cik = filing_info["cik"]
    accession = filing_info["accession_number"].replace("-", "")

    # Try to find the infotable XML file
    filing_url = f"https://www.sec.gov/Archives/edgar/data/{cik.lstrip('0')}/{accession}"

    try:
        # Get the filing index to find the infotable
        index_url = f"{filing_url}/index.json"
        response = await client.get(index_url, timeout=30.0)
        response.raise_for_status()
        index_data = response.json()

        # Find the infotable XML file
        infotable_file = None
        xml_files = []

        for item in index_data.get("directory", {}).get("item", []):
            name = item.get("name", "").lower()
            if name.endswith(".xml"):
                xml_files.append(item.get("name"))
                # Priority 1: explicit infotable in name
                if "infotable" in name:
                    infotable_file = item.get("name")
                    break

        if not infotable_file:
            # Priority 2: 13f in name
            for item in index_data.get("directory", {}).get("item", []):
                name = item.get("name", "").lower()
                if name.endswith(".xml") and "13f" in name:
                    infotable_file = item.get("name")
                    break

        if not infotable_file:
            # Priority 3: Try all XML files except primary_doc.xml
            for xml_name in xml_files:
                if "primary" not in xml_name.lower() and "index" not in xml_name.lower():
                    infotable_file = xml_name
                    break

        if not infotable_file:
            print(f"    Could not find infotable XML in filing")
            return []

        # Fetch the infotable XML
        xml_url = f"{filing_url}/{infotable_file}"
        response = await client.get(xml_url, timeout=60.0)
        response.raise_for_status()
        xml_content = response.text

        # Parse XML
        return parse_13f_xml(xml_content)

    except Exception as e:
        print(f"    Error fetching 13F holdings: {e}")
        return []


def parse_13f_xml(xml_content: str) -> list[dict]:
    """Parse 13F infotable XML to extract holdings."""
    holdings = []

    try:
        # More robust namespace removal
        # Remove all namespace declarations
        xml_content = re.sub(r'\sxmlns[^=]*="[^"]*"', '', xml_content)
        # Remove all namespace prefixes from tags (handles ns1:, n1:, etc.)
        xml_content = re.sub(r'<([a-zA-Z0-9]+):', '<', xml_content)
        xml_content = re.sub(r'</([a-zA-Z0-9]+):', '</', xml_content)
        # Remove any remaining colon-prefixed attributes
        xml_content = re.sub(r'\s[a-zA-Z0-9]+:[a-zA-Z0-9]+="[^"]*"', '', xml_content)

        root = ET.fromstring(xml_content)

        # Find all infoTable entries
        for info_table in root.iter():
            if "infoTable" in info_table.tag or "infotable" in info_table.tag.lower():
                holding = {}

                for child in info_table:
                    tag = child.tag.split("}")[-1].lower() if "}" in child.tag else child.tag.lower()

                    if "nameofissuer" in tag:
                        holding["company_name"] = child.text.strip() if child.text else ""
                    elif "titleofclass" in tag:
                        holding["title_of_class"] = child.text.strip() if child.text else ""
                    elif "cusip" in tag:
                        holding["cusip"] = child.text.strip() if child.text else ""
                    elif "value" in tag and "shrs" not in tag:
                        try:
                            # Value is in thousands
                            holding["market_value"] = Decimal(child.text.strip()) * 1000
                        except (ValueError, TypeError):
                            holding["market_value"] = Decimal("0")
                    elif "sshprnamt" in tag:
                        # Share amount
                        for subchild in child:
                            subtag = subchild.tag.split("}")[-1].lower() if "}" in subchild.tag else subchild.tag.lower()
                            if "sshprnamt" in subtag and subchild.text:
                                try:
                                    holding["shares"] = Decimal(subchild.text.strip())
                                except (ValueError, TypeError):
                                    pass

                if holding.get("company_name") and (holding.get("shares") or holding.get("market_value")):
                    holdings.append(holding)

    except ET.ParseError as e:
        print(f"    XML parsing error: {e}")
    except Exception as e:
        print(f"    Error parsing 13F XML: {e}")

    return holdings


# =============================================================================
# CUSIP TO TICKER LOOKUP
# =============================================================================

# Common CUSIP to ticker mappings for major holdings
CUSIP_TO_TICKER = {
    # Major tech
    "037833100": "AAPL",
    "594918104": "MSFT",
    "02079K305": "GOOGL",
    "02079K107": "GOOG",
    "30303M102": "META",
    "67066G104": "NVDA",
    "023135106": "AMZN",
    "88160R101": "TSLA",
    # Financials
    "060505104": "BAC",
    "025816109": "AXP",
    "92826C839": "V",
    "585055106": "WFC",
    "46625H100": "JPM",
    # Consumer
    "191216100": "KO",
    "742718109": "PG",
    "478160104": "JNJ",
    # Energy
    "674599105": "OXY",
    "20825C104": "COP",
    "30231G102": "XOM",
    # ETFs
    "78462F103": "SPY",
    "464287200": "IVV",
    "922908769": "VWO",
    # Other major holdings
    "17275R102": "C",
    "254687106": "DIS",
    "38141G104": "GS",
    "58933Y105": "MRK",
    "713448108": "PEP",
    "931142103": "WMT",
    "756109104": "REGN",
    "459200101": "IBM",
    "88579Y101": "MMM",
    "911312106": "UNP",
    "00206R102": "T",
    "92343V104": "VZ",
    "532457108": "LLY",
    "003654100": "ABBV",
    "29274F104": "PYPL",
    "31428X106": "FDX",
    "92532F100": "VRT",
    "126650100": "CVS",
    "48203R104": "K",
    "22160K105": "COST",
    "549271106": "LOW",
    "431571108": "HIG",
    "89677Q107": "TSM",
    "019118108": "ALLE",
    # Add more as needed
}


def cusip_to_ticker(cusip: str, company_name: str = "") -> str:
    """Convert CUSIP to ticker symbol."""
    if cusip in CUSIP_TO_TICKER:
        return CUSIP_TO_TICKER[cusip]

    # Try to infer from company name (fallback)
    name_upper = company_name.upper()
    name_mappings = {
        "APPLE": "AAPL",
        "MICROSOFT": "MSFT",
        "ALPHABET": "GOOGL",
        "AMAZON": "AMZN",
        "META PLATFORMS": "META",
        "FACEBOOK": "META",
        "NVIDIA": "NVDA",
        "TESLA": "TSLA",
        "BANK OF AMERICA": "BAC",
        "AMERICAN EXPRESS": "AXP",
        "COCA-COLA": "KO",
        "COCA COLA": "KO",
        "BERKSHIRE": "BRK.B",
        "OCCIDENTAL": "OXY",
        "CHEVRON": "CVX",
        "JPMORGAN": "JPM",
        "JP MORGAN": "JPM",
        "WELLS FARGO": "WFC",
        "JOHNSON & JOHNSON": "JNJ",
        "PROCTER & GAMBLE": "PG",
        "PROCTER AND GAMBLE": "PG",
        "VISA": "V",
        "MASTERCARD": "MA",
        "DISNEY": "DIS",
        "WALT DISNEY": "DIS",
    }

    for key, ticker in name_mappings.items():
        if key in name_upper:
            return ticker

    # Return CUSIP as placeholder if no mapping found
    return f"CUSIP:{cusip[:6]}"


# =============================================================================
# DATABASE OPERATIONS
# =============================================================================

async def create_ark_investors():
    """Create ARK investor entries in the database."""
    print("Creating ARK ETF investors...")

    async with AsyncSessionLocal() as session:
        for inv_data in ARK_INVESTORS:
            result = await session.execute(
                select(Investor).where(Investor.slug == inv_data["slug"])
            )
            existing = result.scalar_one_or_none()

            if existing:
                print(f"  Already exists: {inv_data['name']}")
                continue

            investor = Investor(
                name=inv_data["name"],
                slug=inv_data["slug"],
                short_name=inv_data["short_name"],
                description=inv_data["description"],
                investor_type=inv_data["investor_type"],
                aum_billions=inv_data.get("aum_billions"),
                website_url=inv_data.get("website_url"),
                is_active=True,
                is_featured=inv_data.get("is_featured", False),
                expected_update_frequency=inv_data.get("expected_update_frequency", DataGranularity.DAILY),
                source_reliability=inv_data.get("source_reliability", SourceReliabilityLevel.OFFICIAL_VOLUNTARY),
                data_granularity_level=inv_data.get("data_granularity_level", DataGranularityLevel.POSITION_LEVEL),
                supported_features=[
                    SupportedFeature.HOLDINGS_DIFF.value,
                    SupportedFeature.TRADE_HISTORY.value,
                    SupportedFeature.AI_SUMMARY.value,
                    SupportedFeature.AI_RATIONALE.value,
                    SupportedFeature.INSTANT_ALERTS.value,
                    SupportedFeature.WEIGHT_TRACKING.value,
                ],
                supported_alert_frequencies=[
                    AlertFrequency.INSTANT.value,
                    AlertFrequency.DAILY_DIGEST.value,
                    AlertFrequency.WEEKLY_DIGEST.value,
                ],
            )
            update_investor_transparency(investor)
            session.add(investor)
            await session.flush()

            # Add disclosure source
            source = DisclosureSource(
                investor_id=investor.id,
                source_type=DisclosureSourceType.ETF_HOLDINGS,
                source_name=f"{inv_data['short_name']} Daily Holdings",
                is_primary=True,
                data_granularity=DataGranularity.DAILY,
                reporting_delay_days=1,
                source_config={
                    "csv_url": ARK_FUNDS.get(inv_data["short_name"]),
                    "fund_ticker": inv_data["short_name"],
                },
                available_fields=["shares", "weight", "value"],
                known_limitations=["Execution prices not disclosed"],
            )
            session.add(source)

            print(f"  Created: {inv_data['name']}")

        await session.commit()

    print("ARK investors created\n")


async def create_13f_investors():
    """Create 13F filer investor entries in the database."""
    print("Creating 13F filer investors...")

    async with AsyncSessionLocal() as session:
        for inv_data in SEC_13F_FILERS:
            result = await session.execute(
                select(Investor).where(Investor.slug == inv_data["slug"])
            )
            existing = result.scalar_one_or_none()

            if existing:
                print(f"  Already exists: {inv_data['name']}")
                continue

            investor = Investor(
                name=inv_data["name"],
                slug=inv_data["slug"],
                short_name=inv_data["short_name"],
                description=inv_data["description"],
                investor_type=inv_data["investor_type"],
                aum_billions=inv_data.get("aum_billions"),
                website_url=inv_data.get("website_url"),
                is_active=True,
                is_featured=inv_data.get("is_featured", False),
                expected_update_frequency=inv_data.get("expected_update_frequency", DataGranularity.QUARTERLY),
                typical_reporting_delay_days=45,
                source_reliability=inv_data.get("source_reliability", SourceReliabilityLevel.OFFICIAL_REGULATORY),
                data_granularity_level=inv_data.get("data_granularity_level", DataGranularityLevel.POSITION_LEVEL),
                supported_features=[
                    SupportedFeature.HOLDINGS_DIFF.value,
                    SupportedFeature.AI_SUMMARY.value,
                    SupportedFeature.AI_RATIONALE.value,
                    SupportedFeature.VALUE_TRACKING.value,
                ],
                supported_alert_frequencies=[
                    AlertFrequency.WEEKLY_DIGEST.value,
                    AlertFrequency.ON_DISCLOSURE.value,
                ],
            )
            update_investor_transparency(investor)
            session.add(investor)
            await session.flush()

            # Add disclosure source
            source = DisclosureSource(
                investor_id=investor.id,
                source_type=DisclosureSourceType.SEC_13F,
                source_name="SEC Form 13F-HR",
                is_primary=True,
                data_granularity=DataGranularity.QUARTERLY,
                reporting_delay_days=45,
                source_config={
                    "cik": inv_data["cik"],
                    "filer_name": inv_data["name"].upper(),
                },
                available_fields=["shares", "value"],
                known_limitations=[
                    "No exact trade dates",
                    "No execution prices",
                    "45-day reporting delay",
                    "Quarter-end snapshot only",
                ],
            )
            session.add(source)

            # Add strategy notes if provided
            for note_data in inv_data.get("strategy_notes", []):
                note = StrategyNote(
                    investor_id=investor.id,
                    snippet_id=note_data["snippet_id"],
                    text=note_data["text"],
                    source_title=note_data.get("source_title"),
                    source_url=note_data.get("source_url"),
                    topic=note_data.get("topic"),
                )
                session.add(note)

            print(f"  Created: {inv_data['name']}")

        await session.commit()

    print("13F filer investors created\n")


async def fetch_real_ark_holdings():
    """Fetch REAL holdings data from ARK's public CSV files."""
    print("Fetching real ARK holdings data...")

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; WhyTheyBuy/1.0)",
    }

    async with AsyncSessionLocal() as session:
        for fund_code, url in ARK_FUNDS.items():
            print(f"\n  Fetching {fund_code}...")

            result = await session.execute(
                select(Investor).where(Investor.short_name == fund_code)
            )
            investor = result.scalar_one_or_none()

            if not investor:
                print(f"    Investor not found for {fund_code}, skipping")
                continue

            try:
                async with httpx.AsyncClient(follow_redirects=True, headers=headers) as client:
                    response = await client.get(url, timeout=60.0)
                    response.raise_for_status()
                    csv_content = response.text

                reader = csv.DictReader(io.StringIO(csv_content))
                holdings = []
                snapshot_date = None
                total_value = Decimal("0")

                def _col(row, *candidates, default=""):
                    for c in candidates:
                        if c in row and row[c]:
                            return row[c].strip()
                    return default

                for row in reader:
                    ticker = _col(row, "ticker")
                    if not ticker or ticker == "":
                        continue

                    if snapshot_date is None:
                        date_str = _col(row, "date")
                        if date_str:
                            try:
                                snapshot_date = datetime.strptime(date_str, "%m/%d/%Y").date()
                            except ValueError:
                                snapshot_date = date.today()

                    shares_str = _col(row, "shares").replace(",", "")
                    mv_str = _col(row, "market value ($)", "market value($)").replace(",", "").replace("$", "")
                    wt_str = _col(row, "weight (%)", "weight(%)").replace("%", "")

                    market_value = Decimal(mv_str) if mv_str else Decimal("0")
                    total_value += market_value

                    holdings.append({
                        "ticker": ticker.upper(),
                        "company_name": _col(row, "company"),
                        "cusip": _col(row, "cusip"),
                        "shares": Decimal(shares_str) if shares_str else None,
                        "market_value": market_value,
                        "weight_percent": Decimal(wt_str) if wt_str else None,
                    })

                if not holdings:
                    print(f"    No holdings found in CSV")
                    continue

                snapshot_date = snapshot_date or date.today()

                existing = await session.execute(
                    select(HoldingsSnapshot).where(
                        HoldingsSnapshot.investor_id == investor.id,
                        HoldingsSnapshot.snapshot_date == snapshot_date,
                    )
                )
                if existing.scalar_one_or_none():
                    print(f"    {fund_code}: Already have data for {snapshot_date} ({len(holdings)} holdings)")
                    continue

                snapshot = HoldingsSnapshot(
                    investor_id=investor.id,
                    snapshot_date=snapshot_date,
                    total_value=total_value,
                    total_positions=len(holdings),
                    source=SnapshotSource.ARK_DAILY,
                )
                session.add(snapshot)
                await session.flush()

                for h in holdings:
                    record = HoldingRecord(
                        snapshot_id=snapshot.id,
                        ticker=h["ticker"],
                        company_name=h["company_name"],
                        cusip=h["cusip"],
                        shares=h["shares"],
                        market_value=h["market_value"],
                        weight_percent=h["weight_percent"],
                    )
                    session.add(record)

                # Update investor's last_data_fetch
                investor.last_data_fetch = datetime.utcnow()
                session.add(investor)

                await session.commit()
                print(f"    {fund_code}: Saved {len(holdings)} real holdings for {snapshot_date}")

            except httpx.HTTPError as e:
                print(f"    HTTP error fetching {fund_code}: {e}")
            except Exception as e:
                print(f"    Error processing {fund_code}: {e}")

    print("\nReal ARK holdings fetched\n")


async def fetch_real_13f_holdings():
    """Fetch REAL holdings data from SEC EDGAR 13F filings."""
    print("Fetching real 13F holdings from SEC EDGAR...")

    async with httpx.AsyncClient(headers=SEC_HEADERS, follow_redirects=True) as client:
        async with AsyncSessionLocal() as session:
            for filer_data in SEC_13F_FILERS:
                cik = filer_data["cik"]
                slug = filer_data["slug"]
                name = filer_data["name"]

                print(f"\n  Processing {name} (CIK: {cik})...")

                # Get investor
                result = await session.execute(
                    select(Investor).where(Investor.slug == slug)
                )
                investor = result.scalar_one_or_none()

                if not investor:
                    print(f"    Investor not found, skipping")
                    continue

                # Find latest 13F filing
                filing_info = await fetch_latest_13f_filing(client, cik)
                if not filing_info:
                    print(f"    No 13F-HR filing found")
                    continue

                filing_date_str = filing_info["filing_date"]
                try:
                    snapshot_date = datetime.strptime(filing_date_str, "%Y-%m-%d").date()
                except ValueError:
                    snapshot_date = date.today()

                print(f"    Found filing from {filing_date_str}")

                # Check if we already have this data
                existing = await session.execute(
                    select(HoldingsSnapshot).where(
                        HoldingsSnapshot.investor_id == investor.id,
                        HoldingsSnapshot.snapshot_date == snapshot_date,
                    )
                )
                if existing.scalar_one_or_none():
                    print(f"    Already have data for {snapshot_date}")
                    continue

                # Fetch holdings from filing
                holdings = await fetch_13f_holdings(client, filing_info)
                if not holdings:
                    print(f"    No holdings parsed from filing")
                    continue

                # Calculate totals
                total_value = sum(h.get("market_value", Decimal("0")) for h in holdings)

                # Create snapshot
                snapshot = HoldingsSnapshot(
                    investor_id=investor.id,
                    snapshot_date=snapshot_date,
                    total_value=total_value,
                    total_positions=len(holdings),
                    source=SnapshotSource.SEC_13F,
                )
                session.add(snapshot)
                await session.flush()

                # Create holding records
                for h in holdings:
                    cusip = h.get("cusip", "")
                    company_name = h.get("company_name", "")
                    ticker = cusip_to_ticker(cusip, company_name)

                    record = HoldingRecord(
                        snapshot_id=snapshot.id,
                        ticker=ticker,
                        company_name=company_name,
                        cusip=cusip,
                        shares=h.get("shares"),
                        market_value=h.get("market_value"),
                        weight_percent=(
                            (h.get("market_value", Decimal("0")) / total_value * 100)
                            if total_value > 0 else None
                        ),
                    )
                    session.add(record)

                # Update investor's last_data_fetch
                investor.last_data_fetch = datetime.utcnow()
                session.add(investor)

                await session.commit()
                print(f"    Saved {len(holdings)} real holdings for {snapshot_date}")

                # Be nice to SEC servers
                await asyncio.sleep(0.5)

    print("\nReal 13F holdings fetched\n")


async def main():
    """Main entry point."""
    print("=" * 60)
    print("WhyTheyBuy - Real Data Setup")
    print("=" * 60)
    print("\nThis script fetches REAL holdings data from:")
    print("  - ARK Invest daily CSV files")
    print("  - SEC EDGAR 13F filings")
    print()

    # Step 1: Create ARK investors
    await create_ark_investors()

    # Step 2: Create 13F filer investors
    await create_13f_investors()

    # Step 3: Fetch real ARK holdings
    await fetch_real_ark_holdings()

    # Step 4: Fetch real 13F holdings
    await fetch_real_13f_holdings()

    print("=" * 60)
    print("Setup complete! Your app now has REAL holdings data.")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
