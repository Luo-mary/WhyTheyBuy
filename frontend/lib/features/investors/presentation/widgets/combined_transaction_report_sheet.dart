import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../models/reasoning_card.dart';
import '../../providers/combined_report_provider.dart';
import 'transaction_report_section.dart';

/// Bottom sheet for displaying combined multi-transaction analysis report.
///
/// Shows AI reasoning for multiple selected transactions in an organized,
/// expandable format with each transaction's 6-perspective analysis.
class CombinedTransactionReportSheet extends ConsumerStatefulWidget {
  final String investorId;
  final String investorName;
  final List<String> selectedKeys;  // Format: "TICKER_CHANGETYPE" e.g. "OXY_ADDED", "OXY_SOLD_OUT"

  const CombinedTransactionReportSheet({
    super.key,
    required this.investorId,
    required this.investorName,
    required this.selectedKeys,
  });

  @override
  ConsumerState<CombinedTransactionReportSheet> createState() =>
      _CombinedTransactionReportSheetState();
}

class _CombinedTransactionReportSheetState
    extends ConsumerState<CombinedTransactionReportSheet> {
  // Premium dark theme colors
  static const _surfaceDark = Color(0xFF0D1117);
  static const _surfaceElevated = Color(0xFF161B22);
  static const _borderSubtle = Color(0xFF30363D);
  static const _textPrimary = Color(0xFFE6EDF3);
  static const _textSecondary = Color(0xFF8B949E);
  static const _textMuted = Color(0xFF6E7681);
  static const _accentBlue = Color(0xFF58A6FF);
  static const _accentGreen = Color(0xFF3FB950);
  static const _accentAmber = Color(0xFFD29922);
  static const _accentRed = Color(0xFFF85149);

  // Email sending state
  bool _isSendingEmail = false;
  String? _emailStatusMessage;
  bool _emailSuccess = false;

  @override
  void initState() {
    super.initState();
    // Start loading report data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(combinedReportNotifierProvider.notifier).loadReport((
        investorId: widget.investorId,
        investorName: widget.investorName,
        keys: widget.selectedKeys,
      ));
    });
  }

  Future<void> _sendReportToEmail(List<MultiAgentReasoningResponse> results) async {
    if (_isSendingEmail) return;

    setState(() {
      _isSendingEmail = true;
      _emailStatusMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);

      // Build transactions data
      final transactions = results.map((r) => {
        'ticker': r.ticker,
        'company_name': r.companyName,
        'change_type': r.changeType,
        'activity_summary': r.activitySummary,
        'cards': r.cards.map((c) => {
          'perspective': c.perspective.toJson(),
          'title': c.title,
          'key_points': c.keyPoints,
          'confidence': c.confidence,
          'verdict': c.verdict,
          'verdict_reasoning': c.verdictReasoning,
          'news_sentiment': c.newsSentiment,
          'news_summary': c.newsSummary,
          'risk_level': c.riskLevel,
          'risk_factors': c.riskFactors,
          'risk_summary': c.riskSummary,
          'bull_points': c.bullPoints,
          'bear_points': c.bearPoints,
        }).toList(),
      }).toList();

      final response = await apiClient.sendCombinedTransactionReport(
        widget.investorId,
        widget.investorName,
        widget.selectedKeys,
        transactions,
      );

      if (response.statusCode == 200) {
        final sentToEmail = response.data['email'] ?? 'your email';
        setState(() {
          _emailSuccess = true;
          _emailStatusMessage = 'Report sent to $sentToEmail! Check your inbox (and spam folder).';
        });
      } else {
        setState(() {
          _emailSuccess = false;
          _emailStatusMessage = response.data['detail'] ?? 'Failed to send report';
        });
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to send report. Please try again.';

      // Extract error from DioException
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'];

      if (statusCode == 401) {
        errorMessage = 'Please log in to send reports to email.';
      } else if (statusCode == 400) {
        errorMessage = detail ?? 'Invalid request. Please try again.';
      } else if (statusCode == 500) {
        errorMessage = detail ?? 'Server error. Please try again later.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Network error. Check your connection.';
      } else if (detail != null) {
        errorMessage = detail;
      }

      setState(() {
        _emailSuccess = false;
        _emailStatusMessage = errorMessage;
      });
      debugPrint('DioException sending report: $statusCode - $detail - $e');
    } catch (e) {
      setState(() {
        _emailSuccess = false;
        _emailStatusMessage = 'Failed to send report. Please try again.';
      });
      debugPrint('Error sending report: $e');
    } finally {
      setState(() {
        _isSendingEmail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(combinedReportNotifierProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _surfaceElevated,
            _surfaceDark,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(),

          // Content
          Expanded(
            child: reportState.isComplete
                ? _buildReport(reportState.results)
                : _buildLoadingState(reportState),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Report icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentBlue.withValues(alpha: 0.2),
                      _accentBlue.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.assessment_rounded,
                  color: _accentBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Combined Analysis Report',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.investorName,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: _surfaceDark,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Selected tickers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedKeys.map((ticker) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accentGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  ticker,
                  style: const TextStyle(
                    color: _accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(CombinedReportState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 4,
                    backgroundColor: _borderSubtle,
                    valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
                  ),
                  Text(
                    '${state.loadedCount}/${state.totalCount}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Loading Analysis',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            if (state.currentTicker != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.currentTicker!,
                      style: const TextStyle(
                        color: _accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Loading steps
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderSubtle),
              ),
              child: Column(
                children: [
                  _buildLoadingStep('Fundamental Analysis', 1, state.loadedCount),
                  _buildLoadingStep('News & Sentiment', 2, state.loadedCount),
                  _buildLoadingStep('Market Context', 3, state.loadedCount),
                  _buildLoadingStep('Technical Analysis', 4, state.loadedCount),
                  _buildLoadingStep('Investment Debate', 5, state.loadedCount),
                  _buildLoadingStep('Risk Assessment', 6, state.loadedCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep(String name, int stepNum, int loadedCount) {
    final bool isComplete = loadedCount >= stepNum;
    final bool isCurrent = loadedCount == stepNum - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isComplete
                  ? _accentGreen.withValues(alpha: 0.2)
                  : isCurrent
                      ? _accentBlue.withValues(alpha: 0.2)
                      : _surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isComplete
                    ? _accentGreen
                    : isCurrent
                        ? _accentBlue
                        : _borderSubtle,
              ),
            ),
            child: Center(
              child: isComplete
                  ? const Icon(Icons.check, color: _accentGreen, size: 12)
                  : isCurrent
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_accentBlue),
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              color: isComplete || isCurrent ? _textPrimary : _textMuted,
              fontSize: 13,
              fontWeight: isComplete || isCurrent
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(List<MultiAgentReasoningResponse> results) {
    if (results.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Report summary
        _buildReportSummary(results),
        const SizedBox(height: 20),

        // Transaction sections
        ...results.asMap().entries.map((entry) {
          final index = entry.key;
          final reasoning = entry.value;
          return TransactionReportSection(
            reasoning: reasoning,
            initiallyExpanded: index == 0, // Expand first one by default
          );
        }),

        // Disclaimer footer
        _buildDisclaimer(),
        const SizedBox(height: 20),

        // Send to Email button
        _buildEmailButton(results),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmailButton(List<MultiAgentReasoningResponse> results) {
    return Column(
      children: [
        // Email button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSendingEmail ? null : () => _sendReportToEmail(results),
            icon: _isSendingEmail
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.email_outlined, size: 20),
            label: Text(
              _isSendingEmail ? 'Sending...' : 'Send Report to Email',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: _accentGreen.withValues(alpha: 0.5),
            ),
          ),
        ),

        // Status message
        if (_emailStatusMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _emailSuccess
                  ? _accentGreen.withValues(alpha: 0.1)
                  : _accentRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _emailSuccess
                    ? _accentGreen.withValues(alpha: 0.3)
                    : _accentRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _emailSuccess ? Icons.check_circle : Icons.error_outline,
                  color: _emailSuccess ? _accentGreen : _accentRed,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _emailStatusMessage!,
                    style: TextStyle(
                      color: _emailSuccess ? _accentGreen : _accentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReportSummary(List<MultiAgentReasoningResponse> results) {
    // Count change types
    int newPositions = 0;
    int increased = 0;
    int decreased = 0;
    int exited = 0;

    for (final r in results) {
      switch (r.changeType.toUpperCase()) {
        case 'NEW':
          newPositions++;
          break;
        case 'ADDED':
          increased++;
          break;
        case 'REDUCED':
          decreased++;
          break;
        case 'SOLD_OUT':
          exited++;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderSubtle),
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
                  color: _accentBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'REPORT SUMMARY',
                style: TextStyle(
                  color: _accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _buildSummaryItem(
                  'Transactions', results.length.toString(), _accentBlue),
              if (newPositions > 0)
                _buildSummaryItem('New', '+$newPositions', _accentGreen),
              if (increased > 0)
                _buildSummaryItem('Increased', '+$increased', _accentGreen),
              if (decreased > 0)
                _buildSummaryItem('Decreased', '-$decreased', _accentAmber),
              if (exited > 0)
                _buildSummaryItem('Exited', '-$exited', const Color(0xFFF85149)),
            ],
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            'This report combines AI-generated analysis for ${results.length} transactions '
            'from ${widget.investorName}. Each transaction includes 6 perspectives: '
            'Fundamental, News & Sentiment, Market Context, Technical, Investment Debate, '
            'and Risk Assessment.',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentAmber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: _accentAmber,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Analysis Available',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Could not load analysis for the selected transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                ref.read(combinedReportNotifierProvider.notifier).loadReport((
                  investorId: widget.investorId,
                  investorName: widget.investorName,
                  keys: widget.selectedKeys,
                ));
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(
                foregroundColor: _accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _accentAmber.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _accentAmber,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EDUCATIONAL USE ONLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accentAmber,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This report is AI-generated for educational purposes only. '
                  'It does NOT constitute investment advice. All analyses are '
                  'hypothetical and based on publicly available information. '
                  'Past performance does not guarantee future results.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
