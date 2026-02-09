import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/reasoning_card.dart';

/// A compact widget displaying one transaction's analysis within a combined report.
///
/// Shows the transaction header (ticker, company, change type) followed by
/// 6 expandable perspective cards in a compact format.
class TransactionReportSection extends StatefulWidget {
  final MultiAgentReasoningResponse reasoning;
  final bool initiallyExpanded;

  const TransactionReportSection({
    super.key,
    required this.reasoning,
    this.initiallyExpanded = false,
  });

  @override
  State<TransactionReportSection> createState() =>
      _TransactionReportSectionState();
}

class _TransactionReportSectionState extends State<TransactionReportSection> {
  late bool _isExpanded;
  final Map<ReasoningPerspective, bool> _perspectiveExpanded = {};

  // Premium dark theme colors
  static const _surfaceDark = Color(0xFF0D1117);
  static const _surfaceElevated = Color(0xFF161B22);
  static const _borderColor = Color(0xFF30363D);
  static const _textPrimary = Color(0xFFE6EDF3);
  static const _textSecondary = Color(0xFF8B949E);
  static const _textMuted = Color(0xFF6E7681);
  static const _accentGreen = Color(0xFF3FB950);
  static const _accentRed = Color(0xFFF85149);
  static const _accentBlue = Color(0xFF58A6FF);
  static const _accentAmber = Color(0xFFD29922);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  Color _getChangeTypeColor(String changeType) {
    switch (changeType.toUpperCase()) {
      case 'NEW':
      case 'ADDED':
        return _accentGreen;
      case 'REDUCED':
        return _accentAmber;
      case 'SOLD_OUT':
        return _accentRed;
      default:
        return _textSecondary;
    }
  }

  String _getChangeTypeLabel(String changeType) {
    switch (changeType.toUpperCase()) {
      case 'NEW':
        return 'NEW POSITION';
      case 'ADDED':
        return 'INCREASED';
      case 'REDUCED':
        return 'DECREASED';
      case 'SOLD_OUT':
        return 'EXITED';
      default:
        return changeType.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasoning = widget.reasoning;
    final changeColor = _getChangeTypeColor(reasoning.changeType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? changeColor.withValues(alpha: 0.4) : _borderColor,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction header - always visible
          _buildHeader(reasoning, changeColor),
          // Content - expandable
          if (_isExpanded) ...[
            Container(
              height: 1,
              color: _borderColor,
            ),
            _buildActivitySummary(reasoning),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: _borderColor.withValues(alpha: 0.5),
            ),
            _buildPerspectivesList(reasoning),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(MultiAgentReasoningResponse reasoning, Color changeColor) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(16),
        bottom: _isExpanded ? Radius.zero : const Radius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Expand/collapse icon
            AnimatedRotation(
              turns: _isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_right_rounded,
                color: _textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Ticker badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: changeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                reasoning.ticker,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: changeColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Company name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reasoning.companyName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getChangeTypeLabel(reasoning.changeType),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: changeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${reasoning.cards.length} perspectives',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Card count indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: _textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummary(MultiAgentReasoningResponse reasoning) {
    if (reasoning.activitySummary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 18,
                color: _accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIVITY SUMMARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reasoning.activitySummary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerspectivesList(MultiAgentReasoningResponse reasoning) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: reasoning.cards
            .map((card) => _buildCompactPerspectiveCard(card))
            .toList(),
      ),
    );
  }

  Widget _buildCompactPerspectiveCard(ReasoningCard card) {
    final isExpanded = _perspectiveExpanded[card.perspective] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? card.accentColor.withValues(alpha: 0.4)
              : _borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Perspective header
          InkWell(
            onTap: () => setState(() {
              _perspectiveExpanded[card.perspective] = !isExpanded;
            }),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: card.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      card.icon,
                      color: card.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${card.keyPoints.length} key points',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  _buildStatusIndicator(card),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) ...[
            Container(
              height: 1,
              color: _borderColor,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildPerspectiveContent(card),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ReasoningCard card) {
    // Show special indicator for certain card types
    switch (card.perspective) {
      case ReasoningPerspective.bullVsBear:
        if (card.verdict != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: card.verdictColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              card.verdict!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: card.verdictColor,
              ),
            ),
          );
        }
        break;
      case ReasoningPerspective.newsSentiment:
        if (card.newsSentiment != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: card.newsSentimentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              card.newsSentiment!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: card.newsSentimentColor,
              ),
            ),
          );
        }
        break;
      case ReasoningPerspective.riskAssessment:
        if (card.riskLevel != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: card.riskLevelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              card.riskLevel!.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: card.riskLevelColor,
              ),
            ),
          );
        }
        break;
      default:
        break;
    }
    return const SizedBox.shrink();
  }

  Widget _buildPerspectiveContent(ReasoningCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key points
        ...card.keyPoints.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: card.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: card.accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Special content for Bull vs Bear
        if (card.perspective == ReasoningPerspective.bullVsBear) ...[
          if (card.bullPoints != null && card.bullPoints!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBullBearSection('BULLISH', card.bullPoints!, _accentGreen),
          ],
          if (card.bearPoints != null && card.bearPoints!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBullBearSection('BEARISH', card.bearPoints!, _accentRed),
          ],
          if (card.verdict != null && card.verdictReasoning != null) ...[
            const SizedBox(height: 12),
            _buildVerdictSection(card),
          ],
        ],
        // News sentiment special content
        if (card.perspective == ReasoningPerspective.newsSentiment &&
            card.newsSummary != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card.newsSentimentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: card.newsSentimentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              card.newsSummary!,
              style: TextStyle(
                fontSize: 13,
                color: _textPrimary,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        // Risk assessment special content
        if (card.perspective == ReasoningPerspective.riskAssessment &&
            card.riskFactors != null &&
            card.riskFactors!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRiskFactorsSection(card),
        ],
        // Evidence links
        if (card.evidence.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildEvidenceSection(card),
        ],
      ],
    );
  }

  Widget _buildBullBearSection(String label, List<String> points, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                label == 'BULLISH'
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textPrimary,
                          height: 1.4,
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

  Widget _buildVerdictSection(ReasoningCard card) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            card.verdictColor.withValues(alpha: 0.15),
            card.verdictColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.verdictColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                card.verdictIcon,
                color: card.verdictColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'VERDICT: ${card.verdict}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: card.verdictColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.verdictReasoning!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskFactorsSection(ReasoningCard card) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card.riskLevelColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: card.riskLevelColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: card.riskLevelColor,
              ),
              const SizedBox(width: 6),
              Text(
                'RISK FACTORS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: card.riskLevelColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...card.riskFactors!.map((factor) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: card.riskLevelColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        factor,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textPrimary,
                          height: 1.4,
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

  Widget _buildEvidenceSection(ReasoningCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EVIDENCE SOURCES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: card.evidence.map((e) {
            return InkWell(
              onTap: e.isClickable ? () => _launchUrl(e.url) : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: e.isClickable
                      ? card.accentColor.withValues(alpha: 0.1)
                      : _surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: e.isClickable
                        ? card.accentColor.withValues(alpha: 0.3)
                        : _borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e.icon,
                      size: 14,
                      color: e.isClickable ? card.accentColor : _textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.title.length > 30
                          ? '${e.title.substring(0, 30)}...'
                          : e.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: e.isClickable ? card.accentColor : _textSecondary,
                        decoration: e.isClickable
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                    if (e.isClickable) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: card.accentColor,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
