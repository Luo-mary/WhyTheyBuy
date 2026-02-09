"""WebSocket API for real-time stock data via Finnhub."""
import asyncio
import json
import logging
from typing import Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import websockets

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

# Finnhub WebSocket URL
FINNHUB_WS_URL = "wss://ws.finnhub.io"

# Store active client connections
active_connections: Set[WebSocket] = set()

# Store current subscriptions per client
client_subscriptions: dict[WebSocket, Set[str]] = {}

# Shared Finnhub connection
finnhub_ws = None
finnhub_subscribed_symbols: Set[str] = set()


class ConnectionManager:
    """Manages WebSocket connections and Finnhub relay."""

    def __init__(self):
        self.active_connections: Set[WebSocket] = set()
        self.client_subscriptions: dict[WebSocket, Set[str]] = {}
        self.finnhub_ws = None
        self.finnhub_task = None
        self.subscribed_symbols: Set[str] = set()

    async def connect(self, websocket: WebSocket):
        """Accept a new client connection."""
        await websocket.accept()
        self.active_connections.add(websocket)
        self.client_subscriptions[websocket] = set()
        logger.info(f"Client connected. Total connections: {len(self.active_connections)}")

        # Start Finnhub connection if this is the first client
        if len(self.active_connections) == 1:
            await self.start_finnhub_connection()

    def disconnect(self, websocket: WebSocket):
        """Handle client disconnection."""
        self.active_connections.discard(websocket)
        if websocket in self.client_subscriptions:
            del self.client_subscriptions[websocket]
        logger.info(f"Client disconnected. Total connections: {len(self.active_connections)}")

        # Stop Finnhub connection if no clients
        if len(self.active_connections) == 0:
            asyncio.create_task(self.stop_finnhub_connection())

    async def start_finnhub_connection(self):
        """Connect to Finnhub WebSocket."""
        if not settings.finnhub_api_key:
            logger.warning("No Finnhub API key configured")
            return

        try:
            self.finnhub_ws = await websockets.connect(
                f"{FINNHUB_WS_URL}?token={settings.finnhub_api_key}"
            )
            logger.info("Connected to Finnhub WebSocket")

            # Start listening task
            self.finnhub_task = asyncio.create_task(self.listen_finnhub())

        except Exception as e:
            logger.error(f"Failed to connect to Finnhub: {e}")
            self.finnhub_ws = None

    async def stop_finnhub_connection(self):
        """Disconnect from Finnhub WebSocket."""
        if self.finnhub_task:
            self.finnhub_task.cancel()
            self.finnhub_task = None

        if self.finnhub_ws:
            await self.finnhub_ws.close()
            self.finnhub_ws = None
            self.subscribed_symbols.clear()
            logger.info("Disconnected from Finnhub WebSocket")

    async def listen_finnhub(self):
        """Listen for messages from Finnhub and relay to clients."""
        try:
            async for message in self.finnhub_ws:
                data = json.loads(message)

                if data.get("type") == "trade":
                    # Relay trade data to all subscribed clients
                    await self.broadcast_trades(data.get("data", []))

                elif data.get("type") == "ping":
                    # Respond to ping
                    pass

        except websockets.ConnectionClosed:
            logger.info("Finnhub connection closed")
        except asyncio.CancelledError:
            logger.info("Finnhub listener cancelled")
        except Exception as e:
            logger.error(f"Error in Finnhub listener: {e}")

    async def broadcast_trades(self, trades: list):
        """Broadcast trade data to subscribed clients."""
        if not trades:
            return

        # Group trades by symbol
        trades_by_symbol: dict[str, list] = {}
        for trade in trades:
            symbol = trade.get("s")
            if symbol:
                if symbol not in trades_by_symbol:
                    trades_by_symbol[symbol] = []
                trades_by_symbol[symbol].append({
                    "price": trade.get("p"),
                    "volume": trade.get("v"),
                    "timestamp": trade.get("t"),
                })

        # Send to each client based on their subscriptions
        disconnected = []
        for client, subscriptions in self.client_subscriptions.items():
            for symbol, symbol_trades in trades_by_symbol.items():
                if symbol in subscriptions:
                    try:
                        # Send the latest trade for each symbol
                        latest = symbol_trades[-1]
                        await client.send_json({
                            "type": "trade",
                            "symbol": symbol,
                            "price": latest["price"],
                            "volume": latest["volume"],
                            "timestamp": latest["timestamp"],
                        })
                    except Exception:
                        disconnected.append(client)
                        break

        # Clean up disconnected clients
        for client in disconnected:
            self.disconnect(client)

    async def subscribe(self, websocket: WebSocket, symbol: str):
        """Subscribe a client to a symbol."""
        symbol = symbol.upper()

        if websocket not in self.client_subscriptions:
            return

        self.client_subscriptions[websocket].add(symbol)

        # Subscribe to Finnhub if not already subscribed
        if symbol not in self.subscribed_symbols and self.finnhub_ws:
            try:
                await self.finnhub_ws.send(json.dumps({
                    "type": "subscribe",
                    "symbol": symbol
                }))
                self.subscribed_symbols.add(symbol)
                logger.info(f"Subscribed to {symbol} on Finnhub")
            except Exception as e:
                logger.error(f"Failed to subscribe to {symbol}: {e}")

    async def unsubscribe(self, websocket: WebSocket, symbol: str):
        """Unsubscribe a client from a symbol."""
        symbol = symbol.upper()

        if websocket in self.client_subscriptions:
            self.client_subscriptions[websocket].discard(symbol)

        # Check if any other client still needs this symbol
        still_needed = any(
            symbol in subs
            for client, subs in self.client_subscriptions.items()
            if client != websocket
        )

        # Unsubscribe from Finnhub if no one needs it
        if not still_needed and symbol in self.subscribed_symbols and self.finnhub_ws:
            try:
                await self.finnhub_ws.send(json.dumps({
                    "type": "unsubscribe",
                    "symbol": symbol
                }))
                self.subscribed_symbols.discard(symbol)
                logger.info(f"Unsubscribed from {symbol} on Finnhub")
            except Exception as e:
                logger.error(f"Failed to unsubscribe from {symbol}: {e}")


# Global connection manager
manager = ConnectionManager()


@router.websocket("/ws/stocks")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for real-time stock data.

    Client messages:
    - {"action": "subscribe", "symbol": "AAPL"}
    - {"action": "unsubscribe", "symbol": "AAPL"}

    Server messages:
    - {"type": "trade", "symbol": "AAPL", "price": 150.25, "volume": 100, "timestamp": 1234567890}
    - {"type": "connected"}
    - {"type": "error", "message": "..."}
    """
    await manager.connect(websocket)

    try:
        # Send connection confirmation
        await websocket.send_json({
            "type": "connected",
            "message": "Connected to real-time stock data"
        })

        # Check if Finnhub is configured
        if not settings.finnhub_api_key:
            await websocket.send_json({
                "type": "error",
                "message": "Real-time data not configured. Please add FINNHUB_API_KEY to .env"
            })

        # Listen for client messages
        while True:
            data = await websocket.receive_json()
            action = data.get("action")
            symbol = data.get("symbol", "").upper()

            if action == "subscribe" and symbol:
                await manager.subscribe(websocket, symbol)
                await websocket.send_json({
                    "type": "subscribed",
                    "symbol": symbol
                })

            elif action == "unsubscribe" and symbol:
                await manager.unsubscribe(websocket, symbol)
                await websocket.send_json({
                    "type": "unsubscribed",
                    "symbol": symbol
                })

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
