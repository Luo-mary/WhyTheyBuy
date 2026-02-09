"""
Enhanced AI Analysis Service - Evidence-Based Reasoning

Generates focused, evidence-rich analysis without boilerplate.
"""

from datetime import datetime, timedelta
from decimal import Decimal
from typing import Optional, List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.holdings import HoldingRecord, HoldingsChange, HoldingsSnapshot, ChangeType
from app.models.investor import Investor, StrategyNote, DisclosureSource
from app.models.reasoning import (
    ReasoningPillar,
    EvidenceSignal,
    SignalType,
    ConfidenceLevel,
    EvidencePanel,
    HoldingsChangeAnalysis,
)


class EvidenceBasedAnalyzer:
    """Generates evidence-based analysis for holdings"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def analyze_holding_change(
        self,
        investor_id: str,
        holding_change: HoldingsChange,
        current_snapshot: HoldingsSnapshot,
    ) -> HoldingsChangeAnalysis:
        """Analyze a specific holding change with evidence"""
        
        # Get investor info
        investor = await self.db.execute(
            select(Investor).where(Investor.id == investor_id)
        )
        investor = investor.scalar_one()
        
        # Build evidence pillars
        pillars = await self._build_reasoning_pillars(
            investor, holding_change, current_snapshot
        )
        
        # Determine unknowns
        unknowns = self._identify_unknowns(investor)
        
        return HoldingsChangeAnalysis(
            ticker=holding_change.ticker,
            company_name=holding_change.company_name,
            change_type=holding_change.change_type,
            shares_before=holding_change.shares_before,
            shares_after=holding_change.shares_after,
            shares_delta=holding_change.shares_delta,
            weight_before=holding_change.weight_before,
            weight_after=holding_change.weight_after,
            weight_delta=holding_change.weight_delta,
            value_delta=holding_change.value_delta,
            from_date=holding_change.from_date.isoformat(),
            to_date=holding_change.to_date.isoformat(),
            reasoning_pillars=pillars,
            unknowns=unknowns,
        )
    
    async def _build_reasoning_pillars(
        self,
        investor: Investor,
        change: HoldingsChange,
        snapshot: HoldingsSnapshot,
    ) -> List[ReasoningPillar]:
        """Build evidence-based reasoning pillars"""
        
        pillars = []
        
        # Pillar 1: Capital Deployment
        if change.value_delta and float(change.value_delta) != 0:
            deployment_pillar = ReasoningPillar(
                name="Capital Deployment",
                description=f"How {investor.name} is allocating capital",
                evidence_signals=[
                    {
                        "signal_type": "holdings_change",
                        "observation": self._format_capital_deployment(change),
                    }
                ],
                confidence=ConfidenceLevel.HIGH,
                key_observation=self._generate_deployment_insight(change),
            )
            pillars.append(deployment_pillar)
        
        # Pillar 2: Position Strategy
        if change.change_type in ["new", "reduced", "sold_out"]:
            strategy_pillar = ReasoningPillar(
                name="Position Strategy",
                description="Strategic shift in portfolio positioning",
                evidence_signals=[
                    {
                        "signal_type": "holdings_change",
                        "observation": self._format_position_strategy(change),
                    }
                ],
                confidence=ConfidenceLevel.HIGH,
                key_observation=self._generate_strategy_insight(investor, change),
            )
            pillars.append(strategy_pillar)
        
        # Pillar 3: Weight Management
        if change.weight_delta:
            weight_pillar = ReasoningPillar(
                name="Portfolio Weight Management",
                description="Adjustment of position relative to total portfolio",
                evidence_signals=[
                    {
                        "signal_type": "sector_concentration",
                        "observation": self._format_weight_change(change),
                    }
                ],
                confidence=ConfidenceLevel.HIGH,
                key_observation=self._generate_weight_insight(change),
            )
            pillars.append(weight_pillar)
        
        return pillars
    
    def _format_capital_deployment(self, change: HoldingsChange) -> str:
        """Format capital deployment as evidence"""
        if change.value_delta is None:
            return "No value change detected"
        
        delta = float(change.value_delta)
        direction = "increased" if delta > 0 else "decreased"
        abs_delta = abs(delta)
        
        return (
            f"{change.ticker}: Value {direction} by ${abs_delta:,.0f} "
            f"(from ${float(change.value_before or 0):,.0f} to "
            f"${float(change.value_after or 0):,.0f})"
        )
    
    def _generate_deployment_insight(self, change: HoldingsChange) -> str:
        """Generate insight about capital deployment"""
        if not change.value_delta:
            return "Position value unchanged"
        
        delta = float(change.value_delta)
        if delta > 0:
            return f"Net capital addition to {change.ticker} position"
        else:
            return f"Capital reduction from {change.ticker} position"
    
    def _format_position_strategy(self, change: HoldingsChange) -> str:
        """Format position strategy as evidence"""
        if change.change_type == "new":
            value = float(change.value_after or 0)
            return f"NEW POSITION: Entered {change.ticker} at ${value:,.0f}"
        elif change.change_type == "reduced":
            delta = float(change.shares_delta or 0)
            return f"POSITION REDUCED: Cut {change.ticker} by {abs(delta):,.0f} shares"
        elif change.change_type == "sold_out":
            return f"POSITION EXITED: Completely sold out of {change.ticker}"
        else:
            return f"POSITION ADDED: Increased {change.ticker} holdings"
    
    def _generate_strategy_insight(self, investor: Investor, change: HoldingsChange) -> str:
        """Generate insight about position strategy"""
        if change.change_type == "new":
            return f"{investor.name} believes {change.ticker} fits its investment criteria"
        elif change.change_type == "sold_out":
            return f"{investor.name} no longer sees investment case for {change.ticker}"
        elif change.change_type == "reduced":
            return f"{investor.name} is reducing conviction or rebalancing {change.ticker}"
        else:
            return f"{investor.name} is increasing commitment to {change.ticker}"
    
    def _format_weight_change(self, change: HoldingsChange) -> str:
        """Format weight change as evidence"""
        if not change.weight_delta:
            return "Portfolio weight unchanged"
        
        delta = float(change.weight_delta)
        sign = "+" if delta > 0 else ""
        
        return (
            f"{change.ticker} weight: {float(change.weight_before or 0):.2f}% → "
            f"{float(change.weight_after or 0):.2f}% ({sign}{delta:.2f}%)"
        )
    
    def _generate_weight_insight(self, change: HoldingsChange) -> str:
        """Generate insight about weight management"""
        if not change.weight_delta:
            return "Position weight maintained relative to portfolio"
        
        delta = float(change.weight_delta)
        if abs(delta) > 0.5:
            direction = "significant increase" if delta > 0 else "significant decrease"
            return f"Major reallocation: {change.ticker} weight {direction}"
        else:
            direction = "modest increase" if delta > 0 else "modest decrease"
            return f"Minor adjustment: {change.ticker} weight {direction}"
    
    def _identify_unknowns(self, investor: Investor) -> List[str]:
        """List what we don't know about investor decisions"""
        return [
            "Exact execution prices at which trades were made",
            "Specific timing of trades (only holding dates are disclosed)",
            "Investor's private reasoning or conviction level",
            "Whether this represents a long-term view or short-term adjustment",
            "Complete portfolio context (may be partial holdings data)",
            "Correlation with broader market or sector movements",
        ]


async def generate_enhanced_analysis(
    db: AsyncSession,
    investor_id: str,
    ticker: str,
    current_weight: float,
    sector: str,
) -> dict:
    """
    Generate enhanced analysis for a specific holding
    
    Returns focused, evidence-based analysis without boilerplate.
    """
    
    analyzer = EvidenceBasedAnalyzer(db)
    
    # Get disclosure sources
    investor_result = await db.execute(
        select(Investor).where(Investor.id == investor_id)
    )
    investor = investor_result.scalar_one()
    
    sources_result = await db.execute(
        select(DisclosureSource).where(DisclosureSource.investor_id == investor_id)
    )
    sources = sources_result.scalars().all()
    
    # Build evidence panel
    evidence_panel = {
        "investor_name": investor.name,
        "disclosure_sources": [
            {
                "type": s.source_type,
                "name": s.source_name,
                "frequency": s.data_granularity,
                "reporting_delay_days": s.reporting_delay_days,
            }
            for s in sources
        ],
        "data_completeness_score": 75,  # Placeholder
        "signals_used": [
            {
                "type": "holdings_data",
                "source": "SEC Form 13F",
                "observation": f"{ticker}: {current_weight:.2f}% of portfolio",
            }
        ],
        "what_we_dont_know": [
            "Execution prices and exact trade dates",
            "Investor's private reasoning",
            "Long-term vs. short-term intent",
        ],
    }
    
    return {
        "ticker": ticker,
        "company_name": f"Company {ticker}",
        "sector": sector,
        "current_weight": current_weight,
        "position_status": _determine_position_status(current_weight),
        "holding_date": datetime.utcnow().isoformat(),
        "reasoning_pillars": [
            {
                "name": "Capital Allocation",
                "description": f"How {investor.name} weights {ticker} in portfolio",
                "evidence_signals": [
                    {
                        "type": "position_size",
                        "source": "Holdings Data",
                        "observation": f"{ticker} represents {current_weight:.2f}% of portfolio",
                    }
                ],
                "confidence": "medium",
                "key_observation": _generate_position_observation(current_weight),
            }
        ],
        "risk_factors": [
            f"{sector} sector risk",
            "Concentration risk if position increases",
            "Market volatility impact",
        ],
        "evidence": evidence_panel,
        "overall_confidence": "medium",
        "key_insight": _generate_key_insight(ticker, sector, current_weight),
        "disclaimers": [
            "AI analysis based only on disclosed holdings data",
            "Does not represent investment advice",
            "Reasoning is hypothetical based on available signals",
            "Data may be delayed or incomplete",
        ],
    }


def _determine_position_status(weight: float) -> str:
    """Determine position status from weight"""
    if weight > 5:
        return "core_holding"
    elif weight > 2:
        return "significant_position"
    elif weight > 0.5:
        return "emerging"
    else:
        return "small_position"


def _generate_position_observation(weight: float) -> str:
    """Generate observation about position sizing"""
    if weight > 5:
        return "This is a significant core holding in the portfolio"
    elif weight > 2:
        return "This represents a meaningful allocation"
    else:
        return "This is a smaller position with limited portfolio impact"


def _generate_key_insight(ticker: str, sector: str, weight: float) -> str:
    """Generate key insight summary"""
    return (
        f"{ticker} ({sector}) is {_determine_position_status(weight)} "
        f"representing {weight:.2f}% of disclosed holdings"
    )
