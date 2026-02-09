"""
Tests for AI service - focusing on compliance and no-hallucination guardrails.

COMPLIANCE TEST FOCUS:
- All outputs are descriptive, historical, hypothetical
- No predictive or advisory language
- No assumption of investor intent
- Proper disclaimers and limitations
"""
import pytest
import json
from unittest.mock import AsyncMock, patch, MagicMock
from decimal import Decimal
from datetime import date

from app.services.ai import (
    generate_investor_summary,
    generate_company_rationale,
    INVESTOR_SUMMARY_PROMPT,
    COMPANY_RATIONALE_PROMPT,
    AI_SYSTEM_PROMPT,
)
from app.schemas.report import (
    AISummaryResponse,
    AICompanyRationaleResponse,
    InterpretationNote,
    PossibleRationale,
    AIOutputValidator,
)


class TestAISystemPromptCompliance:
    """Tests for AI system prompt compliance rules."""
    
    def test_system_prompt_is_not_advisory(self):
        """Verify system prompt explicitly states no investment advice."""
        assert "do NOT provide investment advice" in AI_SYSTEM_PROMPT
        assert "do NOT know why they traded" in AI_SYSTEM_PROMPT.upper() or \
               "do not know why they traded" in AI_SYSTEM_PROMPT.lower()
        assert "hypothetical" in AI_SYSTEM_PROMPT.lower()
        assert "informational" in AI_SYSTEM_PROMPT.lower()
    
    def test_system_prompt_forbids_predictions(self):
        """Verify system prompt forbids predictions."""
        assert "NEVER predict" in AI_SYSTEM_PROMPT
        assert "NEVER recommend" in AI_SYSTEM_PROMPT


class TestInvestorSummaryPromptCompliance:
    """Tests for investor summary prompt compliance."""
    
    def test_prompt_requires_grounding(self):
        """Verify prompt requires grounding on provided data only."""
        assert "ONLY describe what is explicitly in the provided data" in INVESTOR_SUMMARY_PROMPT
        assert "Do NOT infer trading motivations" in INVESTOR_SUMMARY_PROMPT
    
    def test_prompt_enforces_low_confidence(self):
        """Verify prompt never allows high confidence claims."""
        assert "NEVER claim high confidence" in INVESTOR_SUMMARY_PROMPT
        assert "low or medium confidence" in INVESTOR_SUMMARY_PROMPT.lower()
    
    def test_prompt_requires_disclaimer(self):
        """Verify prompt requires disclaimer."""
        assert "disclaimer" in INVESTOR_SUMMARY_PROMPT.lower()
        assert "limitations" in INVESTOR_SUMMARY_PROMPT.lower()


class TestCompanyRationalePromptCompliance:
    """Tests for company rationale prompt compliance."""
    
    def test_prompt_frames_as_hypotheses(self):
        """Verify prompt frames all explanations as hypotheses."""
        assert "do NOT know the investor's true intent" in COMPANY_RATIONALE_PROMPT
        assert "ALL explanations are HYPOTHESES" in COMPANY_RATIONALE_PROMPT
    
    def test_prompt_forbids_recommendations(self):
        """Verify prompt forbids recommendations."""
        assert "NEVER predict price movements" in COMPANY_RATIONALE_PROMPT
        assert "NEVER recommend actions" in COMPANY_RATIONALE_PROMPT
    
    def test_prompt_requires_unknown_statement(self):
        """Verify prompt requires stating what is unknown."""
        assert "what is unknown" in COMPANY_RATIONALE_PROMPT.lower()


class TestAISummarySchemaCompliance:
    """Tests for AI summary schema compliance."""
    
    def test_schema_has_required_fields(self):
        """Test that schema has all required compliance fields."""
        expected_fields = {
            "headline",
            "what_changed",
            "top_buys",
            "top_sells",
            "observations",
            "interpretation_notes",
            "limitations",
            "disclaimer",
        }
        actual_fields = set(AISummaryResponse.model_fields.keys())
        assert expected_fields == actual_fields
    
    def test_summary_requires_disclaimer(self):
        """Test that summary requires disclaimer."""
        summary = AISummaryResponse(
            headline="Test Headline",
            what_changed=["Change 1"],
            top_buys=[],
            top_sells=[],
            observations=[],
            interpretation_notes=[],
            limitations="We don't know the reasoning.",
            disclaimer="This is not investment advice.",
        )
        
        assert "advice" in summary.disclaimer.lower()
    
    def test_summary_requires_limitations(self):
        """Test that summary includes limitations."""
        summary = AISummaryResponse(
            headline="Test",
            what_changed=[],
            limitations="We do not know the investor's actual reasoning.",
            disclaimer="Not investment advice.",
        )
        
        assert "reasoning" in summary.limitations.lower()


class TestInterpretationNoteCompliance:
    """Tests for interpretation note compliance."""
    
    def test_confidence_cannot_be_high(self):
        """Test that confidence cannot be 'high'."""
        with pytest.raises(ValueError) as exc_info:
            InterpretationNote(
                note="Test note",
                confidence="high",
            )
        
        assert "high" in str(exc_info.value).lower()
    
    def test_valid_confidence_levels(self):
        """Test valid confidence levels."""
        low = InterpretationNote(note="Test", confidence="low")
        medium = InterpretationNote(note="Test", confidence="medium")
        
        assert low.confidence == "low"
        assert medium.confidence == "medium"


class TestPossibleRationaleCompliance:
    """Tests for possible rationale compliance."""
    
    def test_confidence_cannot_be_high(self):
        """Test that confidence cannot be 'high' for rationales."""
        with pytest.raises(ValueError):
            PossibleRationale(
                hypothesis="Test hypothesis",
                supporting_signals=["Signal 1"],
                confidence="high",
            )
    
    def test_requires_supporting_signals(self):
        """Test that rationales require supporting signals."""
        with pytest.raises(ValueError):
            PossibleRationale(
                hypothesis="Test hypothesis",
                supporting_signals=[],  # Empty list should fail
                confidence="low",
            )
    
    def test_valid_rationale(self):
        """Test valid rationale construction."""
        rationale = PossibleRationale(
            hypothesis="The investor may be dollar-cost averaging",
            supporting_signals=[
                "Previous buys at similar price levels",
                "Strategy note [ARK-001] mentions long-term approach",
            ],
            confidence="low",
        )
        
        assert rationale.confidence == "low"
        assert len(rationale.supporting_signals) >= 1


class TestAICompanyRationaleSchemaCompliance:
    """Tests for AI company rationale schema compliance."""
    
    def test_schema_has_required_fields(self):
        """Test that schema has all required compliance fields."""
        expected_fields = {
            "company_overview",
            "investor_activity_summary",
            "possible_rationales",
            "patterns_vs_history",
            "what_is_unknown",
            "disclaimer",
        }
        actual_fields = set(AICompanyRationaleResponse.model_fields.keys())
        assert expected_fields == actual_fields
    
    def test_rationale_requires_disclaimer(self):
        """Test that rationale requires disclaimer."""
        rationale = AICompanyRationaleResponse(
            company_overview="Test company",
            investor_activity_summary="Bought shares",
            possible_rationales=[],
            patterns_vs_history="Consistent with past behavior.",
            what_is_unknown="We do not know the actual reasoning.",
            disclaimer="Informational only, not investment advice.",
        )
        
        assert "advice" in rationale.disclaimer.lower()
    
    def test_rationale_requires_what_is_unknown(self):
        """Test that rationale includes what is unknown."""
        rationale = AICompanyRationaleResponse(
            company_overview="Test",
            investor_activity_summary="Bought",
            possible_rationales=[],
            patterns_vs_history="",
            what_is_unknown="We do not know the exact execution prices, the investor's private reasoning, or future intentions.",
            disclaimer="Not advice.",
        )
        
        assert "do not know" in rationale.what_is_unknown.lower()


class TestAIOutputValidator:
    """Tests for AI output validation."""
    
    def test_detects_advisory_language(self):
        """Test that validator detects advisory language."""
        is_valid, violations = AIOutputValidator.validate_no_advisory_language(
            "You should buy TSLA because it will increase in value."
        )
        
        assert not is_valid
        assert len(violations) > 0
    
    def test_passes_descriptive_language(self):
        """Test that validator passes descriptive language."""
        is_valid, violations = AIOutputValidator.validate_no_advisory_language(
            "The investor disclosed purchasing 10,000 shares of TSLA."
        )
        
        assert is_valid
        assert len(violations) == 0
    
    def test_detects_forbidden_phrases(self):
        """Test detection of specific forbidden phrases."""
        forbidden_texts = [
            "We recommend buying",
            "The price will increase",
            "Guaranteed returns",
            "Buy now while it's cheap",
            "This is a great opportunity to sell",
        ]
        
        for text in forbidden_texts:
            is_valid, violations = AIOutputValidator.validate_no_advisory_language(text)
            assert not is_valid, f"Should have detected: {text}"
    
    def test_validates_disclaimer(self):
        """Test disclaimer validation."""
        valid_disclaimer = "This is not investment advice."
        invalid_disclaimer = "Thanks for reading!"
        
        assert AIOutputValidator.validate_disclaimer_present(valid_disclaimer)
        assert not AIOutputValidator.validate_disclaimer_present(invalid_disclaimer)
    
    def test_validates_summary_response(self):
        """Test full summary response validation."""
        # Valid response
        valid_response = AISummaryResponse(
            headline="ARK disclosed Tesla purchases",
            what_changed=["Added 15,000 TSLA shares"],
            top_buys=[],
            top_sells=[],
            observations=["Accumulation pattern observed"],
            interpretation_notes=[
                InterpretationNote(note="May indicate conviction", confidence="low")
            ],
            limitations="We do not know the actual reasoning.",
            disclaimer="This is not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_summary_response(valid_response)
        assert is_valid, f"Unexpected errors: {errors}"
    
    def test_rejects_advisory_summary(self):
        """Test that advisory language in summary is rejected."""
        bad_response = AISummaryResponse(
            headline="You should buy TSLA now!",  # Advisory language
            what_changed=["Price will increase"],
            top_buys=[],
            top_sells=[],
            observations=[],
            interpretation_notes=[],
            limitations="",
            disclaimer="This is not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_summary_response(bad_response)
        assert not is_valid
        assert len(errors) > 0


class TestAIGenerationFallbacks:
    """Tests for AI generation fallback behavior."""
    
    @pytest.mark.asyncio
    async def test_summary_fallback_on_invalid_json(self):
        """Test that invalid AI response returns safe fallback."""
        # Create mock investor and changes
        class MockInvestor:
            name = "Test Fund"
            category = MagicMock()
            category.value = "daily_etf"
        
        class MockChange:
            ticker = "AAPL"
            company_name = "Apple Inc."
            change_type = MagicMock()
            change_type.value = "added"
            to_date = date.today()
            shares_delta = Decimal("100")
            weight_delta = Decimal("0.5")
            price_range_low = Decimal("150")
            price_range_high = Decimal("160")
        
        with patch("app.services.ai.call_ai", new_callable=AsyncMock) as mock_ai:
            # Return invalid JSON
            mock_ai.return_value = "This is not valid JSON"
            
            result = await generate_investor_summary(MockInvestor(), [MockChange()])
            
            # Should return safe fallback
            assert result.headline is not None
            assert "advice" in result.disclaimer.lower()
            assert len(result.limitations) > 0
    
    @pytest.mark.asyncio
    async def test_summary_fallback_has_disclaimer(self):
        """Test that fallback always includes disclaimer."""
        class MockInvestor:
            name = "Test Fund"
            category = MagicMock()
            category.value = "daily_etf"
        
        with patch("app.services.ai.call_ai", new_callable=AsyncMock) as mock_ai:
            mock_ai.return_value = "{invalid json"
            
            result = await generate_investor_summary(MockInvestor(), [])
            
            assert "advice" in result.disclaimer.lower() or "not" in result.disclaimer.lower()


class TestDataGrounding:
    """Tests to ensure AI outputs are grounded in provided data."""
    
    def test_summary_format_matches_spec(self):
        """Test that AI summary format matches the required spec."""
        expected_fields = {
            "headline",
            "what_changed",
            "top_buys",
            "top_sells",
            "observations",
            "interpretation_notes",
            "limitations",
            "disclaimer",
        }
        
        actual_fields = set(AISummaryResponse.model_fields.keys())
        assert expected_fields == actual_fields
    
    def test_rationale_format_matches_spec(self):
        """Test that AI rationale format matches the required spec."""
        expected_fields = {
            "company_overview",
            "investor_activity_summary",
            "possible_rationales",
            "patterns_vs_history",
            "what_is_unknown",
            "disclaimer",
        }
        
        actual_fields = set(AICompanyRationaleResponse.model_fields.keys())
        assert expected_fields == actual_fields


class TestMarketPriceRangeLabeling:
    """Tests to ensure market price ranges are properly labeled."""
    
    def test_prompt_clarifies_price_range(self):
        """Ensure prompts clarify that price ranges are NOT execution prices."""
        assert "NOT execution price" in COMPANY_RATIONALE_PROMPT or \
               "not execution price" in COMPANY_RATIONALE_PROMPT.lower()
        
        # Summary prompt should label as market price range
        assert "market_price_range" in INVESTOR_SUMMARY_PROMPT.lower() or \
               "market price range" in INVESTOR_SUMMARY_PROMPT.lower()
