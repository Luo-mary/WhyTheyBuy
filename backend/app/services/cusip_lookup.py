"""
CUSIP to Ticker lookup service.

13F filings use CUSIPs as identifiers, but we need tickers for:
- User-friendly display
- AI reasoning (Gemini can better analyze tickers like "KHC" vs CUSIPs like "500754106")
- Price data lookups

This module provides lookup functionality using multiple sources:
1. Local cache (fast)
2. OpenFIGI API (free, authoritative)
3. Fallback heuristics
"""

import asyncio
import logging
import httpx
from functools import lru_cache
from typing import Optional

logger = logging.getLogger(__name__)

# Well-known CUSIP to Ticker mappings for popular stocks
# This serves as a fast local cache for common holdings
KNOWN_CUSIP_MAPPINGS = {
    # Tech Giants
    "594918104": "MSFT",    # Microsoft
    "037833100": "AAPL",    # Apple
    "02079K305": "GOOG",    # Alphabet Class C
    "02079K107": "GOOGL",   # Alphabet Class A
    "023135106": "AMZN",    # Amazon
    "30303M102": "META",    # Meta Platforms
    "67066G104": "NVDA",    # NVIDIA
    "88160R101": "TSLA",    # Tesla
    "09857L108": "BKNG",    # Booking Holdings
    "22160K105": "COST",    # Costco
    "126408103": "CRM",     # Salesforce
    "00724F101": "ADBE",    # Adobe
    "464287473": "INTC",    # Intel
    "007903107": "AMD",     # AMD
    "79466L302": "COP",     # ConocoPhillips

    # Berkshire's top holdings
    "500754106": "KHC",     # Kraft Heinz
    "674599105": "OXY",     # Occidental Petroleum
    "172967424": "C",       # Citigroup
    "060505104": "BAC",     # Bank of America
    "20825C104": "KO",      # Coca-Cola
    "035420103": "AXP",     # American Express
    "166764100": "CVX",     # Chevron
    "459200101": "IBM",     # IBM
    "571748102": "MA",      # Mastercard
    "92343V104": "VZ",      # Verizon
    "G5480U104": "LLY",     # Eli Lilly (foreign CUSIP)
    "24736N103": "DELL",    # Dell Technologies
    "92826C839": "V",       # Visa
    "256677105": "DVA",     # DaVita
    "G32655105": "LSXMA",   # Liberty SiriusXM
    "G32655204": "LSXMK",   # Liberty SiriusXM K
    "531229409": "LPX",     # Louisiana-Pacific
    "553030106": "MCO",     # Moody's
    "609207105": "MDLZ",    # Mondelez
    "617446448": "MS",      # Morgan Stanley
    "655044105": "NVR",     # NVR Inc
    "62955J103": "NUE",     # Nucor
    "69331C108": "PM",      # Philip Morris
    "G71766103": "RH",      # RH (Restoration Hardware)
    "78409V104": "SIRI",    # Sirius XM
    "865622100": "STZ",     # Constellation Brands
    "91911K102": "ULTA",    # Ulta Beauty
    "92553P201": "VRSN",    # Verisign
    "168088102": "CHTR",    # Charter Communications
    "29786A106": "ETSY",    # Etsy
    "427866108": "HEICO",   # HEICO Corporation

    # Financial
    "46625H100": "JPM",     # JPMorgan Chase
    "38141G104": "GS",      # Goldman Sachs
    "949746101": "WFC",     # Wells Fargo
    "084670702": "BRK.B",   # Berkshire Hathaway B
    "084670108": "BRK.A",   # Berkshire Hathaway A
    "14040H105": "COF",     # Capital One
    "00206R102": "T",       # AT&T
    "14149Y108": "ALLY",    # Ally Financial
    "G0176J109": "ACN",     # Accenture
    "G0450A105": "AON",     # Aon
    "G0177J108": "ACN",     # Accenture (alternate)
    "09247X101": "BLK",     # BlackRock
    "149123101": "CAT",     # Caterpillar
    "125523100": "CI",      # Cigna
    "302130109": "XOM",     # Exxon Mobil (alternate)
    "337932107": "FITB",    # Fifth Third Bancorp
    "441815103": "HPQ",     # HP Inc
    "45866F104": "ICE",     # Intercontinental Exchange
    "460146103": "IP",      # International Paper
    "48203R104": "JNPR",    # Juniper Networks
    "491033100": "KEY",     # KeyCorp
    "50540R409": "LYV",     # Live Nation
    "552953101": "MDT",     # Medtronic
    "580135101": "MCD",     # McDonald's
    "58155Q103": "MU",      # Micron
    "68389X105": "ORCL",    # Oracle
    "743315103": "PNC",     # PNC Financial
    "756109104": "RTX",     # Raytheon
    "78462F103": "SPY",     # SPDR S&P 500 ETF
    "808513105": "SCHW",    # Charles Schwab
    "816851109": "SQ",      # Block Inc (Square)
    "855244109": "SBUX",    # Starbucks
    "871829107": "SYF",     # Synchrony Financial
    "872540109": "TJX",     # TJX Companies
    "882508104": "TGT",     # Target
    "891906109": "TOL",     # Toll Brothers
    "896522109": "TRV",     # Travelers
    "902104108": "USB",     # U.S. Bancorp
    "91913Y100": "UBER",    # Uber
    "928298108": "VMC",     # Vulcan Materials
    "977137109": "WY",      # Weyerhaeuser

    # Healthcare
    "478160104": "JNJ",     # Johnson & Johnson
    "58933Y105": "MRK",     # Merck
    "718172109": "PFE",     # Pfizer
    "002824100": "ABBV",    # AbbVie
    "91324P102": "UNH",     # UnitedHealth
    "053015103": "AVGO",    # Broadcom
    "457030104": "INFY",    # Infosys
    "883556102": "TMO",     # Thermo Fisher
    "004849100": "A",       # Agilent
    "025537101": "AMGN",    # Amgen
    "124805102": "BMY",     # Bristol-Myers Squibb
    "179414108": "CLX",     # Clorox
    "210795209": "CNC",     # Centene
    "368546109": "GIS",     # General Mills
    "46619E602": "ISRG",    # Intuitive Surgical
    "58155Q103": "MU",      # Micron
    "713448108": "PEP",     # PepsiCo
    "759509102": "REGN",    # Regeneron
    "92532F100": "VRTX",    # Vertex

    # Consumer
    "742718109": "PG",      # Procter & Gamble
    "931142103": "WMT",     # Walmart
    "254687106": "DIS",     # Disney
    "532457108": "LMT",     # Lockheed Martin
    "64110L106": "NFLX",    # Netflix
    "437076102": "HD",      # Home Depot
    "501044101": "KR",      # Kroger
    "58155U103": "MARA",    # Marathon Digital
    "67011P100": "NWL",     # Newell Brands
    "68404L201": "ONON",    # On Holding
    "708160106": "JWN",     # Nordstrom
    "743315103": "PNC",     # PNC Financial
    "828359104": "SLB",     # Schlumberger

    # Insurance (Berkshire holdings)
    "H1467J104": "CB",      # Chubb Limited
    "G0176J109": "ACN",     # Accenture

    # Energy
    "30231G102": "XOM",     # Exxon Mobil
    "345370860": "F",       # Ford
    "369604103": "GE",      # General Electric
    "20825C104": "KO",      # Coca-Cola
    "35137L105": "FANG",    # Diamondback Energy
    "25179M103": "DVN",     # Devon Energy
    "302154105": "EOG",     # EOG Resources
    "33767D105": "FE",      # FirstEnergy
    "361448105": "HAL",     # Halliburton
    "423074103": "HES",     # Hess Corporation
    "559080101": "MPC",     # Marathon Petroleum
    "69351T106": "PSX",     # Phillips 66
    "913017109": "UPS",     # UPS
    "92857W308": "VLO",     # Valero Energy

    # Bridgewater / Large 13F filers common holdings
    "031162100": "AMZN",    # Amazon (alternate)
    "172967424": "C",       # Citigroup
    "20030N101": "CMCSA",   # Comcast
    "254687106": "DIS",     # Disney
    "345370860": "F",       # Ford
    "42824C109": "HSBC",    # HSBC
    "459200101": "IBM",     # IBM
    "459506101": "INTU",    # Intuit
    "478160104": "JNJ",     # Johnson & Johnson
    "532457108": "LMT",     # Lockheed Martin
    "55354G100": "MMM",     # 3M
    "617446448": "MS",      # Morgan Stanley
    "637071101": "NEE",     # NextEra Energy
    "704326107": "PEG",     # PSEG
    "742718109": "PG",      # Procter & Gamble
    "74834L100": "QCOM",    # Qualcomm
    "759930109": "RIOT",    # Riot Platforms
    "78378X107": "SLV",     # iShares Silver Trust
    "78462F103": "SPY",     # SPDR S&P 500
    "81369Y704": "SHW",     # Sherwin-Williams
    "84265V105": "SO",      # Southern Company
    "858119100": "STT",     # State Street
    "872540109": "TJX",     # TJX
    "902973304": "UNP",     # Union Pacific
    "92913P100": "VICI",    # VICI Properties
    "931142103": "WMT",     # Walmart
}

# Reverse mapping: Ticker -> CUSIP (built from KNOWN_CUSIP_MAPPINGS)
KNOWN_TICKER_TO_CUSIP = {v: k for k, v in KNOWN_CUSIP_MAPPINGS.items()}


def get_cusip_from_ticker(ticker: str) -> Optional[str]:
    """
    Reverse lookup: Get CUSIP from ticker symbol.

    This is useful when the frontend sends a resolved ticker (like "KHC")
    but the database stores the original CUSIP (like "500754106").

    Args:
        ticker: The ticker symbol

    Returns:
        CUSIP if found in the known mappings, None otherwise
    """
    if not ticker:
        return None
    return KNOWN_TICKER_TO_CUSIP.get(ticker.upper())


async def lookup_ticker_from_cusip(cusip: str, company_name: Optional[str] = None) -> Optional[str]:
    """
    Look up ticker symbol from CUSIP.

    Args:
        cusip: The CUSIP identifier (9 characters)
        company_name: Optional company name for fallback matching

    Returns:
        Ticker symbol if found, None otherwise
    """
    if not cusip:
        return None

    # Clean CUSIP (remove any spaces/dashes)
    cusip = cusip.strip().replace("-", "").replace(" ", "").upper()

    # 1. Check local cache first (fast)
    if cusip in KNOWN_CUSIP_MAPPINGS:
        return KNOWN_CUSIP_MAPPINGS[cusip]

    # 2. Try OpenFIGI API
    ticker = await _lookup_openfigi(cusip)
    if ticker:
        # Cache for future lookups
        KNOWN_CUSIP_MAPPINGS[cusip] = ticker
        return ticker

    # 3. Fallback: try to extract from company name
    if company_name:
        ticker = _guess_ticker_from_name(company_name)
        if ticker:
            return ticker

    return None


async def _lookup_openfigi(cusip: str) -> Optional[str]:
    """
    Query OpenFIGI API for CUSIP to ticker mapping.

    OpenFIGI is free and provides authoritative security identifiers.
    Rate limit: 25 requests per minute for unauthenticated.
    """
    try:
        url = "https://api.openfigi.com/v3/mapping"
        payload = [{"idType": "ID_CUSIP", "idValue": cusip}]

        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=10.0,
            )

            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0 and "data" in data[0]:
                    for item in data[0]["data"]:
                        ticker = item.get("ticker")
                        if ticker:
                            logger.info(f"OpenFIGI resolved {cusip} -> {ticker}")
                            return ticker

    except Exception as e:
        logger.warning(f"OpenFIGI lookup failed for {cusip}: {e}")

    return None


def _guess_ticker_from_name(company_name: str) -> Optional[str]:
    """
    Attempt to guess ticker from company name.

    This is a last resort fallback - not always accurate.
    """
    if not company_name:
        return None

    name_upper = company_name.upper()

    # Common mappings based on company name
    name_mappings = {
        "KRAFT HEINZ": "KHC",
        "OCCIDENTAL PETE": "OXY",
        "OCCIDENTAL PETROLEUM": "OXY",
        "CHUBB": "CB",
        "BANK OF AMERICA": "BAC",
        "BANK AMER": "BAC",
        "COCA-COLA": "KO",
        "COCA COLA": "KO",
        "AMERICAN EXPRESS": "AXP",
        "APPLE": "AAPL",
        "MICROSOFT": "MSFT",
        "AMAZON": "AMZN",
        "AMAZON COM": "AMZN",
        "ALPHABET": "GOOGL",
        "GOOGLE": "GOOGL",
        "META PLATFORMS": "META",
        "FACEBOOK": "META",
        "NVIDIA": "NVDA",
        "TESLA": "TSLA",
        "BERKSHIRE": "BRK.B",
        "JPMORGAN": "JPM",
        "JP MORGAN": "JPM",
        "WELLS FARGO": "WFC",
        "CHEVRON": "CVX",
        "EXXON": "XOM",
        "JOHNSON & JOHNSON": "JNJ",
        "JOHNSON AND JOHNSON": "JNJ",
        "PROCTER & GAMBLE": "PG",
        "PROCTER GAMBLE": "PG",
        "WALT DISNEY": "DIS",
        "DISNEY": "DIS",
        "VISA": "V",
        "MASTERCARD": "MA",
        "INTEL": "INTC",
        "CISCO": "CSCO",
        "CISCO SYS": "CSCO",
        "ORACLE": "ORCL",
        "NETFLIX": "NFLX",
        "STARBUCKS": "SBUX",
        "MCDONALD": "MCD",
        "MCDONALDS": "MCD",
        "HOME DEPOT": "HD",
        "TARGET": "TGT",
        "COSTCO": "COST",
        "WALMART": "WMT",
        "PFIZER": "PFE",
        "MERCK": "MRK",
        "ABBVIE": "ABBV",
        "ELI LILLY": "LLY",
        "UNITEDHEALTH": "UNH",
        "UNITED HEALTH": "UNH",
        "BOEING": "BA",
        "CATERPILLAR": "CAT",
        "GENERAL ELECTRIC": "GE",
        "3M": "MMM",
        "HONEYWELL": "HON",
        "UNION PACIFIC": "UNP",
        "LOCKHEED": "LMT",
        "RAYTHEON": "RTX",
        "NORTHROP": "NOC",
        "GENERAL DYNAMICS": "GD",
        "GOLDMAN": "GS",
        "GOLDMAN SACHS": "GS",
        "MORGAN STANLEY": "MS",
        "CITIGROUP": "C",
        "CITI": "C",
        "BLACKROCK": "BLK",
        "CHARLES SCHWAB": "SCHW",
        "STATE STREET": "STT",
        "CAPITAL ONE": "COF",
        "TRAVELERS": "TRV",
        "AT&T": "T",
        "VERIZON": "VZ",
        "COMCAST": "CMCSA",
        "CHARTER COMM": "CHTR",
        "SALESFORCE": "CRM",
        "ADOBE": "ADBE",
        "SERVICENOW": "NOW",
        "INTUIT": "INTU",
        "BROADCOM": "AVGO",
        "QUALCOMM": "QCOM",
        "ADVANCED MICRO": "AMD",
        "MICRON": "MU",
        "TEXAS INSTRUMENTS": "TXN",
        "APPLIED MATERIALS": "AMAT",
        "ANALOG DEVICES": "ADI",
        "NEXTERA": "NEE",
        "DUKE ENERGY": "DUK",
        "SOUTHERN": "SO",
        "DOMINION": "D",
        "CONOCOPHILLIPS": "COP",
        "PHILLIPS 66": "PSX",
        "VALERO": "VLO",
        "MARATHON PETRO": "MPC",
        "SCHLUMBERGER": "SLB",
        "HALLIBURTON": "HAL",
        "VERISIGN": "VRSN",
        "MOODY": "MCO",
        "S&P GLOBAL": "SPGI",
        "CME GROUP": "CME",
        "INTERCONTINENTAL": "ICE",
        "KROGER": "KR",
        "PEPSI": "PEP",
        "MONDELEZ": "MDLZ",
        "PHILIP MORRIS": "PM",
        "ALTRIA": "MO",
        "CONSTELLATION": "STZ",
        "DIAGEO": "DEO",
        "ANHEUSER": "BUD",
        "BOOKING": "BKNG",
        "UBER": "UBER",
        "AIRBNB": "ABNB",
        "BLOCK INC": "SQ",
        "SQUARE": "SQ",
        "PAYPAL": "PYPL",
        "DAVITA": "DVA",
        "NVR INC": "NVR",
        "NUCOR": "NUE",
        "SIRIUS": "SIRI",
        "LIBERTY": "LSXMA",
        "LOUISIANA PAC": "LPX",
        "HEICO": "HEI",
        "ALLY FINL": "ALLY",
        "ALLY FINANCIAL": "ALLY",
        "DOMINO": "DPZ",
        "CHIPOTLE": "CMG",
        "HILTON": "HLT",
        "MARRIOTT": "MAR",
        "ULTA": "ULTA",
        "RESTORATION HARDWARE": "RH",
        "RH INC": "RH",
        "ETSY": "ETSY",
    }

    for pattern, ticker in name_mappings.items():
        if pattern in name_upper:
            return ticker

    return None


async def enrich_holdings_with_tickers(holdings: list[dict]) -> list[dict]:
    """
    Enrich a list of holdings with ticker symbols from CUSIPs.

    Args:
        holdings: List of holding dicts with 'cusip', 'ticker', and 'company_name' keys

    Returns:
        Same list with 'ticker' fields populated where possible
    """
    tasks = []
    for holding in holdings:
        cusip = holding.get("cusip") or ""
        current_ticker = holding.get("ticker") or ""
        company_name = holding.get("company_name") or ""

        # Skip if already has a valid ticker (not a share class description)
        if current_ticker and len(current_ticker) <= 5 and current_ticker.isalpha():
            continue

        # Look up ticker from CUSIP
        tasks.append(lookup_ticker_from_cusip(cusip, company_name))

    if tasks:
        results = await asyncio.gather(*tasks, return_exceptions=True)

        result_idx = 0
        for holding in holdings:
            current_ticker = holding.get("ticker") or ""

            # Skip if already has a valid ticker
            if current_ticker and len(current_ticker) <= 5 and current_ticker.isalpha():
                continue

            if result_idx < len(results) and not isinstance(results[result_idx], Exception):
                new_ticker = results[result_idx]
                if new_ticker:
                    holding["ticker"] = new_ticker
            result_idx += 1

    return holdings


def get_ticker_from_cusip_sync(cusip: str) -> Optional[str]:
    """
    Synchronous version that only checks local cache.
    Use for display purposes when async isn't available.
    """
    if not cusip:
        return None
    cusip = cusip.strip().replace("-", "").replace(" ", "").upper()
    return KNOWN_CUSIP_MAPPINGS.get(cusip)
