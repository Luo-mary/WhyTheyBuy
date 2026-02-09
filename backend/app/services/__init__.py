"""Service modules."""
from app.services.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_token,
)
from app.services.ai import generate_investor_summary, generate_company_rationale
from app.services.email import send_password_reset_email, send_verification_email
from app.services.diff import compute_holdings_diff
from app.services.market_data import fetch_price_data, get_price_range

__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "create_refresh_token",
    "verify_token",
    "generate_investor_summary",
    "generate_company_rationale",
    "send_password_reset_email",
    "send_verification_email",
    "compute_holdings_diff",
    "fetch_price_data",
    "get_price_range",
]
