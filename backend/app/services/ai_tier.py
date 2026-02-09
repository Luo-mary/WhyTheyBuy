"""
Tier-based AI output processing.

This module handles adapting AI outputs based on subscription tier,
gating features like:
- Number of hypotheses shown
- Evidence panel depth
- Transparency detail level

IMPORTANT PRINCIPLES:
- Do NOT sell performance or outcomes
- Higher tiers provide UNDERSTANDING, not trading advantage
- Premium = deeper insight into limitations
"""
from typing import Optional
from uuid import UUID
from sqlalchemy.orm import Session

from app.models.subscription import SubscriptionTier, TierEntitlements
from app.schemas.report import (
    AISummaryResponse,
    AICompanyRationaleResponse,
    EvidencePanel,
    EvidenceSignal,
    UnknownFactor,
    InterpretationNote,
    PossibleRationale,
    TopBuySell,
)


class TierBasedOutput:
    """
    Processes AI outputs based on subscription tier.
    
    This ensures users only see features they're entitled to,
    while maintaining a useful experience at every tier.
    """
    
    def __init__(self, tier: SubscriptionTier):
        self.tier = tier
        self.entitlements = TierEntitlements.get_entitlements(tier)
    
    # ==========================================================================
    # SUMMARY PROCESSING
    # ==========================================================================
    
    def process_summary(
        self,
        summary: AISummaryResponse,
    ) -> AISummaryResponse:
        """
        Process AI summary based on tier entitlements.
        
        Gates:
        - Number of hypotheses
        - Evidence panel visibility
        - Detail level
        """
        # Limit interpretation notes (hypotheses) based on tier
        max_hypotheses = self.entitlements.get("ai_summary_hypotheses_count", 1)
        if len(summary.interpretation_notes) > max_hypotheses:
            summary.interpretation_notes = summary.interpretation_notes[:max_hypotheses]
        
        # Process evidence panel
        if not self.entitlements.get("ai_evidence_panel_enabled", False):
            # Hide evidence panel for free tier
            summary.evidence_panel = None
        elif summary.evidence_panel:
            summary.evidence_panel = self._process_evidence_panel(summary.evidence_panel)
        
        # Limit top buys/sells for free tier
        if self.tier == SubscriptionTier.FREE:
            summary.top_buys = summary.top_buys[:3]
            summary.top_sells = summary.top_sells[:3]
            summary.observations = summary.observations[:2]
        
        return summary
    
    def process_rationale(
        self,
        rationale: AICompanyRationaleResponse,
    ) -> AICompanyRationaleResponse | None:
        """
        Process company rationale based on tier entitlements.
        
        Returns None if user doesn't have access to company rationale.
        """
        # Check if company rationale is enabled
        if not self.entitlements.get("ai_company_rationale_enabled", False):
            return None
        
        # Limit possible rationales
        max_hypotheses = self.entitlements.get("ai_summary_hypotheses_count", 1)
        if len(rationale.possible_rationales) > max_hypotheses:
            rationale.possible_rationales = rationale.possible_rationales[:max_hypotheses]
        
        # Process evidence panel
        if not self.entitlements.get("ai_evidence_panel_enabled", False):
            rationale.evidence_panel = None
        elif rationale.evidence_panel:
            rationale.evidence_panel = self._process_evidence_panel(rationale.evidence_panel)
        
        return rationale
    
    # ==========================================================================
    # EVIDENCE PANEL PROCESSING
    # ==========================================================================
    
    def _process_evidence_panel(self, panel: EvidencePanel) -> EvidencePanel:
        """
        Process evidence panel based on tier.
        
        Higher tiers see:
        - More signals
        - Auto-expanded panel
        - Full signal details
        """
        # Determine if should auto-expand based on tier
        if self.entitlements.get("evidence_panel_auto_expand", False):
            panel.should_auto_expand = True
        
        # For Pro tier, limit signals shown (Pro+ gets all)
        if self.tier == SubscriptionTier.PRO:
            # Show up to 10 signals
            if len(panel.signals_used) > 10:
                panel.signals_used = panel.signals_used[:10]
                panel.signals_unavailable = panel.signals_unavailable + [
                    f"+ {len(panel.signals_used) - 10} more signals (upgrade for full access)"
                ]
        
        # Pro+ gets everything
        # (no modification needed)
        
        return panel
    
    # ==========================================================================
    # TRANSPARENCY PROCESSING
    # ==========================================================================
    
    def process_transparency(
        self,
        score: int | None,
        label: str | None,
        explanation: str | None,
        dimensions: dict | None,
    ) -> dict:
        """
        Process transparency information based on tier.
        
        FREE: Label only (High/Medium/Low)
        PRO: Score + explanation
        PRO+: Full dimension breakdown
        """
        result = {}
        
        # Always show label
        result["label"] = label
        
        # Score visibility
        if self.entitlements.get("transparency_score_visible", False):
            result["score"] = score
        else:
            result["score"] = None
        
        # Explanation visibility
        if self.entitlements.get("transparency_explanation_visible", False):
            result["explanation"] = explanation
        else:
            result["explanation"] = None
        
        # Dimensions visibility (Pro+ only)
        if self.entitlements.get("transparency_dimensions_visible", False):
            result["dimensions"] = dimensions
        else:
            result["dimensions"] = None
        
        # Add upgrade hint for lower tiers
        if self.tier == SubscriptionTier.FREE:
            result["upgrade_hint"] = "Upgrade to Pro for full transparency scores and explanations"
        elif self.tier == SubscriptionTier.PRO:
            result["upgrade_hint"] = "Upgrade to Pro+ for complete transparency dimension breakdown"
        else:
            result["upgrade_hint"] = None
        
        return result
    
    # ==========================================================================
    # HISTORY GATING
    # ==========================================================================
    
    def get_history_limit_date(self) -> int:
        """Get the number of days of history this tier can access."""
        return self.entitlements.get("history_days", 7)
    
    def can_access_date(self, days_ago: int) -> bool:
        """Check if this tier can access data from N days ago."""
        history_days = self.get_history_limit_date()
        if history_days == -1:  # Unlimited
            return True
        return days_ago <= history_days


# =============================================================================
# TIER-GATED RESPONSE BUILDERS
# =============================================================================

def build_gated_summary_response(
    summary: AISummaryResponse,
    tier: SubscriptionTier,
    include_evidence: bool = True,
) -> dict:
    """
    Build a tier-gated summary response.
    
    This is the main entry point for creating tier-appropriate responses.
    """
    processor = TierBasedOutput(tier)
    processed = processor.process_summary(summary)
    
    response = {
        "headline": processed.headline,
        "what_changed": processed.what_changed,
        "top_buys": [b.model_dump() for b in processed.top_buys],
        "top_sells": [s.model_dump() for s in processed.top_sells],
        "observations": processed.observations,
        "interpretation_notes": [
            {
                "note": n.note,
                "confidence": n.confidence,
                "evidence_ids": n.evidence_ids if include_evidence else [],
            }
            for n in processed.interpretation_notes
        ],
        "limitations": processed.limitations,
        "disclaimer": processed.disclaimer,
    }
    
    # Include evidence panel if entitled and requested
    if include_evidence and processed.evidence_panel:
        response["evidence_panel"] = {
            "signals_used": [
                {
                    "signal_id": s.signal_id,
                    "category": s.category.value if hasattr(s.category, 'value') else s.category,
                    "description": s.description,
                    "source": s.source,
                    "value": s.value,
                }
                for s in processed.evidence_panel.signals_used
            ],
            "unknowns": [
                {
                    "unknown_id": u.unknown_id,
                    "description": u.description,
                    "is_standard": u.is_standard,
                    "impact": u.impact,
                }
                for u in processed.evidence_panel.unknowns
            ],
            "evidence_completeness": processed.evidence_panel.evidence_completeness,
            "evidence_completeness_note": processed.evidence_panel.evidence_completeness_note,
            "signals_unavailable": processed.evidence_panel.signals_unavailable,
            "transparency_context": processed.evidence_panel.transparency_context,
            "should_auto_expand": processed.evidence_panel.should_auto_expand,
        }
    else:
        response["evidence_panel"] = None
        if tier == SubscriptionTier.FREE:
            response["evidence_panel_upgrade_hint"] = (
                "Upgrade to Pro to see what evidence AI used for this analysis"
            )
    
    return response


def build_gated_rationale_response(
    rationale: AICompanyRationaleResponse,
    tier: SubscriptionTier,
) -> dict | None:
    """
    Build a tier-gated company rationale response.
    
    Returns None if tier doesn't have access to company rationale.
    """
    processor = TierBasedOutput(tier)
    processed = processor.process_rationale(rationale)
    
    if processed is None:
        return None
    
    response = {
        "company_overview": processed.company_overview,
        "investor_activity_summary": processed.investor_activity_summary,
        "possible_rationales": [
            {
                "hypothesis": r.hypothesis,
                "supporting_signals": r.supporting_signals,
                "evidence_ids": r.evidence_ids,
                "confidence": r.confidence,
            }
            for r in processed.possible_rationales
        ],
        "patterns_vs_history": processed.patterns_vs_history,
        "what_is_unknown": processed.what_is_unknown,
        "disclaimer": processed.disclaimer,
    }
    
    # Include evidence panel if available
    if processed.evidence_panel:
        response["evidence_panel"] = {
            "signals_used": [
                {
                    "signal_id": s.signal_id,
                    "category": s.category.value if hasattr(s.category, 'value') else s.category,
                    "description": s.description,
                    "source": s.source,
                    "value": s.value,
                }
                for s in processed.evidence_panel.signals_used
            ],
            "unknowns": [
                {
                    "unknown_id": u.unknown_id,
                    "description": u.description,
                    "is_standard": u.is_standard,
                    "impact": u.impact,
                }
                for u in processed.evidence_panel.unknowns
            ],
            "evidence_completeness": processed.evidence_panel.evidence_completeness,
            "evidence_completeness_note": processed.evidence_panel.evidence_completeness_note,
            "signals_unavailable": processed.evidence_panel.signals_unavailable,
            "transparency_context": processed.evidence_panel.transparency_context,
            "should_auto_expand": processed.evidence_panel.should_auto_expand,
        }
    else:
        response["evidence_panel"] = None
    
    return response


def get_tier_feature_hints(tier: SubscriptionTier) -> dict:
    """
    Get upgrade hints and feature explanations for a tier.
    
    Helps users understand what they're missing and why
    higher tiers provide more UNDERSTANDING (not performance).
    """
    if tier == SubscriptionTier.FREE:
        return {
            "current_tier": "free",
            "upgrade_available": True,
            "hints": [
                {
                    "feature": "Evidence Panel",
                    "message": "See exactly what evidence AI uses - upgrade to Pro",
                    "tier_required": "pro",
                },
                {
                    "feature": "Transparency Score",
                    "message": "See the full 0-100 transparency score - upgrade to Pro",
                    "tier_required": "pro",
                },
                {
                    "feature": "Multiple Hypotheses",
                    "message": "Get 3 possible interpretations instead of 1 - upgrade to Pro",
                    "tier_required": "pro",
                },
                {
                    "feature": "Company Analysis",
                    "message": "Get AI analysis for specific companies - upgrade to Pro",
                    "tier_required": "pro",
                },
            ],
            "value_message": (
                "Pro helps you understand limitations better. "
                "It does NOT promise better trading outcomes."
            ),
        }
    
    elif tier == SubscriptionTier.PRO:
        return {
            "current_tier": "pro",
            "upgrade_available": True,
            "hints": [
                {
                    "feature": "Transparency Dimensions",
                    "message": "See the complete 4-dimension transparency breakdown - upgrade to Pro+",
                    "tier_required": "pro_plus",
                },
                {
                    "feature": "Cross-Investor Insights",
                    "message": "See which investors hold the same stocks - upgrade to Pro+",
                    "tier_required": "pro_plus",
                },
                {
                    "feature": "Real-Time Alerts",
                    "message": "Get instant notifications for daily disclosures - upgrade to Pro+",
                    "tier_required": "pro_plus",
                },
                {
                    "feature": "Data Export",
                    "message": "Export data for your own analysis - upgrade to Pro+",
                    "tier_required": "pro_plus",
                },
            ],
            "value_message": (
                "Pro+ provides institutional-grade disclosure analysis. "
                "More depth, not more trading advice."
            ),
        }
    
    else:  # PRO_PLUS
        return {
            "current_tier": "pro_plus",
            "upgrade_available": False,
            "hints": [],
            "value_message": (
                "You have full access to all disclosure analysis features. "
                "Remember: This helps you understand limitations, not predict outcomes."
            ),
        }
