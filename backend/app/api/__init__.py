"""API routes."""
from app.api import auth, users, investors, watchlist, companies, ai, payments, reports

__all__ = [
    "auth",
    "users", 
    "investors",
    "watchlist",
    "companies",
    "ai",
    "payments",
    "reports",
]
