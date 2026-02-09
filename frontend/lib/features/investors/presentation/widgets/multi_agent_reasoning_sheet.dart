import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../models/reasoning_card.dart';
import '../../providers/investor_detail_provider.dart';
import 'reasoning_perspective_card.dart';

/// Custom scroll physics that prevents over-scrolling at boundaries
/// to avoid gesture conflicts with parent widgets.
class _BoundedPageScrollPhysics extends ScrollPhysics {
  const _BoundedPageScrollPhysics({super.parent});

  @override
  _BoundedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _BoundedPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}

/// Premium multi-agent reasoning sheet with maximized card viewing area.
///
/// Design: Bloomberg Terminal meets luxury fintech
/// - Compact header with inline navigation
/// - Cards take 80%+ of available space
/// - Collapsible footer drawer for disclaimers
class MultiAgentReasoningSheet extends ConsumerStatefulWidget {
  final String investorId;
  final String ticker;
  final String companyName;
  final String changeType;

  const MultiAgentReasoningSheet({
    super.key,
    required this.investorId,
    required this.ticker,
    required this.companyName,
    required this.changeType,
  });

  @override
  ConsumerState<MultiAgentReasoningSheet> createState() =>
      _MultiAgentReasoningSheetState();
}

class _MultiAgentReasoningSheetState
    extends ConsumerState<MultiAgentReasoningSheet>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _footerExpanded = false;

  // Premium dark theme colors
  static const _surfaceDark = Color(0xFF0D1117);
  static const _surfaceElevated = Color(0xFF161B22);
  static const _borderSubtle = Color(0xFF30363D);
  static const _textPrimary = Color(0xFFE6EDF3);
  static const _textSecondary = Color(0xFF8B949E);
  static const _textMuted = Color(0xFF6E7681);
  static const _accentGreen = Color(0xFF3FB950);
  static const _accentAmber = Color(0xFFD29922);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (investorId: widget.investorId, ticker: widget.ticker, changeType: widget.changeType);
    final asyncValue = ref.watch(multiAgentReasoningProvider(params));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _surfaceElevated,
            _surfaceDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Minimal drag handle
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

          // Compact header
          _buildCompactHeader(),

          // Content
          Expanded(
            child: asyncValue.when(
              loading: () => _buildLoadingState(),
              error: (e, _) => _buildErrorState(e),
              data: (data) {
                if (data == null) {
                  return _buildErrorState('Failed to load analysis');
                }
                return _buildContent(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Ticker badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentGreen.withValues(alpha: 0.2),
                  _accentGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _accentGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_rounded,
                  color: _accentGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.ticker,
                  style: const TextStyle(
                    color: _accentGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Company name
          Expanded(
            child: Text(
              widget.companyName,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Close button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _borderSubtle.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _textSecondary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated loading indicator
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n?.generatingAnalysis ?? 'Generating Sequential Analysis',
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),
        // Full progress steps - two rows for better display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Row 1: Fundamental → News → Market
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressChip('1', l10n?.fundamental ?? 'Fundamental', _accentGreen),
                  _buildProgressArrow(),
                  _buildProgressChip('2', l10n?.news ?? 'News', const Color(0xFFEC4899)),
                  _buildProgressArrow(),
                  _buildProgressChip('3', l10n?.market ?? 'Market', const Color(0xFF06B6D4)),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Technical → Debate → Risk
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressChip('4', l10n?.technical ?? 'Technical', const Color(0xFF8B5CF6)),
                  _buildProgressArrow(),
                  _buildProgressChip('5', l10n?.debate ?? 'Debate', const Color(0xFFF59E0B)),
                  _buildProgressArrow(),
                  _buildProgressChip('6', l10n?.risk ?? 'Risk', const Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChip(String number, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 14,
        color: _textMuted,
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.analysisUnavailable ?? 'Analysis Unavailable',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.invalidate(multiAgentReasoningProvider((
                    investorId: widget.investorId,
                    ticker: widget.ticker,
                    changeType: widget.changeType,
                  )));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentGreen, _accentGreen.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.retry ?? 'Retry',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(MultiAgentReasoningResponse data) {
    return Column(
      children: [
        // Slim activity banner
        _buildActivityBanner(data),

        // Compact navigation row with dots and arrows
        _buildNavigationRow(data),

        // MAXIMIZED PageView - takes most of the space
        Expanded(
          child: NotificationListener<OverscrollNotification>(
            onNotification: (notification) => true,
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                if (notification.metrics.atEdge) {
                  return true;
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: data.cards.length,
                physics: const _BoundedPageScrollPhysics(),
                padEnds: true,
                itemBuilder: (context, index) {
                  return ReasoningPerspectiveCard(card: data.cards[index]);
                },
              ),
            ),
          ),
        ),

        // Collapsible footer drawer
        _buildCollapsibleFooter(data),
      ],
    );
  }

  Widget _buildActivityBanner(MultiAgentReasoningResponse data) {
    final color = _getChangeTypeColor(widget.changeType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getChangeTypeIcon(widget.changeType),
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.activitySummary,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow(MultiAgentReasoningResponse data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left arrow
          _buildNavArrow(
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 0,
            onTap: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),

          const SizedBox(width: 8),

          // Dot indicators
          ...List.generate(
            data.cards.length,
            (index) => _buildDotIndicator(index, data.cards[index]),
          ),

          const SizedBox(width: 8),

          // Right arrow
          _buildNavArrow(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < data.cards.length - 1,
            onTap: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),

          const SizedBox(width: 12),

          // Page counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _borderSubtle.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_currentPage + 1}/${data.cards.length}',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: enabled
                ? _accentGreen.withValues(alpha: 0.15)
                : _borderSubtle.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? _accentGreen : _textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index, ReasoningCard card) {
    final isActive = index == _currentPage;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: isActive ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: isActive ? card.accentColor : _borderSubtle,
          borderRadius: BorderRadius.circular(3),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: card.accentColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildCollapsibleFooter(MultiAgentReasoningResponse data) {
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _surfaceElevated,
        border: Border(
          top: BorderSide(color: _borderSubtle.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tap to expand header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _footerExpanded = !_footerExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: _accentAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.disclaimersLimitations ?? 'Disclaimers & Limitations',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _footerExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFooterContent(data),
            crossFadeState: _footerExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterContent(MultiAgentReasoningResponse data) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What We Don't Know - compact
            if (data.unknowns.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _borderSubtle.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 14,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.whatWeDontKnow ?? 'What We Don\'t Know',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...data.unknowns.take(3).map((unknown) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 9,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  unknown,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 9,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Disclaimer - compact
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accentAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _accentAmber.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: _accentAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.overallDisclaimer,
                      style: TextStyle(
                        color: _accentAmber.withValues(alpha: 0.9),
                        fontSize: 9,
                        height: 1.35,
                      ),
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

  Color _getChangeTypeColor(String changeType) {
    switch (changeType.toUpperCase()) {
      case 'NEW':
      case 'ADDED':
        return _accentGreen;
      case 'REDUCED':
        return Colors.orange;
      case 'SOLD_OUT':
        return Colors.red;
      default:
        return _textSecondary;
    }
  }

  IconData _getChangeTypeIcon(String changeType) {
    switch (changeType.toUpperCase()) {
      case 'NEW':
        return Icons.add_circle_outline_rounded;
      case 'ADDED':
        return Icons.trending_up_rounded;
      case 'REDUCED':
        return Icons.trending_down_rounded;
      case 'SOLD_OUT':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }
}

/// Helper function to show the multi-agent reasoning bottom sheet.
void showMultiAgentReasoningSheet(
  BuildContext context, {
  required String investorId,
  required String ticker,
  required String companyName,
  required String changeType,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      snap: true,
      snapSizes: const [0.5, 0.92, 0.96],
      builder: (context, scrollController) => MultiAgentReasoningSheet(
        investorId: investorId,
        ticker: ticker,
        companyName: companyName,
        changeType: changeType,
      ),
    ),
  );
}
