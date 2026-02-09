"""Tests for holdings diff computation."""
import pytest
from decimal import Decimal

from app.services.diff import compute_holdings_diff, DiffResult
from app.models.holdings import ChangeType


class TestComputeHoldingsDiff:
    """Tests for compute_holdings_diff function."""
    
    def test_new_position(self):
        """Test detection of new positions."""
        old = {}
        new = {
            "AAPL": {
                "company_name": "Apple Inc.",
                "shares": "1000",
                "weight_percent": "5.5",
                "market_value": "150000",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].ticker == "AAPL"
        assert diffs[0].change_type == ChangeType.NEW
        assert diffs[0].shares_after == Decimal("1000")
        assert diffs[0].shares_before is None
    
    def test_sold_out_position(self):
        """Test detection of completely sold positions."""
        old = {
            "TSLA": {
                "company_name": "Tesla Inc.",
                "shares": "500",
                "weight_percent": "3.0",
                "market_value": "100000",
            }
        }
        new = {}
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].ticker == "TSLA"
        assert diffs[0].change_type == ChangeType.SOLD_OUT
        assert diffs[0].shares_before == Decimal("500")
        assert diffs[0].shares_after is None
        assert diffs[0].shares_delta_percent == Decimal("-100")
    
    def test_increased_position(self):
        """Test detection of increased positions."""
        old = {
            "NVDA": {
                "company_name": "NVIDIA Corp",
                "shares": "1000",
                "weight_percent": "4.0",
                "market_value": "400000",
            }
        }
        new = {
            "NVDA": {
                "company_name": "NVIDIA Corp",
                "shares": "1500",
                "weight_percent": "6.0",
                "market_value": "600000",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].ticker == "NVDA"
        assert diffs[0].change_type == ChangeType.ADDED
        assert diffs[0].shares_delta == Decimal("500")
        assert diffs[0].shares_delta_percent == Decimal("50")
    
    def test_reduced_position(self):
        """Test detection of reduced positions."""
        old = {
            "MSFT": {
                "company_name": "Microsoft Corp",
                "shares": "2000",
                "weight_percent": "8.0",
                "market_value": "800000",
            }
        }
        new = {
            "MSFT": {
                "company_name": "Microsoft Corp",
                "shares": "1500",
                "weight_percent": "6.0",
                "market_value": "600000",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].ticker == "MSFT"
        assert diffs[0].change_type == ChangeType.REDUCED
        assert diffs[0].shares_delta == Decimal("-500")
        assert diffs[0].shares_delta_percent == Decimal("-25")
    
    def test_no_significant_change(self):
        """Test that insignificant changes are filtered out."""
        old = {
            "AAPL": {
                "company_name": "Apple Inc.",
                "shares": "10000",
                "weight_percent": "5.0",
            }
        }
        new = {
            "AAPL": {
                "company_name": "Apple Inc.",
                "shares": "10005",  # Only 0.05% change
                "weight_percent": "5.0",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        # Change is less than 0.1%, should be filtered
        assert len(diffs) == 0
    
    def test_multiple_changes(self):
        """Test handling of multiple simultaneous changes."""
        old = {
            "AAPL": {"company_name": "Apple", "shares": "1000", "weight_percent": "5.0"},
            "TSLA": {"company_name": "Tesla", "shares": "500", "weight_percent": "3.0"},
            "MSFT": {"company_name": "Microsoft", "shares": "800", "weight_percent": "4.0"},
        }
        new = {
            "AAPL": {"company_name": "Apple", "shares": "1200", "weight_percent": "6.0"},
            "NVDA": {"company_name": "NVIDIA", "shares": "300", "weight_percent": "2.0"},
            "MSFT": {"company_name": "Microsoft", "shares": "600", "weight_percent": "3.0"},
        }
        
        diffs = compute_holdings_diff(old, new)
        
        # Should have: AAPL increased, TSLA sold out, NVDA new, MSFT reduced
        assert len(diffs) == 4
        
        tickers = {d.ticker: d for d in diffs}
        assert tickers["AAPL"].change_type == ChangeType.ADDED
        assert tickers["TSLA"].change_type == ChangeType.SOLD_OUT
        assert tickers["NVDA"].change_type == ChangeType.NEW
        assert tickers["MSFT"].change_type == ChangeType.REDUCED
    
    def test_weight_delta_calculation(self):
        """Test correct calculation of weight delta."""
        old = {
            "COIN": {
                "company_name": "Coinbase",
                "shares": "1000",
                "weight_percent": "4.5",
                "market_value": "50000",
            }
        }
        new = {
            "COIN": {
                "company_name": "Coinbase",
                "shares": "1500",
                "weight_percent": "6.8",
                "market_value": "75000",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].weight_before == Decimal("4.5")
        assert diffs[0].weight_after == Decimal("6.8")
        assert diffs[0].weight_delta == Decimal("2.3")
    
    def test_value_delta_calculation(self):
        """Test correct calculation of value delta."""
        old = {
            "SQ": {
                "company_name": "Block Inc",
                "shares": "1000",
                "market_value": "50000",
            }
        }
        new = {
            "SQ": {
                "company_name": "Block Inc",
                "shares": "800",
                "market_value": "35000",
            }
        }
        
        diffs = compute_holdings_diff(old, new)
        
        assert len(diffs) == 1
        assert diffs[0].value_before == Decimal("50000")
        assert diffs[0].value_after == Decimal("35000")
        assert diffs[0].value_delta == Decimal("-15000")
    
    def test_empty_portfolios(self):
        """Test handling of empty portfolios."""
        assert compute_holdings_diff({}, {}) == []
    
    def test_sorting_by_weight_delta(self):
        """Test that results are sorted by absolute weight delta."""
        old = {
            "A": {"company_name": "A", "shares": "100", "weight_percent": "1.0"},
            "B": {"company_name": "B", "shares": "100", "weight_percent": "2.0"},
            "C": {"company_name": "C", "shares": "100", "weight_percent": "3.0"},
        }
        new = {
            "A": {"company_name": "A", "shares": "200", "weight_percent": "1.5"},  # +0.5%
            "B": {"company_name": "B", "shares": "200", "weight_percent": "5.0"},  # +3.0%
            "C": {"company_name": "C", "shares": "200", "weight_percent": "4.0"},  # +1.0%
        }
        
        diffs = compute_holdings_diff(old, new)
        
        # Should be sorted: B (+3.0%), C (+1.0%), A (+0.5%)
        assert diffs[0].ticker == "B"
        assert diffs[1].ticker == "C"
        assert diffs[2].ticker == "A"
