"""
Tests for the Evidence Panel and AI output validation system.

These tests ensure:
- Evidence signals are properly tracked
- AI outputs are validated against provided signals
- Standard unknowns are always included
- Confidence levels match evidence completeness
- Advisory language is rejected
"""
import pytest
from app.schemas.report import (
    EvidenceSignal,
    EvidencePanel,
    EvidenceBuilder,
    UnknownFactor,
    SignalCategory,
    StandardUnknown,
    AISummaryResponse,
    AICompanyRationaleResponse,
    InterpretationNote,
    PossibleRationale,
    TopBuySell,
    AIOutputValidator,
)


class TestEvidenceBuilder:
    """Tests for the EvidenceBuilder class."""
    
    def test_add_signals(self):
        """Test adding various signal types."""
        builder = EvidenceBuilder()
        
        # Add different signal types
        holdings_id = builder.add_holdings_signal(
            signal_id="CHG_001",
            description="Added 1000 shares of TSLA",
            source="ETF Holdings, 2024-01-15",
            value="TSLA: +1000",
        )
        
        price_id = builder.add_price_signal(
            signal_id="PRC_001",
            description="TSLA market price range",
            source="Market data, 2024-01-15",
            value="$180 - $195",
        )
        
        company_id = builder.add_company_signal(
            signal_id="COMP_001",
            description="Tesla Inc.",
            source="Company profile database",
        )
        
        assert holdings_id == "CHG_001"
        assert price_id == "PRC_001"
        assert company_id == "COMP_001"
        
        # Check signals are tracked
        signal_ids = builder.get_signal_ids()
        assert "CHG_001" in signal_ids
        assert "PRC_001" in signal_ids
        assert "COMP_001" in signal_ids
        assert len(signal_ids) == 3
    
    def test_build_panel_with_standard_unknowns(self):
        """Test that panels include standard unknowns."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal(
            signal_id="CHG_001",
            description="Test change",
            source="Test source",
        )
        
        panel = builder.build_panel(transparency_score=70)
        
        # Check standard unknowns are present
        standard_unknown_ids = {u.unknown_id for u in panel.unknowns if u.is_standard}
        assert StandardUnknown.EXECUTION_PRICE.value in standard_unknown_ids
        assert StandardUnknown.EXECUTION_TIMING.value in standard_unknown_ids
        assert StandardUnknown.INVESTOR_REASONING.value in standard_unknown_ids
        assert StandardUnknown.FUTURE_INTENTIONS.value in standard_unknown_ids
    
    def test_evidence_completeness_assessment(self):
        """Test evidence completeness scoring."""
        # Insufficient evidence (< 2 signals)
        builder1 = EvidenceBuilder()
        builder1.add_holdings_signal("S1", "Test", "Source")
        panel1 = builder1.build_panel()
        assert panel1.evidence_completeness == "insufficient"
        
        # Limited evidence (2-4 signals)
        builder2 = EvidenceBuilder()
        builder2.add_holdings_signal("S1", "Test", "Source")
        builder2.add_holdings_signal("S2", "Test", "Source")
        panel2 = builder2.build_panel()
        assert panel2.evidence_completeness == "limited"
        
        # Sufficient evidence (5+ signals)
        builder3 = EvidenceBuilder()
        for i in range(5):
            builder3.add_holdings_signal(f"S{i}", "Test", "Source")
        panel3 = builder3.build_panel()
        assert panel3.evidence_completeness == "sufficient"
    
    def test_auto_expand_for_low_transparency(self):
        """Test that panel auto-expands for low transparency."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal("S1", "Test", "Source")
        
        # High transparency - no auto expand
        panel_high = builder.build_panel(transparency_score=80)
        assert not panel_high.should_auto_expand
        
        # Low transparency - auto expand
        panel_low = builder.build_panel(transparency_score=30)
        assert panel_low.should_auto_expand
    
    def test_signals_for_prompt_format(self):
        """Test the prompt format for AI."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal("CHG_001", "Added TSLA", "ETF", "TSLA: +1000")
        builder.add_price_signal("PRC_001", "TSLA price", "Market", "$180-195")
        
        prompt_text = builder.get_signals_for_prompt()
        
        assert "AVAILABLE SIGNALS" in prompt_text
        assert "CHG_001" in prompt_text
        assert "PRC_001" in prompt_text
        assert "holdings_data" in prompt_text
        assert "price_data" in prompt_text
        assert "You may ONLY reference" in prompt_text


class TestAIOutputValidator:
    """Tests for AI output validation."""
    
    def test_validate_no_advisory_language(self):
        """Test detection of forbidden advisory phrases."""
        # Clean text
        clean_text = "Tesla added 1000 shares to their position."
        is_valid, violations = AIOutputValidator.validate_no_advisory_language(clean_text)
        assert is_valid
        assert len(violations) == 0
        
        # Advisory text
        advisory_texts = [
            "You should buy TSLA now.",
            "We recommend selling this stock.",
            "The price will increase significantly.",
            "This is guaranteed to rise.",
        ]
        
        for text in advisory_texts:
            is_valid, violations = AIOutputValidator.validate_no_advisory_language(text)
            assert not is_valid, f"Should detect advisory language in: {text}"
            assert len(violations) > 0
    
    def test_validate_disclaimer_present(self):
        """Test disclaimer validation."""
        # Valid disclaimer
        assert AIOutputValidator.validate_disclaimer_present(
            "This is not investment advice."
        )
        assert AIOutputValidator.validate_disclaimer_present(
            "Informational only, not advice."
        )
        
        # Invalid disclaimer (missing keywords)
        assert not AIOutputValidator.validate_disclaimer_present(
            "For informational purposes only."
        )
    
    def test_validate_evidence_references(self):
        """Test that AI output only references provided signals."""
        provided_signals = {"CHG_001", "CHG_002", "PRC_001"}
        
        # Valid response - all references exist
        valid_response = AISummaryResponse(
            headline="Test headline",
            what_changed=["Change 1"],
            interpretation_notes=[
                InterpretationNote(
                    note="Test note",
                    confidence="low",
                    evidence_ids=["CHG_001", "CHG_002"],
                ),
            ],
            evidence_panel=EvidencePanel.create_with_standard_unknowns(
                signals_used=[
                    EvidenceSignal(
                        signal_id="CHG_001",
                        category=SignalCategory.HOLDINGS_DATA,
                        description="Test",
                        source="Test",
                    ),
                ],
            ),
            disclaimer="This is not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_evidence_references(
            valid_response, provided_signals
        )
        assert is_valid
        
        # Invalid response - references non-existent signal
        invalid_response = AISummaryResponse(
            headline="Test headline",
            what_changed=["Change 1"],
            interpretation_notes=[
                InterpretationNote(
                    note="Test note",
                    confidence="low",
                    evidence_ids=["CHG_001", "FAKE_SIGNAL"],  # FAKE_SIGNAL not provided
                ),
            ],
            disclaimer="This is not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_evidence_references(
            invalid_response, provided_signals
        )
        assert not is_valid
        assert any("FAKE_SIGNAL" in e for e in errors)
    
    def test_validate_standard_unknowns_present(self):
        """Test that standard unknowns must be present."""
        # Valid - has standard unknowns
        valid_panel = EvidencePanel.create_with_standard_unknowns(signals_used=[])
        is_valid, errors = AIOutputValidator.validate_has_standard_unknowns(valid_panel)
        assert is_valid
        
        # Invalid - missing standard unknowns
        invalid_panel = EvidencePanel(
            signals_used=[],
            unknowns=[
                UnknownFactor(
                    unknown_id="custom_unknown",
                    description="Custom unknown",
                    is_standard=False,
                ),
            ],
        )
        is_valid, errors = AIOutputValidator.validate_has_standard_unknowns(invalid_panel)
        assert not is_valid
        assert "Missing standard unknowns" in str(errors)
    
    def test_validate_confidence_matches_evidence(self):
        """Test that confidence levels match evidence completeness."""
        # Insufficient evidence with medium confidence should fail
        insufficient_panel = EvidencePanel(
            signals_used=[],
            unknowns=[],
            evidence_completeness="insufficient",
        )
        
        invalid_response = AISummaryResponse(
            headline="Test",
            what_changed=[],
            interpretation_notes=[
                InterpretationNote(
                    note="Test",
                    confidence="medium",  # Should be 'low' for insufficient evidence
                    evidence_ids=[],
                ),
            ],
            evidence_panel=insufficient_panel,
            disclaimer="This is not advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_confidence_matches_evidence(
            invalid_response
        )
        assert not is_valid
        assert "insufficient evidence" in str(errors).lower()
    
    def test_full_summary_validation(self):
        """Test complete validation of AI summary response."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal("CHG_001", "Test change", "Test source")
        builder.add_holdings_signal("CHG_002", "Test change 2", "Test source")
        
        valid_response = AISummaryResponse(
            headline="Investor updated positions",
            what_changed=["Added to technology positions"],
            top_buys=[
                TopBuySell(ticker="TSLA", name="Tesla", change="+1000 shares"),
            ],
            observations=["Tech sector focus observed"],
            interpretation_notes=[
                InterpretationNote(
                    note="May indicate conviction in EV sector",
                    confidence="low",
                    evidence_ids=["CHG_001"],
                ),
            ],
            evidence_panel=builder.build_panel(transparency_score=70),
            limitations="We do not know the investor's actual reasoning.",
            disclaimer="This is not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_summary_response(
            valid_response, builder.get_signal_ids()
        )
        assert is_valid, f"Validation failed: {errors}"


class TestRationaleValidation:
    """Tests for company rationale validation."""
    
    def test_rationale_requires_supporting_signals(self):
        """Test that rationales must have supporting signals."""
        # Valid rationale with supporting signals
        valid_rationale = PossibleRationale(
            hypothesis="Investor may be adding to tech exposure",
            supporting_signals=["Added 1000 shares based on disclosure"],
            evidence_ids=["CHG_001"],
            confidence="low",
        )
        
        # This should raise validation error (no supporting signals)
        with pytest.raises(ValueError):
            PossibleRationale(
                hypothesis="Invalid rationale",
                supporting_signals=[],  # Empty - should fail
                confidence="low",
            )
    
    def test_confidence_cannot_be_high(self):
        """Test that high confidence is never allowed."""
        with pytest.raises(ValueError):
            InterpretationNote(
                note="Test note",
                confidence="high",  # Should fail
            )
        
        with pytest.raises(ValueError):
            PossibleRationale(
                hypothesis="Test",
                supporting_signals=["Test signal"],
                confidence="high",  # Should fail
            )
    
    def test_full_rationale_validation(self):
        """Test complete validation of company rationale response."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal("CHG_001", "Bought TSLA", "13F Filing")
        builder.add_company_signal("COMP_001", "Tesla Inc.", "Profile DB")
        
        valid_response = AICompanyRationaleResponse(
            company_overview="Tesla Inc. is an electric vehicle manufacturer.",
            investor_activity_summary="Added 1000 shares per Q3 2024 13F filing.",
            possible_rationales=[
                PossibleRationale(
                    hypothesis="May reflect conviction in EV market growth",
                    supporting_signals=["Added shares during Q3", "Previous history of EV investments"],
                    evidence_ids=["CHG_001"],
                    confidence="low",
                ),
            ],
            patterns_vs_history="Consistent with previous quarterly additions.",
            evidence_panel=builder.build_panel(transparency_score=45),
            what_is_unknown="We do not know the exact execution prices or investor's reasoning.",
            disclaimer="Informational only, not investment advice.",
        )
        
        is_valid, errors = AIOutputValidator.validate_rationale_response(
            valid_response, builder.get_signal_ids()
        )
        assert is_valid, f"Validation failed: {errors}"


class TestEdgeCases:
    """Test edge cases and boundary conditions."""
    
    def test_empty_signals(self):
        """Test handling of empty signal lists."""
        builder = EvidenceBuilder()
        panel = builder.build_panel()
        
        assert panel.evidence_completeness == "insufficient"
        assert panel.should_auto_expand  # Should auto-expand when evidence is insufficient
    
    def test_transparency_score_boundaries(self):
        """Test transparency score edge values."""
        builder = EvidenceBuilder()
        builder.add_holdings_signal("S1", "Test", "Source")
        
        # Exactly at boundary
        panel_70 = builder.build_panel(transparency_score=70)
        assert panel_70.transparency_context is not None
        assert "High" in panel_70.transparency_context
        
        panel_40 = builder.build_panel(transparency_score=40)
        assert "Medium" in panel_40.transparency_context
        
        panel_39 = builder.build_panel(transparency_score=39)
        assert "Low" in panel_39.transparency_context
    
    def test_very_long_signal_description(self):
        """Test handling of very long signal descriptions."""
        builder = EvidenceBuilder()
        long_description = "A" * 1000
        
        builder.add_holdings_signal(
            signal_id="LONG_001",
            description=long_description,
            source="Test source",
        )
        
        # Should not raise error
        prompt_text = builder.get_signals_for_prompt()
        assert "LONG_001" in prompt_text


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
