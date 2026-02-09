import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/transparency_badge.dart';
import '../../../../core/widgets/upgrade_prompt.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../models/investor_card_model.dart';
import '../../providers/home_provider.dart';
import '../../providers/investor_tracking_provider.dart';

/// Modal bottom sheet for selecting and adding investors.
///
/// Features:
/// - Shows all available investors by default
/// - Search/filter by investor name
/// - Shows tracking count and limit based on subscription
/// - Checks subscription limits before adding
/// - Shows calm UpgradePrompt if limit exceeded
class InvestorSearchModal extends ConsumerStatefulWidget {
  const InvestorSearchModal({super.key});

  /// Show the modal
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => const InvestorSearchModal(),
      ),
    );
  }

  @override
  ConsumerState<InvestorSearchModal> createState() =>
      _InvestorSearchModalState();
}

class _InvestorSearchModalState extends ConsumerState<InvestorSearchModal> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debouncer.run(() {
      setState(() {
        _searchQuery = value.trim().toLowerCase();
      });
    });
  }

  Future<void> _onInvestorSelected(InvestorCardModel investor) async {
    // Check subscription limits before attempting to add
    final subscription = ref.read(subscriptionProvider).valueOrNull;
    final currentCount = subscription?.monitoredInvestorsCount ?? 0;
    final maxAllowed = subscription?.maxMonitoredInvestors ?? 2;
    final isUnlimited = maxAllowed == -1;

    // Check if limit would be exceeded
    if (!isUnlimited && currentCount >= maxAllowed) {
      String upgradeMessage;

      if (subscription?.tier == 'free') {
        upgradeMessage = 'Free users can track up to 2 investors (including Berkshire Hathaway). '
            'Upgrade to Pro to track up to 10 investors.';
      } else if (subscription?.tier == 'pro') {
        upgradeMessage = 'Pro users can track up to 10 investors. '
            'Upgrade to Pro+ for unlimited investor tracking.';
      } else {
        upgradeMessage = 'You\'ve reached your tracking limit.';
      }

      await UpgradePrompt.show(
        context,
        title: 'Tracking Limit Reached',
        message: upgradeMessage,
        ctaText: subscription?.tier == 'pro' ? 'Upgrade to Pro+' : 'Upgrade to Pro',
      );
      return;
    }

    // Proceed with adding investor
    final result = await ref
        .read(investorTrackingProvider.notifier)
        .addInvestor(investor.id);

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      context.push('/investor/${investor.id}');
    } else if (result.limitReached) {
      // Show calm upgrade prompt (backup check)
      await UpgradePrompt.show(
        context,
        title: 'Tracking Limit Reached',
        message: result.message,
      );
    } else {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Failed to add investor'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    final allInvestors = ref.watch(allInvestorsProvider);
    final subscription = ref.watch(subscriptionProvider);

    // Get tracking info
    final currentCount = subscription.valueOrNull?.monitoredInvestorsCount ?? 0;
    final maxAllowed = subscription.valueOrNull?.maxMonitoredInvestors ?? 2;
    final isUnlimited = maxAllowed == -1;
    final canAddMore = isUnlimited || currentCount < maxAllowed;
    final tierName = subscription.valueOrNull?.tierDisplayName ?? 'Free';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with tracking count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Investor',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tracking count indicator
                      Row(
                        children: [
                          Icon(
                            canAddMore ? Icons.check_circle_outline : Icons.info_outline,
                            color: canAddMore ? AppColors.success : AppColors.warning,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isUnlimited
                                ? 'Tracking $currentCount investors ($tierName)'
                                : 'Tracking $currentCount of $maxAllowed investors ($tierName)',
                            style: TextStyle(
                              color: canAddMore ? AppColors.textSecondary : AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Filter investors...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Investor list
          Expanded(
            child: allInvestors.when(
              data: (investors) {
                // Filter by search query
                final filtered = _searchQuery.isEmpty
                    ? investors
                    : investors.where((i) =>
                        i.name.toLowerCase().contains(_searchQuery) ||
                        i.investorType.toLowerCase().contains(_searchQuery)).toList();

                if (filtered.isEmpty) {
                  return _buildNoResults();
                }
                return _buildInvestorList(filtered, canAddMore);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (_, __) => _buildError(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            color: AppColors.textTertiary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No investors found for "$_searchQuery"',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.textTertiary,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestorList(List<InvestorCardModel> investors, bool canAddMore) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: investors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final investor = investors[index];
        return _InvestorListItem(
          investor: investor,
          canAdd: canAddMore,
          onTap: () => _onInvestorSelected(investor),
        );
      },
    );
  }
}

class _InvestorListItem extends StatefulWidget {
  final InvestorCardModel investor;
  final bool canAdd;
  final VoidCallback onTap;

  const _InvestorListItem({
    required this.investor,
    required this.canAdd,
    required this.onTap,
  });

  @override
  State<_InvestorListItem> createState() => _InvestorListItemState();
}

class _InvestorListItemState extends State<_InvestorListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDefault = widget.investor.id == 'berkshire-hathaway';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceLight : AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.investor.name.isNotEmpty
                        ? widget.investor.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.investor.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          widget.investor.investorTypeDisplay,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.investor.disclosureTypeDisplay,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Transparency badge
              if (widget.investor.transparencyScore != null) ...[
                const SizedBox(width: 8),
                TransparencyBadge.fromScore(
                  widget.investor.transparencyScore!,
                  compact: true,
                ),
              ],
              const SizedBox(width: 8),
              // Add icon (dimmed if at limit and not unlimited)
              Icon(
                widget.canAdd ? Icons.add_circle_outline : Icons.lock_outline,
                color: widget.canAdd
                    ? (_isHovered ? AppColors.primary : AppColors.textTertiary)
                    : AppColors.textTertiary.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple debouncer for search input
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
