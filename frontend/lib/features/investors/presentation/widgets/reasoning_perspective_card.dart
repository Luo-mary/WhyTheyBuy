import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/reasoning_card.dart';

/// Professional stock analysis card with Bloomberg Terminal-inspired aesthetic.
///
/// Features:
/// - Large, readable typography optimized for financial data
/// - Sharp accent colors with subtle glow effects
/// - Expandable evidence section with clickable links
/// - Special layouts for Bull vs Bear (with verdict) and News Sentiment cards
class ReasoningPerspectiveCard extends StatefulWidget {
  final ReasoningCard card;

  const ReasoningPerspectiveCard({
    super.key,
    required this.card,
  });

  @override
  State<ReasoningPerspectiveCard> createState() =>
      _ReasoningPerspectiveCardState();
}

class _ReasoningPerspectiveCardState extends State<ReasoningPerspectiveCard>
    with SingleTickerProviderStateMixin {
  bool _evidenceExpanded = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Professional dark theme colors
  static const _cardBackground = Color(0xFF1A1D26);
  static const _cardBorder = Color(0xFF2D3241);
  static const _textPrimary = Color(0xFFE8ECF4);
  static const _textSecondary = Color(0xFF9CA3B4);
  static const _textMuted = Color(0xFF6B7280);

  // Accent colors for different perspectives
  static const _bullishGreen = Color(0xFF00D084);
  static const _bearishRed = Color(0xFFFF6B6B);
  static const _warningAmber = Color(0xFFFFB020);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isWideScreen ? 12 : 6,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: card.accentColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              // Subtle glow effect matching accent color
              BoxShadow(
                color: card.accentColor.withValues(alpha: _glowAnimation.value * 0.15),
                blurRadius: 24,
                spreadRadius: -4,
              ),
              // Depth shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  card.accentColor.withValues(alpha: 0.8),
                  card.accentColor.withValues(alpha: 0.4),
                  card.accentColor.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isWideScreen ? 24 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(card, isWideScreen),
                  SizedBox(height: isWideScreen ? 20 : 16),
                  _buildDescription(card),
                  SizedBox(height: isWideScreen ? 24 : 20),
                  _buildMainContent(card, isWideScreen),
                  SizedBox(height: isWideScreen ? 24 : 20),
                  if (card.evidence.isNotEmpty) ...[
                    _buildEvidenceSection(card),
                    SizedBox(height: isWideScreen ? 20 : 16),
                  ],
                  _buildDisclaimer(card),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ReasoningCard card, bool isWideScreen) {
    return Row(
      children: [
        // Icon container with glow
        Container(
          padding: EdgeInsets.all(isWideScreen ? 14 : 12),
          decoration: BoxDecoration(
            color: card.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: card.accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: card.accentColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Icon(
            card.icon,
            color: card.accentColor,
            size: isWideScreen ? 28 : 24,
          ),
        ),
        SizedBox(width: isWideScreen ? 16 : 12),
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: TextStyle(
                  fontSize: isWideScreen ? 22 : 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getPerspectiveLabel(card.perspective),
                style: TextStyle(
                  fontSize: isWideScreen ? 13 : 11,
                  color: card.accentColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // Confidence badge
        _buildConfidenceBadge(card, isWideScreen),
      ],
    );
  }

  Widget _buildConfidenceBadge(ReasoningCard card, bool isWideScreen) {
    final confidenceLower = card.confidence.toLowerCase();
    final isLow = confidenceLower == 'low';
    final badgeColor = isLow ? _textMuted : _warningAmber;

    return GestureDetector(
      onTap: () => _showConfidenceExplanation(context, card.confidence),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isWideScreen ? 14 : 10,
          vertical: isWideScreen ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLow ? Icons.info_outline : Icons.shield_outlined,
              size: isWideScreen ? 16 : 14,
              color: badgeColor,
            ),
            const SizedBox(width: 6),
            Text(
              card.confidence.toUpperCase(),
              style: TextStyle(
                fontSize: isWideScreen ? 12 : 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfidenceExplanation(BuildContext context, String confidence) {
    final confidenceLower = confidence.toLowerCase();
    String title;
    String explanation;
    Color color;
    IconData icon;

    switch (confidenceLower) {
      case 'high':
        title = 'High Confidence';
        explanation = 'This analysis uses extensive and reliable data sources, including recent filings, earnings reports, and verified market data. The insights provided are well-supported but still represent hypothetical reasoning.';
        color = _bullishGreen;
        icon = Icons.verified_outlined;
        break;
      case 'medium':
        title = 'Medium Confidence';
        explanation = 'This analysis uses moderate data sources with reasonable coverage. The insights are a fair approximation of potential motivations, but some data points may be dated or incomplete.';
        color = _warningAmber;
        icon = Icons.shield_outlined;
        break;
      case 'low':
      default:
        title = 'Low Confidence';
        explanation = 'This analysis is based on limited or publicly available data. The insights are speculative and may not accurately reflect the investor\'s actual reasoning or strategy.';
        color = _textMuted;
        icon = Icons.info_outline;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              // Explanation
              Text(
                explanation,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.15),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(ReasoningCard card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        PerspectiveMetadata.getDescription(card.perspective),
        style: TextStyle(
          fontSize: 14,
          color: _textSecondary,
          height: 1.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildMainContent(ReasoningCard card, bool isWideScreen) {
    switch (card.perspective) {
      case ReasoningPerspective.bullVsBear:
        return _buildBullVsBearContent(card, isWideScreen);
      case ReasoningPerspective.newsSentiment:
        return _buildNewsSentimentContent(card, isWideScreen);
      case ReasoningPerspective.riskAssessment:
        return _buildRiskAssessmentContent(card, isWideScreen);
      default:
        return _buildKeyPointsContent(card, isWideScreen);
    }
  }

  Widget _buildKeyPointsContent(ReasoningCard card, bool isWideScreen) {
    return Container(
      padding: EdgeInsets.all(isWideScreen ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: card.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'KEY INSIGHTS',
                style: TextStyle(
                  fontSize: isWideScreen ? 14 : 12,
                  fontWeight: FontWeight.w700,
                  color: card.accentColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isWideScreen ? 20 : 16),
          ...card.keyPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: isWideScreen ? 16 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isWideScreen ? 28 : 24,
                    height: isWideScreen ? 28 : 24,
                    decoration: BoxDecoration(
                      color: card.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: isWideScreen ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          color: card.accentColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWideScreen ? 14 : 12),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14,
                        color: _textPrimary,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBullVsBearContent(ReasoningCard card, bool isWideScreen) {
    return Column(
      children: [
        // Bull vs Bear sections side by side on wide screens
        if (isWideScreen)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildBullSection(card, isWideScreen)),
                const SizedBox(width: 12),
                Expanded(child: _buildBearSection(card, isWideScreen)),
              ],
            ),
          )
        else ...[
          _buildBullSection(card, isWideScreen),
          const SizedBox(height: 12),
          _buildBearSection(card, isWideScreen),
        ],
        const SizedBox(height: 20),
        // Verdict section
        if (card.verdict != null) _buildVerdictSection(card, isWideScreen),
      ],
    );
  }

  Widget _buildBullSection(ReasoningCard card, bool isWideScreen) {
    final points = card.bullPoints ?? [];
    return Container(
      padding: EdgeInsets.all(isWideScreen ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _bullishGreen.withValues(alpha: 0.12),
            _bullishGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _bullishGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bullishGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: _bullishGreen,
                  size: isWideScreen ? 22 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'BULLISH',
                style: TextStyle(
                  fontSize: isWideScreen ? 16 : 14,
                  fontWeight: FontWeight.w800,
                  color: _bullishGreen,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          ...points.map((point) => Padding(
                padding: EdgeInsets.only(bottom: isWideScreen ? 12 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _bullishGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _bullishGreen.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: isWideScreen ? 15 : 13,
                          color: _textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBearSection(ReasoningCard card, bool isWideScreen) {
    final points = card.bearPoints ?? [];
    return Container(
      padding: EdgeInsets.all(isWideScreen ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _bearishRed.withValues(alpha: 0.12),
            _bearishRed.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _bearishRed.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bearishRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_down_rounded,
                  color: _bearishRed,
                  size: isWideScreen ? 22 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'BEARISH',
                style: TextStyle(
                  fontSize: isWideScreen ? 16 : 14,
                  fontWeight: FontWeight.w800,
                  color: _bearishRed,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          ...points.map((point) => Padding(
                padding: EdgeInsets.only(bottom: isWideScreen ? 12 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _bearishRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _bearishRed.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: isWideScreen ? 15 : 13,
                          color: _textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildVerdictSection(ReasoningCard card, bool isWideScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWideScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            card.verdictColor.withValues(alpha: 0.2),
            card.verdictColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: card.verdictColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: card.verdictColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Verdict header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isWideScreen ? 14 : 12),
                decoration: BoxDecoration(
                  color: card.verdictColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: card.verdictColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  card.verdictIcon,
                  color: card.verdictColor,
                  size: isWideScreen ? 36 : 30,
                ),
              ),
            ],
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          // Verdict label
          Text(
            'FINAL VERDICT',
            style: TextStyle(
              fontSize: isWideScreen ? 12 : 10,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          // Verdict value
          Text(
            card.verdict!,
            style: TextStyle(
              fontSize: isWideScreen ? 32 : 26,
              fontWeight: FontWeight.w900,
              color: card.verdictColor,
              letterSpacing: 2,
            ),
          ),
          // Reasoning
          if (card.verdictReasoning != null) ...[
            SizedBox(height: isWideScreen ? 20 : 16),
            Container(
              padding: EdgeInsets.all(isWideScreen ? 16 : 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                card.verdictReasoning!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isWideScreen ? 15 : 13,
                  color: _textPrimary,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewsSentimentContent(ReasoningCard card, bool isWideScreen) {
    return Column(
      children: [
        // Sentiment indicator
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWideScreen ? 20 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                card.newsSentimentColor.withValues(alpha: 0.15),
                card.newsSentimentColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: card.newsSentimentColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: card.newsSentimentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      card.newsSentimentIcon,
                      color: card.newsSentimentColor,
                      size: isWideScreen ? 28 : 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SENTIMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.newsSentiment ?? 'NEUTRAL',
                        style: TextStyle(
                          fontSize: isWideScreen ? 22 : 18,
                          fontWeight: FontWeight.w800,
                          color: card.newsSentimentColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (card.newsSummary != null) ...[
                SizedBox(height: isWideScreen ? 18 : 14),
                Container(
                  padding: EdgeInsets.all(isWideScreen ? 14 : 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    card.newsSummary!,
                    style: TextStyle(
                      fontSize: isWideScreen ? 14 : 13,
                      color: _textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // News sources
        if (card.newsSources != null && card.newsSources!.isNotEmpty) ...[
          SizedBox(height: isWideScreen ? 16 : 12),
          Container(
            padding: EdgeInsets.all(isWideScreen ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEWS SOURCES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: card.newsSources!.map((source) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: card.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: card.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: 12,
                          color: card.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
        // Key points
        if (card.keyPoints.isNotEmpty) ...[
          SizedBox(height: isWideScreen ? 16 : 12),
          _buildKeyPointsContent(card, isWideScreen),
        ],
      ],
    );
  }

  Widget _buildRiskAssessmentContent(ReasoningCard card, bool isWideScreen) {
    return Column(
      children: [
        // Risk level indicator with prominent "NOT ADVICE" banner
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWideScreen ? 20 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                card.riskLevelColor.withValues(alpha: 0.2),
                card.riskLevelColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: card.riskLevelColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: card.riskLevelColor.withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: [
              // NOT INVESTMENT ADVICE banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _warningAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _warningAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: _warningAmber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NOT INVESTMENT ADVICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _warningAmber,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isWideScreen ? 20 : 16),
              // Risk level indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isWideScreen ? 14 : 12),
                    decoration: BoxDecoration(
                      color: card.riskLevelColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: card.riskLevelColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(
                      card.riskLevelIcon,
                      color: card.riskLevelColor,
                      size: isWideScreen ? 32 : 28,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isWideScreen ? 14 : 10),
              // Risk level label
              Text(
                'RISK LEVEL',
                style: TextStyle(
                  fontSize: isWideScreen ? 11 : 10,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              // Risk level value
              Text(
                card.riskLevel?.replaceAll('_', ' ') ?? 'UNKNOWN',
                style: TextStyle(
                  fontSize: isWideScreen ? 28 : 24,
                  fontWeight: FontWeight.w900,
                  color: card.riskLevelColor,
                  letterSpacing: 1,
                ),
              ),
              // Risk summary
              if (card.riskSummary != null) ...[
                SizedBox(height: isWideScreen ? 18 : 14),
                Container(
                  padding: EdgeInsets.all(isWideScreen ? 14 : 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    card.riskSummary!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isWideScreen ? 14 : 13,
                      color: _textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Risk factors section
        if (card.riskFactors != null && card.riskFactors!.isNotEmpty) ...[
          SizedBox(height: isWideScreen ? 16 : 12),
          Container(
            padding: EdgeInsets.all(isWideScreen ? 18 : 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: card.riskLevelColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: card.riskLevelColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'RISK FACTORS',
                      style: TextStyle(
                        fontSize: isWideScreen ? 13 : 11,
                        fontWeight: FontWeight.w700,
                        color: card.riskLevelColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWideScreen ? 16 : 12),
                ...card.riskFactors!.map((factor) => Padding(
                      padding: EdgeInsets.only(bottom: isWideScreen ? 12 : 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: card.riskLevelColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: card.riskLevelColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              factor,
                              style: TextStyle(
                                fontSize: isWideScreen ? 14 : 12,
                                color: _textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
        // Key points if any
        if (card.keyPoints.isNotEmpty) ...[
          SizedBox(height: isWideScreen ? 16 : 12),
          _buildKeyPointsContent(card, isWideScreen),
        ],
      ],
    );
  }

  Widget _buildEvidenceSection(ReasoningCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _evidenceExpanded = !_evidenceExpanded),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: card.accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evidence Sources (${card.evidence.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: card.accentColor,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _evidenceExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: card.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              children: card.evidence.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: e.isClickable ? () => _launchUrl(e.url) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.isClickable
                            ? card.accentColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: e.isClickable
                            ? Border.all(
                                color: card.accentColor.withValues(alpha: 0.2))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.icon,
                            size: 18,
                            color: e.isClickable
                                ? card.accentColor
                                : _textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.title,
                              style: TextStyle(
                                fontSize: 14,
                                color: e.isClickable
                                    ? card.accentColor
                                    : _textSecondary,
                                decoration: e.isClickable
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: card.accentColor,
                              ),
                            ),
                          ),
                          if (e.isClickable)
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: card.accentColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          crossFadeState: _evidenceExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(ReasoningCard card) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warningAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _warningAmber.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: _warningAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              card.disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: _warningAmber.withValues(alpha: 0.9),
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPerspectiveLabel(ReasoningPerspective perspective) {
    switch (perspective) {
      case ReasoningPerspective.fundamental:
        return 'FINANCIALS & VALUATION';
      case ReasoningPerspective.newsSentiment:
        return 'MEDIA ANALYSIS';
      case ReasoningPerspective.marketContext:
        return 'MARKET & SECTOR';
      case ReasoningPerspective.technical:
        return 'PRICE ACTION & TRENDS';
      case ReasoningPerspective.bullVsBear:
        return 'INVESTMENT THESIS';
      case ReasoningPerspective.riskAssessment:
        return 'RISK OVERVIEW';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
