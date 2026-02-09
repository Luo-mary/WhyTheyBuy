"""Market data service for fetching price information."""
import logging
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Optional
import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# Simple in-memory cache to avoid hitting rate limits
_price_cache: dict[str, tuple[datetime, list[dict]]] = {}
_quote_cache: dict[str, tuple[datetime, dict]] = {}
CACHE_TTL_MINUTES = 5  # Cache for 5 minutes

# API endpoints
ALPHA_VANTAGE_BASE = "https://www.alphavantage.co/query"
POLYGON_BASE = "https://api.polygon.io"
FINNHUB_BASE = "https://finnhub.io/api/v1"


async def fetch_price_data(
    ticker: str,
    from_date: date,
    to_date: date,
    source: str = "alpha_vantage",
) -> list[dict]:
    """
    Fetch historical price data for a ticker.

    Returns list of dicts with: date, open, high, low, close, volume
    """
    ticker = ticker.upper()
    cache_key = f"{ticker}_{source}"

    # Check cache first
    if cache_key in _price_cache:
        cached_time, cached_data = _price_cache[cache_key]
        if datetime.now() - cached_time < timedelta(minutes=CACHE_TTL_MINUTES):
            logger.info(f"Returning cached price data for {ticker}")
            # Filter cached data by date range
            return [p for p in cached_data if from_date <= p["date"] <= to_date]

    if source == "alpha_vantage" and settings.alpha_vantage_api_key:
        data = await fetch_alpha_vantage(ticker, from_date, to_date)
        if data:
            _price_cache[cache_key] = (datetime.now(), data)
        return data
    elif source == "polygon" and settings.polygon_api_key:
        return await fetch_polygon(ticker, from_date, to_date)
    elif source == "yahoo":
        return await fetch_yahoo_finance(ticker, from_date, to_date)
    else:
        # Fallback to Yahoo Finance (no API key required)
        logger.info(f"Using Yahoo Finance for {ticker} (no API key required)")
        return await fetch_yahoo_finance(ticker, from_date, to_date)


async def fetch_alpha_vantage(
    ticker: str,
    from_date: date,
    to_date: date,
) -> list[dict]:
    """Fetch price data from Alpha Vantage."""
    try:
        # Use compact mode (last 100 days) for faster response and lower API usage
        async with httpx.AsyncClient() as client:
            response = await client.get(
                ALPHA_VANTAGE_BASE,
                params={
                    "function": "TIME_SERIES_DAILY",
                    "symbol": ticker,
                    "outputsize": "compact",
                    "apikey": settings.alpha_vantage_api_key,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            time_series = data.get("Time Series (Daily)", {})
            prices = []
            
            for date_str, values in time_series.items():
                price_date = datetime.strptime(date_str, "%Y-%m-%d").date()
                
                if from_date <= price_date <= to_date:
                    prices.append({
                        "date": price_date,
                        "open": Decimal(values["1. open"]),
                        "high": Decimal(values["2. high"]),
                        "low": Decimal(values["3. low"]),
                        "close": Decimal(values["4. close"]),
                        "volume": int(values["5. volume"]),
                    })
            
            return sorted(prices, key=lambda p: p["date"])
            
    except Exception as e:
        logger.error(f"Error fetching Alpha Vantage data for {ticker}: {e}")
        return []


async def fetch_polygon(
    ticker: str,
    from_date: date,
    to_date: date,
) -> list[dict]:
    """Fetch price data from Polygon.io."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{POLYGON_BASE}/v2/aggs/ticker/{ticker}/range/1/day/{from_date}/{to_date}",
                params={"apiKey": settings.polygon_api_key},
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            prices = []
            for result in data.get("results", []):
                prices.append({
                    "date": datetime.fromtimestamp(result["t"] / 1000).date(),
                    "open": Decimal(str(result["o"])),
                    "high": Decimal(str(result["h"])),
                    "low": Decimal(str(result["l"])),
                    "close": Decimal(str(result["c"])),
                    "volume": int(result["v"]),
                })
            
            return sorted(prices, key=lambda p: p["date"])
            
    except Exception as e:
        logger.error(f"Error fetching Polygon data for {ticker}: {e}")
        return []


async def fetch_yahoo_finance(
    ticker: str,
    from_date: date,
    to_date: date,
) -> list[dict]:
    """
    Fetch price data from Yahoo Finance (no API key required).
    Uses yfinance library.
    """
    import asyncio
    from concurrent.futures import ThreadPoolExecutor

    def _fetch_sync():
        try:
            import yfinance as yf

            # yfinance needs end date to be exclusive, so add 1 day
            end_date = to_date + timedelta(days=1)

            stock = yf.Ticker(ticker)
            df = stock.history(start=from_date.isoformat(), end=end_date.isoformat())

            if df.empty:
                logger.warning(f"No Yahoo Finance data for {ticker}")
                return []

            prices = []
            for idx, row in df.iterrows():
                price_date = idx.date() if hasattr(idx, 'date') else idx
                prices.append({
                    "date": price_date,
                    "open": Decimal(str(round(row["Open"], 2))),
                    "high": Decimal(str(round(row["High"], 2))),
                    "low": Decimal(str(round(row["Low"], 2))),
                    "close": Decimal(str(round(row["Close"], 2))),
                    "volume": int(row["Volume"]),
                })

            return sorted(prices, key=lambda p: p["date"])

        except Exception as e:
            logger.error(f"Error fetching Yahoo Finance data for {ticker}: {e}")
            return []

    # Run synchronous yfinance in a thread pool
    loop = asyncio.get_event_loop()
    with ThreadPoolExecutor() as executor:
        return await loop.run_in_executor(executor, _fetch_sync)


async def get_price_range(
    ticker: str,
    from_date: date,
    to_date: date,
) -> tuple[Optional[Decimal], Optional[Decimal]]:
    """
    Get the price range (low, high) for a ticker over a date range.
    
    Returns (period_low, period_high) or (None, None) if data unavailable.
    """
    prices = await fetch_price_data(ticker, from_date, to_date)
    
    if not prices:
        return None, None
    
    lows = [p["low"] for p in prices if p.get("low")]
    highs = [p["high"] for p in prices if p.get("high")]
    
    if not lows or not highs:
        return None, None
    
    return min(lows), max(highs)


async def get_single_day_price(
    ticker: str,
    price_date: date,
) -> dict:
    """Get OHLC for a single day."""
    prices = await fetch_price_data(ticker, price_date, price_date)
    
    if prices:
        return prices[0]
    
    # Try previous trading day if exact date not found
    for days_back in range(1, 5):
        check_date = price_date - timedelta(days=days_back)
        prices = await fetch_price_data(ticker, check_date, check_date)
        if prices:
            return prices[0]
    
    return {}


async def fetch_company_profile(ticker: str) -> dict:
    """Fetch company profile from Finnhub or other source."""
    if not settings.finnhub_api_key:
        return {}
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{FINNHUB_BASE}/stock/profile2",
                params={
                    "symbol": ticker,
                    "token": settings.finnhub_api_key,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            return {
                "ticker": data.get("ticker", ticker),
                "name": data.get("name"),
                "exchange": data.get("exchange"),
                "sector": data.get("finnhubIndustry"),
                "industry": data.get("finnhubIndustry"),
                "market_cap": data.get("marketCapitalization"),
                "shares_outstanding": data.get("shareOutstanding"),
                "website": data.get("weburl"),
                "logo_url": data.get("logo"),
                "ipo_date": data.get("ipo"),
            }
    except Exception as e:
        logger.error(f"Error fetching company profile for {ticker}: {e}")
        return {}


async def batch_fetch_prices(
    tickers: list[str],
    from_date: date,
    to_date: date,
) -> dict[str, list[dict]]:
    """Batch fetch prices for multiple tickers."""
    results = {}

    for ticker in tickers:
        results[ticker] = await fetch_price_data(ticker, from_date, to_date)

    return results


async def fetch_realtime_quote(ticker: str) -> dict:
    """
    Fetch real-time quote from Alpha Vantage.

    Returns dict with: price, change, change_percent, volume, high, low, open, previous_close
    """
    ticker = ticker.upper()

    # Check cache first
    if ticker in _quote_cache:
        cached_time, cached_data = _quote_cache[ticker]
        if datetime.now() - cached_time < timedelta(minutes=CACHE_TTL_MINUTES):
            logger.info(f"Returning cached quote for {ticker}")
            return cached_data

    if not settings.alpha_vantage_api_key:
        logger.warning(f"No Alpha Vantage API key configured")
        return {}

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                ALPHA_VANTAGE_BASE,
                params={
                    "function": "GLOBAL_QUOTE",
                    "symbol": ticker,
                    "apikey": settings.alpha_vantage_api_key,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()

            quote = data.get("Global Quote", {})

            if not quote:
                # Check for API limit message
                if "Note" in data or "Information" in data:
                    logger.warning(f"Alpha Vantage API limit reached: {data}")
                return {}

            result = {
                "ticker": ticker.upper(),
                "price": Decimal(quote.get("05. price", "0")),
                "change": Decimal(quote.get("09. change", "0")),
                "change_percent": quote.get("10. change percent", "0%").replace("%", ""),
                "volume": int(quote.get("06. volume", "0")),
                "high": Decimal(quote.get("03. high", "0")),
                "low": Decimal(quote.get("04. low", "0")),
                "open": Decimal(quote.get("02. open", "0")),
                "previous_close": Decimal(quote.get("08. previous close", "0")),
                "latest_trading_day": quote.get("07. latest trading day"),
            }

            # Cache the result
            _quote_cache[ticker] = (datetime.now(), result)
            return result

    except Exception as e:
        logger.error(f"Error fetching Alpha Vantage quote for {ticker}: {e}")
        return {}
