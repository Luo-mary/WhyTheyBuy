import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/transparency_badge.dart';
import '../../../../core/widgets/upgrade_prompt.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../models/investor_card_model.dart';
import '../../providers/home_provider.dart';
import '../../providers/investor_tracking_provider.dart';
import 'featured_investor.dart'
    show getLocalizedInvestorType, getLocalizedDisclosureType;

/// Recommended investors section showing 3 investor cards.
///
/// Features a shuffle button to load another set of recommendations.
class RecommendedInvestors extends ConsumerWidget {
  const RecommendedInvestors({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    final recommendedAsync = ref.watch(recommendedInvestorsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and shuffle button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)?.recommendedInvestors ??
                  'Recommended Investors',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            _ShuffleButton(
              onTap: () =>
                  ref.read(recommendedInvestorsProvider.notifier).shuffle(),
              isLoading: recommendedAsync.isLoading,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Investor cards (for discovery only - tap to add to watchlist)
        recommendedAsync.when(
          data: (investors) => _InvestorCardList(investors: investors, ref: ref),
          loading: () => const _InvestorCardListSkeleton(),
          error: (_, __) => const _InvestorCardListSkeleton(),
        ),
      ],
    );
  }
}

class _ShuffleButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _ShuffleButton({
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<_ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends State<_ShuffleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ShuffleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _controller.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: const Icon(
                  Icons.refresh,
                  color: AppColors.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)?.shuffle ?? 'Shuffle',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvestorCardList extends StatelessWidget {
  final List<InvestorCardModel> investors;
  final WidgetRef ref;

  const _InvestorCardList({required this.investors, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    if (isWide) {
      // Horizontal layout for wider screens
      return Row(
        children: investors.map((investor) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: investor != investors.last ? 8 : 0,
              ),
              child: _InvestorCard(investor: investor, ref: ref),
            ),
          );
        }).toList(),
      );
    }

    // Vertical layout for mobile
    return Column(
      children: investors.map((investor) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: investor != investors.last ? 8 : 0,
          ),
          child: _InvestorCard(investor: investor, ref: ref),
        );
      }).toList(),
    );
  }
}

class _InvestorCard extends StatefulWidget {
  final InvestorCardModel investor;
  final WidgetRef ref;

  const _InvestorCard({required this.investor, required this.ref});

  @override
  State<_InvestorCard> createState() => _InvestorCardState();
}

class _InvestorCardState extends State<_InvestorCard> {
  bool _isHovered = false;
  bool _isAdding = false;

  Future<void> _handleTap(BuildContext context) async {
    // Capture context-dependent objects before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Show confirmation dialog to add to watchlist
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AddToWatchlistDialog(
        investorName: widget.investor.name,
      ),
    );

    if (shouldAdd != true || !mounted) return;

    // Check subscription limits
    final subscription = widget.ref.read(subscriptionProvider).valueOrNull;
    if (subscription != null && !subscription.canAddInvestor) {
      // Show upgrade prompt
      final tierName = subscription.tier;
      String message;
      if (tierName == 'free') {
        message = 'Free users can track up to ${subscription.maxMonitoredInvestors} investors. '
            'Upgrade to Pro to track up to 10 investors.';
      } else if (tierName == 'pro') {
        message = 'Pro users can track up to ${subscription.maxMonitoredInvestors} investors. '
            'Upgrade to Pro+ for unlimited tracking.';
      } else {
        message = 'You\'ve reached your tracking limit of ${subscription.maxMonitoredInvestors} investors.';
      }

      if (mounted) {
        UpgradePrompt.show(
          context,
          title: 'Investor Limit Reached',
          message: message,
          ctaText: 'View Plans',
        );
      }
      return;
    }

    // Add to watchlist
    setState(() => _isAdding = true);

    final result = await widget.ref
        .read(investorTrackingProvider.notifier)
        .addInvestor(widget.investor.id);

    if (!mounted) return;
    setState(() => _isAdding = false);

    if (result.success) {
      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${widget.investor.name} added to your watchlist'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
      // Navigate to investor detail page
      router.push('/investor/${widget.investor.id}');
    } else if (result.limitReached) {
      // Show upgrade prompt
      if (mounted) {
        UpgradePrompt.show(
          context,
          title: 'Investor Limit Reached',
          message: result.message ?? 'You\'ve reached your tracking limit.',
          ctaText: 'View Plans',
        );
      }
    } else {
      // Show error
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Failed to add investor'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _isAdding ? null : () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Compact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
                    Text(
                      widget.investor.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Type badge
                    Text(
                      getLocalizedInvestorType(context, widget.investor.investorType),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Loading indicator or add icon
              if (_isAdding)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.add_circle_outline,
                  color: _isHovered ? AppColors.primary : AppColors.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to confirm adding an investor to watchlist
class _AddToWatchlistDialog extends StatelessWidget {
  final String investorName;

  const _AddToWatchlistDialog({required this.investorName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n?.addToWatchlistQuestion ?? 'Add to Watchlist?',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.addToWatchlistDescription(investorName) ?? 'Add "$investorName" to your watchlist to view their transactions and AI reasoning.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.onlyWatchlistedInvestors ?? 'Only watchlisted investors show transactions & AI insights.',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            l10n?.cancel ?? 'Cancel',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(l10n?.addToWatchlist ?? 'Add to Watchlist'),
        ),
      ],
    );
  }
}

class _InvestorCardListSkeleton extends StatelessWidget {
  const _InvestorCardListSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    if (isWide) {
      return Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
              child: const _InvestorCardSkeleton(),
            ),
          );
        }),
      );
    }

    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < 2 ? 8 : 0),
          child: const _InvestorCardSkeleton(),
        );
      }),
    );
  }
}

class _InvestorCardSkeleton extends StatelessWidget {
  const _InvestorCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.backgroundAlt,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
