import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/cache_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/evidence_panel.dart';
import '../../../../core/widgets/disclaimer_block.dart';
import '../../../../core/widgets/transparency_badge.dart';
import '../../../../core/widgets/upgrade_prompt.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../../subscription/models/subscription_model.dart';
import '../../providers/investor_detail_provider.dart';
import '../../providers/combined_report_provider.dart';
import '../widgets/multi_agent_reasoning_sheet.dart';
import '../widgets/combined_transaction_report_sheet.dart';

// ============================================================================
// MAIN PAGE
// ============================================================================

/// Investor AI Summary Page - Single scrollable page with sections (no tabs)
///
/// Sections:
/// 0. Header (always visible) - Name, type, disclosure, transparency, disclaimer
/// 1. Executive AI Summary (expanded) - Headline, highlights, hypothetical language
/// 2. Holdings Changes (expanded) - Per-stock cards with embedded trades & evidence
/// 3. Holdings Snapshot (collapsed) - Top holdings table
class InvestorDetailPage extends ConsumerStatefulWidget {
  final String investorId;

  const InvestorDetailPage({super.key, required this.investorId});

  @override
  ConsumerState<InvestorDetailPage> createState() => _InvestorDetailPageState();
}

class _InvestorDetailPageState extends ConsumerState<InvestorDetailPage> {
  // Expand/collapse state for top-level sections
  final Map<int, bool> _expandedSections = {
    1: true, // Executive Summary / Portfolio Overview - expanded
    2: true, // Holdings Changes - expanded
  };

  // Per-stock state
  final Set<String> _flippedStockCards = {};

  void _toggleSection(int index) {
    setState(() {
      _expandedSections[index] = !(_expandedSections[index] ?? false);
    });
  }

  void _toggleStockFlip(String ticker) {
    setState(() {
      if (_flippedStockCards.contains(ticker)) {
        _flippedStockCards.remove(ticker);
      } else {
        _flippedStockCards.add(ticker);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // No-op: Holdings Snapshot is now embedded inside Portfolio Overview
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale to rebuild when language changes (same pattern as settings_page.dart)
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final investorAsync = ref.watch(investorDetailProvider(widget.investorId));
    final changesAsync = ref.watch(investorChangesProvider(widget.investorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: investorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.failedToLoadInvestor)),
        data: (investor) {
          final stockChanges = changesAsync.valueOrNull ?? [];
          final isChangesLoading = changesAsync.isLoading;

          return RefreshIndicator(
            onRefresh: () async {
              // Clear TTL cache first
              clearInvestorCache(ref, widget.investorId);
              // Then invalidate Riverpod providers to force re-fetch
              ref.invalidate(investorDetailProvider(widget.investorId));
              ref.invalidate(investorChangesProvider(widget.investorId));
              ref.invalidate(portfolioOverviewProvider(widget.investorId));
              ref.invalidate(investorHoldingsProvider(widget.investorId));
              // Wait for data to reload
              await ref.read(investorDetailProvider(widget.investorId).future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 0: Header (always visible)
                _HeaderSection(
                  investor: investor,
                  onBack: () => context.go('/home'),
                  l10n: l10n,
                ),
                const SizedBox(height: 24),

                // Section 1: Executive AI Summary
                _ExecutiveSummarySection(
                  investorId: widget.investorId,
                  isExpanded: _expandedSections[1]!,
                  onToggle: () => _toggleSection(1),
                ),

                // Section 2: Holdings Changes (with per-stock trades & evidence)
                _HoldingsChangesSection(
                  investorId: widget.investorId,
                  investorName: investor['name'] ?? 'Unknown Investor',
                  updateFrequency: investor['updateFrequency'] ?? 'Unknown',
                  isExpanded: _expandedSections[2]!,
                  onToggle: () => _toggleSection(2),
                  stockChanges: stockChanges,
                  isLoading: isChangesLoading,
                  flippedStockCards: _flippedStockCards,
                  onToggleStockFlip: _toggleStockFlip,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}

// ============================================================================
// SECTION 0: HEADER (Always Visible)
// ============================================================================

class _HeaderSection extends StatelessWidget {
  final Map<String, dynamic> investor;
  final VoidCallback onBack;
  final AppLocalizations l10n;

  const _HeaderSection({
    required this.investor,
    required this.onBack,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 20),

        // Investor header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  investor['name'][0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investor['name'],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.business,
                        label: investor['investorType'],
                      ),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: investor['updateFrequency'],
                      ),
                      TransparencyBadge.fromScore(
                        investor['transparencyScore'] ?? 50,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          investor['description'],
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // Disclaimer banner (always visible)
        DisclaimerBanner(
          text: l10n.forEducationalPurposes,
        ),
        const SizedBox(height: 16),

        // Stats row - adapted for quarterly vs daily investors
        Builder(
          builder: (context) {
            final isQuarterly = investor['updateFrequency']?.toString().toLowerCase() == 'quarterly';
            final filingPeriod = investor['latestFilingPeriod'] as String?;
            final filingChanges = investor['latestFilingChanges'] as int?;

            // For quarterly filers with filing data, show filing period info
            // Otherwise show standard 30d changes
            String changesLabel;
            String changesValue;
            String? changesSubtitle;

            if (isQuarterly && filingPeriod != null && filingChanges != null) {
              changesLabel = 'Latest 13F';
              changesValue = '$filingChanges';
              changesSubtitle = filingPeriod;
            } else {
              changesLabel = l10n.changes30d;
              changesValue = '${investor['changes30d']}';
              changesSubtitle = null;
            }

            return Row(
              children: [
                _StatBox(
                  label: l10n.totalHoldings,
                  value: '${investor['totalHoldings']}',
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: changesLabel,
                  value: changesValue,
                  subtitle: changesSubtitle,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: l10n.lastUpdate,
                  value: investor['lastUpdate'],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle; // Optional subtitle (e.g., filing period)

  const _StatBox({required this.label, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 1: EXECUTIVE AI SUMMARY
// ============================================================================

class _ExecutiveSummarySection extends ConsumerStatefulWidget {
  final String investorId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExecutiveSummarySection({
    required this.investorId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  ConsumerState<_ExecutiveSummarySection> createState() =>
      _ExecutiveSummarySectionState();
}

class _ExecutiveSummarySectionState
    extends ConsumerState<_ExecutiveSummarySection> {
  bool _holdingsExpanded = false;
  bool _showAllHoldings = false;

  @override
  Widget build(BuildContext context) {
    // Use provider-based localization to ensure proper rebuilding
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    final overviewAsync = ref.watch(portfolioOverviewProvider(widget.investorId));

    return _ExpandableSection(
      title: l10n.portfolioOverview,
      icon: Icons.pie_chart_outline,
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggle,
      subtitle: l10n.sectorBreakdownActivity,
      child: overviewAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => _buildFallbackContent(),
        data: (overview) {
          if (overview == null) return _buildFallbackContent();
          return _buildOverviewContent(overview);
        },
      ),
    );
  }

  Widget _buildOverviewContent(Map<String, dynamic> data) {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final sectors =
        (data['sector_breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentChanges =
        data['recent_changes'] as Map<String, dynamic>? ?? {};
    final snapshotDate = data['snapshot_date'] as String?;
    final totalPositions = data['total_positions'] as int? ?? 0;

    final summaryText = recentChanges['summary_text'] as String? ?? '';
    final buys =
        (recentChanges['buys'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sells =
        (recentChanges['sells'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Snapshot metadata
        if (snapshotDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${l10n?.latestSnapshot ?? 'Latest snapshot'}: $snapshotDate  ·  $totalPositions ${l10n?.positions ?? 'positions'}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ),

        // Sector breakdown bar chart
        if (sectors.isNotEmpty) ...[
          Text(
            l10n?.sectorAllocation ?? 'Sector Allocation',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...sectors.take(8).map((s) => _SectorBar(
                label: s['sector'] as String? ?? 'Other',
                pct: (s['weight_pct'] as num?)?.toDouble() ?? 0,
                count: s['count'] as int? ?? 0,
              )),
          if (sectors.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n?.moreSectors(sectors.length - 8) ?? '+${sectors.length - 8} more sectors',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // Recent changes summary
        Text(
          l10n?.recentActivity ?? 'Recent Activity',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (summaryText.isNotEmpty)
          Text(
            summaryText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        if (buys.isNotEmpty || sells.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...buys.take(5).map((b) => _ChangeBadge(
                    ticker: b['ticker'] as String? ?? '',
                    type: b['change_type'] as String? ?? 'added',
                    isBuy: true,
                  )),
              ...sells.take(5).map((s) => _ChangeBadge(
                    ticker: s['ticker'] as String? ?? '',
                    type: s['change_type'] as String? ?? 'reduced',
                    isBuy: false,
                  )),
            ],
          ),
        ],
        if (buys.isEmpty && sells.isEmpty && sectors.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.textTertiary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.noHoldingsDataYet ?? 'No holdings data available yet. Data will appear after the next ingestion cycle.',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Holdings Snapshot (collapsible sub-section)
        const SizedBox(height: 16),
        _buildHoldingsSnapshot(),

        // Disclaimer
        const SizedBox(height: 12),
        Text(
          l10n?.basedOnPublicDisclosures ?? 'Based on publicly disclosed holdings. This is not investment advice.',
          style: TextStyle(
            color: AppColors.textTertiary.withValues(alpha: 0.7),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingsSnapshot() {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final holdingsAsync =
        ref.watch(investorHoldingsProvider(widget.investorId));
    final holdings = holdingsAsync.valueOrNull ?? [];
    final isLoading = holdingsAsync.isLoading;
    final displayCount = _showAllHoldings ? holdings.length : 10;
    final displayHoldings = holdings.take(displayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header
        InkWell(
          onTap: () => setState(() => _holdingsExpanded = !_holdingsExpanded),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _holdingsExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n?.holdingsSnapshot ?? 'Holdings Snapshot',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (holdings.isNotEmpty)
                  Text(
                    '${holdings.length} ${l10n?.positions ?? 'positions'}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Collapsible content
        if (_holdingsExpanded) ...[
          const SizedBox(height: 8),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (holdings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n?.noHoldingsData ?? 'No holdings data available',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    child: Text('#',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(l10n?.ticker ?? 'Ticker',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(l10n?.weight ?? 'Weight',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(l10n?.value ?? 'Value',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Holdings rows
            ...List.generate(displayHoldings.length, (index) {
              final h = displayHoldings[index];
              return _HoldingRow(
                rank: index + 1,
                ticker: h.ticker,
                name: h.companyName,
                weight: h.weightPercent,
                value: h.marketValue,
              );
            }),
            if (holdings.length > 10) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllHoldings = !_showAllHoldings),
                  child: Text(
                    _showAllHoldings
                        ? (l10n?.showTop10 ?? 'Show top 10')
                        : (l10n?.viewAllHoldings(holdings.length) ?? 'View all ${holdings.length} holdings'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildFallbackContent() {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.portfolioOverviewUnavailable,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar for a single sector in the breakdown chart.
class _SectorBar extends StatelessWidget {
  final String label;
  final double pct;
  final int count;

  const _SectorBar({
    required this.label,
    required this.pct,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth =
                    (pct / 100).clamp(0.0, 1.0) * constraints.maxWidth;
                return Stack(
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      height: 16,
                      width: barWidth.clamp(2.0, constraints.maxWidth),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge showing a buy/sell change ticker.
class _ChangeBadge extends StatelessWidget {
  final String ticker;
  final String type;
  final bool isBuy;

  const _ChangeBadge({
    required this.ticker,
    required this.type,
    required this.isBuy,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBuy ? AppColors.success : AppColors.error;
    final prefix = isBuy ? '+' : '-';
    final label = type == 'new'
        ? 'NEW'
        : type == 'sold_out'
            ? 'EXIT'
            : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$prefix$ticker${label.isNotEmpty ? ' $label' : ''}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 2: HOLDINGS CHANGES (Redesigned with per-stock cards)
// ============================================================================

class _HoldingsChangesSection extends ConsumerStatefulWidget {
  final String investorId;
  final String investorName;
  final String updateFrequency; // 'Daily', 'Quarterly', etc.
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<StockChangeItem> stockChanges;
  final bool isLoading;
  final Set<String> flippedStockCards;
  final void Function(String ticker) onToggleStockFlip;

  const _HoldingsChangesSection({
    required this.investorId,
    required this.investorName,
    required this.updateFrequency,
    required this.isExpanded,
    required this.onToggle,
    required this.stockChanges,
    this.isLoading = false,
    required this.flippedStockCards,
    required this.onToggleStockFlip,
  });

  /// Check if this investor updates daily (e.g., ARK ETFs)
  bool get isDailyUpdater => updateFrequency.toLowerCase() == 'daily';

  /// Check if this investor updates quarterly (e.g., 13F filers)
  bool get isQuarterlyUpdater => updateFrequency.toLowerCase() == 'quarterly';

  @override
  ConsumerState<_HoldingsChangesSection> createState() =>
      _HoldingsChangesSectionState();
}

class _HoldingsChangesSectionState extends ConsumerState<_HoldingsChangesSection> {
  bool _isRestExpanded = false; // Track if remaining transactions are expanded

  /// Parse absolute numeric value from formatted shares string like "+3,883,145"
  static int _parseAbsShares(String formatted) {
    final cleaned = formatted.replaceAll(RegExp(r'[,+\s]'), '');
    return (int.tryParse(cleaned) ?? 0).abs();
  }

  /// Parse signed numeric value from formatted shares string like "+3,883,145" or "-1,234"
  static int _parseSignedShares(String formatted) {
    final isNegative = formatted.contains('-');
    final cleaned = formatted.replaceAll(RegExp(r'[,+\-\s]'), '');
    final value = int.tryParse(cleaned) ?? 0;
    return isNegative ? -value : value;
  }

  /// Format number with commas and sign
  static String _formatSharesDelta(int value) {
    final formatter = NumberFormat('#,###');
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${formatter.format(value)}';
  }

  /// Aggregate transactions by ticker - combines multiple trades of same stock into one entry
  static List<StockChangeItem> _aggregateByTicker(List<StockChangeItem> items) {
    if (items.isEmpty) return items;

    // Group by ticker
    final Map<String, List<StockChangeItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.ticker, () => []).add(item);
    }

    // Aggregate each group
    final List<StockChangeItem> aggregated = [];
    for (final entry in grouped.entries) {
      final ticker = entry.key;
      final group = entry.value;

      if (group.length == 1) {
        // No aggregation needed
        aggregated.add(group.first);
      } else {
        // Aggregate multiple transactions
        // Sum up shares delta
        int totalDelta = 0;
        for (final item in group) {
          totalDelta += _parseSignedShares(item.sharesDelta);
        }

        // Find date range (earliest to latest)
        final dates = group.map((e) => e.rawDate).toList()..sort();
        final earliestDate = dates.first;
        final latestDate = dates.last;

        // Format date range - always include year to avoid confusion
        String dateRange;
        if (earliestDate == latestDate) {
          dateRange = group.first.dateRange;
        } else {
          // Parse and format dates with year
          try {
            final startDate = DateTime.parse(earliestDate);
            final endDate = DateTime.parse(latestDate);
            // If same year, show year only at the end
            if (startDate.year == endDate.year) {
              final startStr = DateFormat('MMM d').format(startDate);
              final endStr = DateFormat('MMM d, yyyy').format(endDate);
              dateRange = '$startStr - $endStr';
            } else {
              final startStr = DateFormat('MMM d, yyyy').format(startDate);
              final endStr = DateFormat('MMM d, yyyy').format(endDate);
              dateRange = '$startStr - $endStr';
            }
          } catch (_) {
            dateRange = '$earliestDate - $latestDate';
          }
        }

        // Determine change type (NEW takes priority, then ADDED/REDUCED)
        String changeType = group.first.changeType;
        for (final item in group) {
          if (item.changeType == 'NEW') {
            changeType = 'NEW';
            break;
          }
          if (item.changeType == 'SOLD_OUT') {
            changeType = 'SOLD_OUT';
            break;
          }
        }

        // Combine all trades
        final allTrades = <StockTradeData>[];
        for (final item in group) {
          allTrades.addAll(item.trades);
        }

        // Calculate combined price range (min low, max high across all transactions)
        double? minLow;
        double? maxHigh;
        for (final item in group) {
          if (item.priceRange != null && item.priceRange!.isNotEmpty) {
            // Parse price range like "$24.79 - $27.66"
            final match = RegExp(r'\$?([\d.]+)\s*-\s*\$?([\d.]+)').firstMatch(item.priceRange!);
            if (match != null) {
              final low = double.tryParse(match.group(1) ?? '');
              final high = double.tryParse(match.group(2) ?? '');
              if (low != null) {
                minLow = minLow == null ? low : (low < minLow ? low : minLow);
              }
              if (high != null) {
                maxHigh = maxHigh == null ? high : (high > maxHigh ? high : maxHigh);
              }
            }
          }
        }

        // Format combined price range
        String? combinedPriceRange;
        if (minLow != null && maxHigh != null) {
          combinedPriceRange = '\$${minLow.toStringAsFixed(2)} - \$${maxHigh.toStringAsFixed(2)}';
        }

        // Calculate estimated value = total shares × average price
        String? combinedEstimatedValue;
        if (minLow != null && maxHigh != null && totalDelta != 0) {
          final avgPrice = (minLow + maxHigh) / 2;
          final totalValue = totalDelta.abs() * avgPrice;
          if (totalValue >= 1e9) {
            combinedEstimatedValue = '\$${(totalValue / 1e9).toStringAsFixed(1)}B';
          } else if (totalValue >= 1e6) {
            combinedEstimatedValue = '\$${(totalValue / 1e6).toStringAsFixed(1)}M';
          } else if (totalValue >= 1e3) {
            combinedEstimatedValue = '\$${(totalValue / 1e3).toStringAsFixed(0)}K';
          } else {
            combinedEstimatedValue = '\$${totalValue.toStringAsFixed(0)}';
          }
        }

        // Create aggregated item using the most recent date for sorting
        // For sharesDisplay: buys show +X, sells show -X (keep the sign)
        aggregated.add(StockChangeItem(
          ticker: ticker,
          name: group.first.name,
          changeType: changeType,
          sharesDelta: _formatSharesDelta(totalDelta),
          sharesDisplay: _formatSharesDelta(totalDelta),
          weightDelta: group.first.weightDelta, // Use first item's weight
          date: group.first.date, // Use most recent formatted date
          rawDate: latestDate, // Use latest date for sorting
          dateRange: dateRange,
          priceRange: combinedPriceRange ?? group.first.priceRange,
          estimatedValue: combinedEstimatedValue ?? group.first.estimatedValue,
          trades: allTrades,
          evidence: group.first.evidence,
        ));
      }
    }

    return aggregated;
  }

  void _toggleSelection(String uniqueKey) {
    final currentSelected = ref.read(selectedTransactionsProvider);
    final newSelected = Set<String>.from(currentSelected);
    if (newSelected.contains(uniqueKey)) {
      newSelected.remove(uniqueKey);
    } else {
      newSelected.add(uniqueKey);
    }
    ref.read(selectedTransactionsProvider.notifier).state = newSelected;
  }

  void _showCombinedReport(BuildContext context) {
    final selectedKeys = ref.read(selectedTransactionsProvider).toList();
    if (selectedKeys.isEmpty) return;

    // Reset the report notifier before showing
    ref.read(combinedReportNotifierProvider.notifier).reset();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => CombinedTransactionReportSheet(
          investorId: widget.investorId,
          investorName: widget.investorName,
          selectedKeys: selectedKeys,  // Pass unique keys instead of just tickers
        ),
      ),
    );
  }

  /// Filter changes to only recent 7 days for daily investors
  List<StockChangeItem> _filterToRecent7Days(List<StockChangeItem> changes) {
    if (changes.isEmpty) return changes;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return changes.where((item) {
      if (item.rawDate.isEmpty) return false;
      try {
        final date = DateTime.parse(item.rawDate);
        return date.isAfter(sevenDaysAgo) ||
               date.isAtSameMomentAs(sevenDaysAgo);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// Compute subtitle text based on investor type and data range
  String _computeSubtitle(List<StockChangeItem> changes) {
    if (changes.isEmpty) return '';

    // Collect all dates from the changes
    final dates = <DateTime>[];
    for (final change in changes) {
      if (change.rawDate.isNotEmpty) {
        try {
          dates.add(DateTime.parse(change.rawDate));
        } catch (_) {}
      }
    }

    if (dates.isEmpty) return '';

    dates.sort();
    final earliest = dates.first;
    final latest = dates.last;

    // Format the date range
    final dateFormat = DateFormat('MMM d');
    if (earliest.year != latest.year) {
      final fullFormat = DateFormat('MMM d, yyyy');
      return '${fullFormat.format(earliest)} - ${fullFormat.format(latest)}';
    } else if (earliest.month == latest.month && earliest.day == latest.day) {
      // Same day
      return dateFormat.format(latest);
    } else {
      return '${dateFormat.format(earliest)} - ${dateFormat.format(latest)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use provider-based localization to ensure proper rebuilding
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final isSelectMode = ref.watch(transactionSelectModeProvider);
    final selectedTickers = ref.watch(selectedTransactionsProvider);

    // For daily investors (ARK ETFs): filter to only last 7 days
    // For quarterly investors (13F): use all data (represents latest filing)
    List<StockChangeItem> filteredChanges;
    if (widget.isDailyUpdater) {
      filteredChanges = _filterToRecent7Days(widget.stockChanges);
    } else {
      // 13F filers: use all changes (they represent the latest filing period)
      filteredChanges = widget.stockChanges;
    }

    // Separate filtered changes into buys and sells, then aggregate by ticker
    // This combines multiple trades of the same stock into one entry with date range
    final rawBuys = filteredChanges
        .where((c) => c.changeType == 'NEW' || c.changeType == 'ADDED')
        .toList();
    final rawSells = filteredChanges
        .where((c) => c.changeType == 'REDUCED' || c.changeType == 'SOLD_OUT')
        .toList();

    // Aggregate transactions by ticker (e.g., BLSH traded on Feb 4, 5, 6 -> one entry)
    final aggregatedBuys = _aggregateByTicker(rawBuys);
    final aggregatedSells = _aggregateByTicker(rawSells);

    // Sort by: 1) Transaction size (biggest first), 2) Most recent date
    final allBuys = aggregatedBuys
      ..sort((a, b) {
          // Sort by transaction size first (biggest first)
          final sizeCompare = _parseAbsShares(b.sharesDelta).compareTo(_parseAbsShares(a.sharesDelta));
          if (sizeCompare != 0) return sizeCompare;
          // Then by date (most recent first)
          return b.rawDate.compareTo(a.rawDate);
        });

    final allSells = aggregatedSells
      ..sort((a, b) {
          // Sort by transaction size first (biggest first)
          final sizeCompare = _parseAbsShares(b.sharesDelta).compareTo(_parseAbsShares(a.sharesDelta));
          if (sizeCompare != 0) return sizeCompare;
          // Then by date (most recent first)
          return b.rawDate.compareTo(a.rawDate);
        });

    // Top 5 buys and top 5 sells with rank for AI reasoning access control
    // Rank 1-5 = free tier can access AI reasoning
    // Rank 6+ = paid tier only
    final topBuys = allBuys.take(5).toList().asMap().entries
        .map((e) => e.value.copyWithRank(e.key + 1))
        .toList();
    final topSells = allSells.take(5).toList().asMap().entries
        .map((e) => e.value.copyWithRank(e.key + 1))
        .toList();

    // Remaining transactions (rank 6+, requires paid plan for AI reasoning)
    final restBuys = allBuys.skip(5).toList().asMap().entries
        .map((e) => e.value.copyWithRank(e.key + 6))  // Rank starts at 6
        .toList();
    final restSells = allSells.skip(5).toList().asMap().entries
        .map((e) => e.value.copyWithRank(e.key + 6))  // Rank starts at 6
        .toList();

    final restCount = restBuys.length + restSells.length;

    // Compute dynamic subtitle based on investor type
    final String subtitle;
    if (widget.isDailyUpdater) {
      final dateRange = _computeSubtitle(filteredChanges);
      subtitle = dateRange.isNotEmpty ? 'Past week ($dateRange)' : 'Past week';
    } else if (widget.isQuarterlyUpdater) {
      final dateRange = _computeSubtitle(filteredChanges);
      subtitle = dateRange.isNotEmpty ? 'Latest 13F filing ($dateRange)' : 'Latest 13F filing';
    } else {
      subtitle = l10n.last30Days;
    }

    return _ExpandableSection(
      title: l10n.holdingsChanges,
      icon: Icons.swap_vert,
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggle,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Select mode toggle
          GestureDetector(
            onTap: () {
              final newMode = !isSelectMode;
              ref.read(transactionSelectModeProvider.notifier).state = newMode;
              if (!newMode) {
                // Clear selections when exiting select mode
                ref.read(selectedTransactionsProvider.notifier).state = {};
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelectMode
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelectMode
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelectMode ? Icons.close : Icons.checklist_rounded,
                    size: 12,
                    color: isSelectMode ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSelectMode ? (l10n?.cancel ?? 'Cancel') : (l10n?.selectForReport ?? 'Select for Report'),
                    style: TextStyle(
                      color: isSelectMode ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.nChanges(filteredChanges.length),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      child: widget.isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : filteredChanges.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      widget.isDailyUpdater
                          ? 'No changes in the past week'
                          : widget.isQuarterlyUpdater
                              ? 'No changes in latest 13F filing'
                              : l10n.noChangesLast30Days,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top 5 Buys
                    if (topBuys.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              l10n.topBuys,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${allBuys.length} total)',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...topBuys.map((item) => _SelectableStockCard(
                            investorId: widget.investorId,
                            item: item,
                            isSelectMode: isSelectMode,
                            isSelected: selectedTickers.contains(item.uniqueKey),
                            onToggleSelection: () => _toggleSelection(item.uniqueKey),
                            isFlipped: widget.flippedStockCards.contains(item.ticker),
                            onToggleFlip: () => widget.onToggleStockFlip(item.ticker),
                          )),
                      const SizedBox(height: 12),
                    ],

                    // Top 5 Sells
                    if (topSells.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              l10n.topSells,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${allSells.length} total)',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...topSells.map((item) => _SelectableStockCard(
                            investorId: widget.investorId,
                            item: item,
                            isSelectMode: isSelectMode,
                            isSelected: selectedTickers.contains(item.uniqueKey),
                            onToggleSelection: () => _toggleSelection(item.uniqueKey),
                            isFlipped: widget.flippedStockCards.contains(item.ticker),
                            onToggleFlip: () => widget.onToggleStockFlip(item.ticker),
                          )),
                    ],

                    // Remaining transactions (folded by default, requires Pro for AI reasoning)
                    if (restCount > 0) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() {
                          _isRestExpanded = !_isRestExpanded;
                        }),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isRestExpanded ? Icons.expand_less : Icons.expand_more,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRestExpanded
                                    ? 'Hide $restCount more transactions'
                                    : 'Show $restCount more transactions',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 10,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Pro',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isRestExpanded) ...[
                        const SizedBox(height: 8),
                        // Remaining buys
                        if (restBuys.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, top: 4),
                            child: Text(
                              'More Buys',
                              style: TextStyle(
                                color: AppColors.success.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ...restBuys.map((item) => _SelectableStockCard(
                                investorId: widget.investorId,
                                item: item,
                                isSelectMode: isSelectMode,
                                isSelected: selectedTickers.contains(item.uniqueKey),
                                onToggleSelection: () => _toggleSelection(item.uniqueKey),
                                isFlipped: widget.flippedStockCards.contains(item.ticker),
                                onToggleFlip: () => widget.onToggleStockFlip(item.ticker),
                              )),
                        ],
                        // Remaining sells
                        if (restSells.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, top: 8),
                            child: Text(
                              'More Sells',
                              style: TextStyle(
                                color: AppColors.error.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ...restSells.map((item) => _SelectableStockCard(
                                investorId: widget.investorId,
                                item: item,
                                isSelectMode: isSelectMode,
                                isSelected: selectedTickers.contains(item.uniqueKey),
                                onToggleSelection: () => _toggleSelection(item.uniqueKey),
                                isFlipped: widget.flippedStockCards.contains(item.ticker),
                                onToggleFlip: () => widget.onToggleStockFlip(item.ticker),
                              )),
                        ],
                      ],
                    ],

                    // Selection action bar
                    if (isSelectMode && selectedTickers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                l10n?.nSelected(selectedTickers.length) ?? '${selectedTickers.length} selected',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                ref.read(selectedTransactionsProvider.notifier).state = {};
                              },
                              child: Text(
                                l10n?.clear ?? 'Clear',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showCombinedReport(context),
                              icon: const Icon(Icons.assessment_rounded, size: 16),
                              label: Text(l10n?.generateReport ?? 'Generate Report'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

// ============================================================================
// PER-STOCK CARD - Opens multi-agent reasoning sheet on tap
// ============================================================================

class _StockChangeCard extends ConsumerWidget {
  final String investorId;
  final StockChangeItem item;
  final bool isFlipped; // Kept for API compatibility but not used
  final VoidCallback onToggleFlip; // Kept for API compatibility but not used

  const _StockChangeCard({
    required this.investorId,
    required this.item,
    required this.isFlipped,
    required this.onToggleFlip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _StockChangeCardFront(
        investorId: investorId,
        item: item,
      ),
    );
  }
}

/// Stock change card with optional checkbox for multi-select mode.
class _SelectableStockCard extends ConsumerWidget {
  final String investorId;
  final StockChangeItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final bool isFlipped;
  final VoidCallback onToggleFlip;

  const _SelectableStockCard({
    required this.investorId,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.isFlipped,
    required this.onToggleFlip,
  });

  void _handleReasoningTap(BuildContext context, WidgetRef ref) {
    final subscription = ref.read(subscriptionProvider).valueOrNull;
    final rank = item.rank ?? 999;

    // Check if user can access AI reasoning for this rank
    if (subscription != null && !subscription.canAccessAiReasoning(rank)) {
      // Show upgrade prompt
      UpgradePrompt.show(
        context,
        title: 'AI Reasoning Limit',
        message: 'Free users can access AI reasoning for the Top 5 Buys and Top 5 Sells. '
            'Upgrade to Pro for unlimited AI analysis on all transactions.',
        ctaText: 'Upgrade to Pro',
      );
      return;
    }

    // Show reasoning sheet
    showMultiAgentReasoningSheet(
      context,
      investorId: investorId,
      ticker: item.ticker,
      companyName: item.name,
      changeType: item.changeType,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final isBuy = item.changeType == 'NEW' || item.changeType == 'ADDED';
    final trade = item.trades.isNotEmpty ? item.trades.first : null;
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final rank = item.rank ?? 999;
    final isLocked = subscription != null && !subscription.canAccessAiReasoning(rank);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          if (isSelectMode) {
            onToggleSelection();
          } else {
            _handleReasoningTap(context, ref);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox (shown in select mode)
              if (isSelectMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              // BUY/SELL icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isBuy
                      ? AppColors.successBackground
                      : AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isBuy ? AppColors.success : AppColors.error,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              // Ticker, name, change type badge, fund badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.ticker,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ChangeTypeBadge(
                          type: item.changeType,
                          color: item.changeColor,
                        ),
                        if (trade != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundAlt,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              trade.fund,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Shares delta, est. value, price range, date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Shares change with "shares" label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.sharesDisplay.isNotEmpty ? item.sharesDisplay : item.sharesDelta,
                        style: TextStyle(
                          color: item.changeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l10n?.shares ?? 'shares',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  // Estimated value
                  if (item.estimatedValue != null && item.estimatedValue!.isNotEmpty)
                    Text(
                      '${l10n?.estimated ?? 'Est.'} ${item.estimatedValue}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    )
                  else if (trade != null)
                    Text(
                      '${l10n?.estimated ?? 'Est.'} ${trade.value}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  // Price range
                  if (item.priceRange != null && item.priceRange!.isNotEmpty)
                    Text(
                      item.priceRange!,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  // Date range
                  Text(
                    (item.dateRange.isNotEmpty) ? item.dateRange : item.date,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              // Trailing indicator (checkbox in select mode, brain/lock icon otherwise)
              if (!isSelectMode) ...[
                const SizedBox(width: 8),
                Icon(
                  isLocked ? Icons.lock_outline : Icons.psychology_outlined,
                  color: isLocked
                      ? AppColors.textTertiary
                      : AppColors.primary.withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD FRONT: Stock change summary - opens multi-agent reasoning on tap
// ============================================================================

class _StockChangeCardFront extends ConsumerWidget {
  final String investorId;
  final StockChangeItem item;

  const _StockChangeCardFront({
    required this.investorId,
    required this.item,
  });

  void _handleReasoningTap(BuildContext context, WidgetRef ref) {
    final subscription = ref.read(subscriptionProvider).valueOrNull;
    final rank = item.rank ?? 999;

    // Check if user can access AI reasoning for this rank
    if (subscription != null && !subscription.canAccessAiReasoning(rank)) {
      // Show upgrade prompt
      UpgradePrompt.show(
        context,
        title: 'AI Reasoning Limit',
        message: 'Free users can access AI reasoning for the Top 5 Buys and Top 5 Sells. '
            'Upgrade to Pro for unlimited AI analysis on all transactions.',
        ctaText: 'Upgrade to Pro',
      );
      return;
    }

    // Show reasoning sheet
    showMultiAgentReasoningSheet(
      context,
      investorId: investorId,
      ticker: item.ticker,
      companyName: item.name,
      changeType: item.changeType,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final isBuy = item.changeType == 'NEW' || item.changeType == 'ADDED';
    // Use first trade for estimated value and fund info
    final trade = item.trades.isNotEmpty ? item.trades.first : null;
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final rank = item.rank ?? 999;
    final isLocked = subscription != null && !subscription.canAccessAiReasoning(rank);

    return GestureDetector(
      onTap: () => _handleReasoningTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // BUY/SELL icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isBuy
                    ? AppColors.successBackground
                    : AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                color: isBuy ? AppColors.success : AppColors.error,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            // Ticker, name, change type badge, fund badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.ticker,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ChangeTypeBadge(
                        type: item.changeType,
                        color: item.changeColor,
                      ),
                      if (trade != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            trade.fund,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Shares delta, est. value, price range, date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Shares change with "shares" label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.sharesDisplay.isNotEmpty ? item.sharesDisplay : item.sharesDelta,
                      style: TextStyle(
                        color: item.changeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      l10n?.shares ?? 'shares',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                // Estimated value
                if (item.estimatedValue != null && item.estimatedValue!.isNotEmpty)
                  Text(
                    '${l10n?.estimated ?? 'Est.'} ${item.estimatedValue}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  )
                else if (trade != null)
                  Text(
                    '${l10n?.estimated ?? 'Est.'} ${trade.value}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                // Price range
                if (item.priceRange != null && item.priceRange!.isNotEmpty)
                  Text(
                    item.priceRange!,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                // Date range
                Text(
                  (item.dateRange.isNotEmpty) ? item.dateRange : item.date,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Brain/lock icon indicates AI analysis available/locked
            Icon(
              isLocked ? Icons.lock_outline : Icons.psychology_outlined,
              color: isLocked
                  ? AppColors.textTertiary
                  : AppColors.primary.withValues(alpha: 0.7),
              size: 18,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARD BACK: Per-stock Evidence & AI Reasoning
// ============================================================================

class _StockChangeCardBack extends ConsumerWidget {
  final String investorId;
  final StockChangeItem item;
  final VoidCallback onFlipBack;

  const _StockChangeCardBack({
    super.key,
    required this.investorId,
    required this.item,
    required this.onFlipBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rationaleAsync = ref.watch(companyRationaleProvider(
      (investorId: investorId, ticker: item.ticker),
    ));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    size: 14,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evidence: ${item.ticker}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onFlipBack,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Per-stock reasoning content — loaded from backend
          Padding(
            padding: const EdgeInsets.all(12),
            child: rationaleAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => _buildFallbackContent(),
              data: (rationale) {
                if (rationale == null) return _buildFallbackContent();
                return _buildRationaleContent(rationale);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the full AI rationale content from backend response.
  Widget _buildRationaleContent(Map<String, dynamic> data) {
    final companyOverview = data['company_overview'] as String? ?? '';
    final activitySummary =
        data['investor_activity_summary'] as String? ?? '';
    final rationales =
        (data['possible_rationales'] as List?) ?? [];
    final evidencePanelData =
        data['evidence_panel'] as Map<String, dynamic>?;
    final whatIsUnknown = data['what_is_unknown'] as String? ?? '';
    final disclaimer = data['disclaimer'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Company overview
        if (companyOverview.isNotEmpty) ...[
          Text(
            companyOverview,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Activity summary
        if (activitySummary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              activitySummary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Possible rationales with confidence
        if (rationales.isNotEmpty) ...[
          const Text(
            'Possible Rationales',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...rationales.map((r) {
            final hypothesis = r['hypothesis'] as String? ?? '';
            final confidence = r['confidence'] as String? ?? 'low';
            final signals =
                (r['supporting_signals'] as List?)?.cast<String>() ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: confidence == 'medium'
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : AppColors.textTertiary
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            confidence.toUpperCase(),
                            style: TextStyle(
                              color: confidence == 'medium'
                                  ? AppColors.warning
                                  : AppColors.textTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Hypothesis',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hypothesis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (signals.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...signals.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppColors.textTertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],

        // Evidence panel from backend
        if (evidencePanelData != null)
          EvidencePanel(
            data: EvidencePanelData.fromJson(evidencePanelData),
            initiallyExpanded: true,
          ),

        // What is unknown
        if (whatIsUnknown.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline,
                    color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    whatIsUnknown,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Disclaimer
        if (disclaimer.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            disclaimer,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// Fallback when backend AI is unavailable.
  Widget _buildFallbackContent() {
    // If we have static evidence from the StockChangeItem, show that
    if (item.evidence != null) {
      return EvidencePanel(
        data: item.evidence!,
        initiallyExpanded: true,
      );
    }

    // Otherwise show unavailable message
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off,
              color: AppColors.textTertiary, size: 28),
          const SizedBox(height: 8),
          const Text(
            'AI reasoning unavailable',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect to backend with AI keys configured to see LLM-generated evidence and hypotheses for this stock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHANGE TYPE BADGE
// ============================================================================

class _ChangeTypeBadge extends StatelessWidget {
  final String type;
  final Color color;

  const _ChangeTypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    // Display localized labels for change types
    final label = type == 'SOLD_OUT' ? 'SOLD' : type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final int rank;
  final String ticker;
  final String name;
  final String weight;
  final String value;

  const _HoldingRow({
    required this.rank,
    required this.ticker,
    required this.name,
    required this.weight,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticker,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                weight,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED: EXPANDABLE SECTION WRAPPER
// ============================================================================

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final Color? headerColor;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    this.subtitle,
    this.trailing,
    required this.child,
    this.headerColor,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _rotation = _controller.drive(Tween(begin: 0.0, end: 0.5));
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.headerColor ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: widget.onToggle,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 8),
                  ],
                  RotationTransition(
                    turns: _rotation,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Align(
                  heightFactor: _heightFactor.value,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
