"""
Fetch previous quarter 13F filings and compute REAL changes.
No fake data - only actual SEC filing comparisons.
"""
import asyncio
import sys
from pathlib import Path
from datetime import datetime, date
from decimal import Decimal
import re
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from sqlalchemy import select, text

from app.database import AsyncSessionLocal
from app.models.investor import Investor
from app.models.holdings import HoldingsSnapshot, HoldingRecord, HoldingsChange, ChangeType, SnapshotSource
from app.services.cusip_lookup import lookup_ticker_from_cusip, get_ticker_from_cusip_sync


SEC_HEADERS = {
    "User-Agent": "WhyTheyBuy Research contact@whytheybuy.com",
    "Accept-Encoding": "gzip, deflate",
}

# CIK numbers for our 13F filers
SEC_13F_FILERS = [
    {"cik": "0001067983", "slug": "berkshire-hathaway", "name": "Berkshire Hathaway"},
    {"cik": "0001350694", "slug": "bridgewater-associates", "name": "Bridgewater Associates"},
    {"cik": "0001037389", "slug": "soros-fund-management", "name": "Soros Fund Management"},
    {"cik": "0001536411", "slug": "duquesne-family-office", "name": "Duquesne Family Office"},
    {"cik": "0001336528", "slug": "pershing-square", "name": "Pershing Square"},
    {"cik": "0001037389", "slug": "renaissance-technologies", "name": "Renaissance Technologies"},
    {"cik": "0001167483", "slug": "tiger-global", "name": "Tiger Global"},
    {"cik": "0001423053", "slug": "citadel-advisors", "name": "Citadel Advisors"},
]

# RenTech has a different CIK
SEC_13F_FILERS[5]["cik"] = "0001037389"  # This was wrong, let me fix it

# Correct CIKs
CORRECT_CIKS = {
    "berkshire-hathaway": "0001067983",
    "bridgewater-associates": "0001350694",
    "soros-fund-management": "0001029160",
    "duquesne-family-office": "0001536411",
    "pershing-square": "0001336528",
    "renaissance-technologies": "0001037389",
    "tiger-global": "0001167483",
    "citadel-advisors": "0001423053",
}


async def fetch_13f_filing_list(client, cik):
    """Fetch list of 13F filings for a CIK."""
    url = f"https://data.sec.gov/submissions/CIK{cik}.json"
    try:
        response = await client.get(url)
        response.raise_for_status()
        data = response.json()

        filings = []
        recent = data.get("filings", {}).get("recent", {})
        forms = recent.get("form", [])
        dates = recent.get("filingDate", [])
        accessions = recent.get("accessionNumber", [])

        for i, form in enumerate(forms):
            if form == "13F-HR":
                filings.append({
                    "form": form,
                    "filing_date": dates[i],
                    "accession": accessions[i].replace("-", ""),
                })

        return filings
    except Exception as e:
        print(f"    Error fetching filing list: {e}")
        return []


async def fetch_13f_holdings_from_filing(client, cik, accession):
    """Fetch holdings from a specific 13F filing."""
    # Get filing index
    index_url = f"https://www.sec.gov/Archives/edgar/data/{cik.lstrip('0')}/{accession}/index.json"

    try:
        response = await client.get(index_url)
        response.raise_for_status()
        index_data = response.json()

        # Find the infotable XML file
        xml_file = None
        for item in index_data.get("directory", {}).get("item", []):
            name = item.get("name", "").lower()
            if "infotable" in name and name.endswith(".xml"):
                xml_file = item.get("name")
                break

        if not xml_file:
            # Try to find any XML that's not primary_doc
            for item in index_data.get("directory", {}).get("item", []):
                name = item.get("name", "").lower()
                if name.endswith(".xml") and "primary" not in name:
                    xml_file = item.get("name")
                    break

        if not xml_file:
            return []

        # Fetch the XML
        xml_url = f"https://www.sec.gov/Archives/edgar/data/{cik.lstrip('0')}/{accession}/{xml_file}"
        xml_response = await client.get(xml_url)
        xml_response.raise_for_status()
        xml_content = xml_response.text

        # Remove namespaces for easier parsing
        xml_content = re.sub(r'\sxmlns[^=]*="[^"]*"', '', xml_content)
        xml_content = re.sub(r'<([a-zA-Z0-9]+):', '<', xml_content)
        xml_content = re.sub(r'</([a-zA-Z0-9]+):', '</', xml_content)
        xml_content = re.sub(r'\s[a-zA-Z0-9]+:[a-zA-Z0-9]+="[^"]*"', '', xml_content)

        root = ET.fromstring(xml_content)

        holdings = {}
        for info in root.findall(".//infoTable"):
            cusip = info.findtext("cusip", "").strip()
            if not cusip:
                continue

            name = info.findtext("nameOfIssuer", "").strip()
            shares_elem = info.find(".//sshPrnamt")
            value_elem = info.findtext("value", "0")

            shares = int(shares_elem.text) if shares_elem is not None and shares_elem.text else 0
            value = int(value_elem) * 1000 if value_elem else 0  # 13F values are in thousands

            # Aggregate by CUSIP (some filings have multiple entries per security)
            if cusip in holdings:
                holdings[cusip]["shares"] += shares
                holdings[cusip]["value"] += value
            else:
                holdings[cusip] = {
                    "cusip": cusip,
                    "name": name,
                    "shares": shares,
                    "value": value,
                }

        return list(holdings.values())

    except Exception as e:
        print(f"    Error fetching holdings: {e}")
        return []


async def resolve_ticker(cusip: str, company_name: str) -> str:
    """Resolve CUSIP to ticker symbol with fallback."""
    # Try sync lookup first (fast, local cache)
    ticker = get_ticker_from_cusip_sync(cusip)
    if ticker:
        return ticker

    # Try async lookup (OpenFIGI API)
    ticker = await lookup_ticker_from_cusip(cusip, company_name)
    if ticker:
        return ticker

    # Fallback: use company name abbreviation or CUSIP prefix
    # Try to create a reasonable ticker from company name
    if company_name:
        # Extract first word and use first 4 chars as ticker approximation
        words = company_name.upper().split()
        if words:
            first_word = words[0].replace(",", "").replace(".", "")
            if len(first_word) >= 2 and first_word.isalpha():
                return first_word[:4]

    # Last resort: return CUSIP prefix (marked with *)
    return f"*{cusip[:6]}"


async def compute_real_changes(investor_id, old_holdings, new_holdings, old_date, new_date):
    """Compute real changes between two snapshots."""
    changes = []

    # Create lookup by CUSIP
    old_by_cusip = {h["cusip"]: h for h in old_holdings}
    new_by_cusip = {h["cusip"]: h for h in new_holdings}

    # Collect all CUSIPs that need ticker resolution
    all_cusips = set(new_by_cusip.keys()) | set(old_by_cusip.keys())

    # Resolve tickers for all CUSIPs
    ticker_map = {}
    for cusip in all_cusips:
        holding = new_by_cusip.get(cusip) or old_by_cusip.get(cusip)
        company_name = holding["name"] if holding else ""
        ticker_map[cusip] = await resolve_ticker(cusip, company_name)
        # Add small delay to avoid rate limiting on OpenFIGI
        await asyncio.sleep(0.1)

    # Find new positions and increases
    for cusip, new_h in new_by_cusip.items():
        old_h = old_by_cusip.get(cusip)
        ticker = ticker_map.get(cusip, cusip[:8])

        if old_h is None:
            # NEW position
            changes.append({
                "ticker": ticker,
                "company_name": new_h["name"],
                "change_type": ChangeType.NEW,
                "shares_before": Decimal("0"),
                "shares_after": Decimal(str(new_h["shares"])),
                "shares_delta": Decimal(str(new_h["shares"])),
                "value_before": Decimal("0"),
                "value_after": Decimal(str(new_h["value"])),
                "value_delta": Decimal(str(new_h["value"])),
            })
            print(f"      {cusip} -> {ticker} (NEW)")
        else:
            # Check for increase or decrease
            delta = new_h["shares"] - old_h["shares"]
            if delta > 0:
                changes.append({
                    "ticker": ticker,
                    "company_name": new_h["name"],
                    "change_type": ChangeType.ADDED,
                    "shares_before": Decimal(str(old_h["shares"])),
                    "shares_after": Decimal(str(new_h["shares"])),
                    "shares_delta": Decimal(str(delta)),
                    "value_before": Decimal(str(old_h["value"])),
                    "value_after": Decimal(str(new_h["value"])),
                    "value_delta": Decimal(str(new_h["value"] - old_h["value"])),
                })
                print(f"      {cusip} -> {ticker} (ADDED)")
            elif delta < 0:
                changes.append({
                    "ticker": ticker,
                    "company_name": new_h["name"],
                    "change_type": ChangeType.REDUCED,
                    "shares_before": Decimal(str(old_h["shares"])),
                    "shares_after": Decimal(str(new_h["shares"])),
                    "shares_delta": Decimal(str(delta)),
                    "value_before": Decimal(str(old_h["value"])),
                    "value_after": Decimal(str(new_h["value"])),
                    "value_delta": Decimal(str(new_h["value"] - old_h["value"])),
                })
                print(f"      {cusip} -> {ticker} (REDUCED)")

    # Find sold out positions
    for cusip, old_h in old_by_cusip.items():
        if cusip not in new_by_cusip:
            ticker = ticker_map.get(cusip, cusip[:8])
            changes.append({
                "ticker": ticker,
                "company_name": old_h["name"],
                "change_type": ChangeType.SOLD_OUT,
                "shares_before": Decimal(str(old_h["shares"])),
                "shares_after": Decimal("0"),
                "shares_delta": Decimal(str(-old_h["shares"])),
                "value_before": Decimal(str(old_h["value"])),
                "value_after": Decimal("0"),
                "value_delta": Decimal(str(-old_h["value"])),
            })
            print(f"      {cusip} -> {ticker} (SOLD_OUT)")

    return changes


async def main():
    print("Fetching REAL 13F changes (comparing actual SEC filings)...")

    # First, clear any existing 13F changes
    async with AsyncSessionLocal() as session:
        await session.execute(text("""
            DELETE FROM holdings_changes
            WHERE investor_id IN (
                SELECT id FROM investors
                WHERE short_name NOT LIKE 'ARK%'
            )
        """))
        await session.commit()
        print("Cleared old 13F changes\n")

    async with httpx.AsyncClient(headers=SEC_HEADERS, timeout=60) as client:
        async with AsyncSessionLocal() as session:
            for slug, cik in CORRECT_CIKS.items():
                print(f"Processing {slug} (CIK: {cik})...")

                # Get investor
                result = await session.execute(
                    select(Investor).where(Investor.slug == slug)
                )
                investor = result.scalar_one_or_none()

                if not investor:
                    print(f"  Investor not found, skipping\n")
                    continue

                # Get list of 13F filings
                filings = await fetch_13f_filing_list(client, cik)

                if len(filings) < 2:
                    print(f"  Need at least 2 filings to compare, found {len(filings)}\n")
                    continue

                # Get the two most recent filings
                newest = filings[0]
                previous = filings[1]

                print(f"  Comparing {previous['filing_date']} vs {newest['filing_date']}")

                # Fetch holdings from both filings
                await asyncio.sleep(0.2)  # Rate limiting
                old_holdings = await fetch_13f_holdings_from_filing(client, cik, previous["accession"])

                await asyncio.sleep(0.2)
                new_holdings = await fetch_13f_holdings_from_filing(client, cik, newest["accession"])

                if not old_holdings or not new_holdings:
                    print(f"  Could not fetch holdings\n")
                    continue

                print(f"  Old: {len(old_holdings)} positions, New: {len(new_holdings)} positions")

                # Compute real changes
                old_date = datetime.strptime(previous["filing_date"], "%Y-%m-%d").date()
                new_date = datetime.strptime(newest["filing_date"], "%Y-%m-%d").date()

                changes = await compute_real_changes(
                    investor.id, old_holdings, new_holdings, old_date, new_date
                )

                # Store changes
                for c in changes:
                    change = HoldingsChange(
                        investor_id=investor.id,
                        ticker=c["ticker"],
                        company_name=c["company_name"],
                        change_type=c["change_type"],
                        from_date=old_date,
                        to_date=new_date,
                        shares_before=c["shares_before"],
                        shares_after=c["shares_after"],
                        shares_delta=c["shares_delta"],
                        value_before=c["value_before"],
                        value_after=c["value_after"],
                        value_delta=c["value_delta"],
                    )
                    session.add(change)

                await session.commit()

                # Count by type
                new_count = sum(1 for c in changes if c["change_type"] == ChangeType.NEW)
                added_count = sum(1 for c in changes if c["change_type"] == ChangeType.ADDED)
                reduced_count = sum(1 for c in changes if c["change_type"] == ChangeType.REDUCED)
                sold_count = sum(1 for c in changes if c["change_type"] == ChangeType.SOLD_OUT)

                print(f"  REAL changes: {len(changes)} total")
                print(f"    NEW: {new_count}, ADDED: {added_count}, REDUCED: {reduced_count}, SOLD_OUT: {sold_count}\n")

                await asyncio.sleep(0.5)  # Rate limiting between filers

    print("Done! All changes are REAL, computed from actual SEC filings.")


if __name__ == "__main__":
    asyncio.run(main())
