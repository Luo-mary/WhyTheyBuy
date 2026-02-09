import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/transparency_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/home_provider.dart';
import 'featured_investor.dart' show getLocalizedInvestorType;

/// Section showing the user's tracked investors (from their watchlist).
/// These are the investors the user can click to view transactions & AI reasoning.
class TrackedInvestors extends ConsumerWidget {
  final VoidCallback onAddInvestor;

  const TrackedInvestors({
    super.key,
    required this.onAddInvestor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    final trackedAsync = ref.watch(trackedInvestorsProvider);

    return trackedAsync.when(
      data: (investors) {
        if (investors.isEmpty) {
          // Show empty state with just the add button
          return _EmptyState(onAddInvestor: onAddInvestor);
        }
        return _TrackedInvestorsList(
          investors: investors,
          onAddInvestor: onAddInvestor,
        );
      },
      loading: () => const _TrackedInvestorsListSkeleton(),
      error: (_, __) => _EmptyState(onAddInvestor: onAddInvestor),
    );
  }
}

class _TrackedInvestorsList extends StatelessWidget {
  final List<TrackedInvestorModel> investors;
  final VoidCallback onAddInvestor;

  const _TrackedInvestorsList({
    required this.investors,
    required this.onAddInvestor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.myInvestors ?? 'My Investors',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            // Tracking count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n?.nTracked(investors.length) ?? '${investors.length} tracked',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Investor cards in a wrap or row
        if (isWide)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...investors.map((investor) => _TrackedInvestorCard(investor: investor)),
              _AddInvestorCard(onTap: onAddInvestor),
            ],
          )
        else
          Column(
            children: [
              ...investors.map((investor) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrackedInvestorCard(investor: investor),
              )),
              _AddInvestorCard(onTap: onAddInvestor),
            ],
          ),
      ],
    );
  }
}

class _TrackedInvestorCard extends StatefulWidget {
  final TrackedInvestorModel investor;

  const _TrackedInvestorCard({required this.investor});

  @override
  State<_TrackedInvestorCard> createState() => _TrackedInvestorCardState();
}

class _TrackedInvestorCardState extends State<_TrackedInvestorCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.push('/investor/${widget.investor.investorSlug}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isWide ? 320 : double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.investor.isDefault
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.investor.isDefault ? Icons.star_rounded : Icons.person_outline,
                  color: widget.investor.isDefault ? AppColors.primary : AppColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Default badge + name row
                    Row(
                      children: [
                        if (widget.investor.isDefault) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.defaultLabel ?? 'DEFAULT',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            widget.investor.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Type + transparency
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            getLocalizedInvestorType(context, widget.investor.investorType),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (widget.investor.transparencyScore != null) ...[
                          const SizedBox(width: 8),
                          TransparencyBadge.fromScore(
                            widget.investor.transparencyScore!,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: _isHovered ? AppColors.primary : AppColors.textTertiary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddInvestorCard extends StatefulWidget {
  final VoidCallback onTap;

  const _AddInvestorCard({required this.onTap});

  @override
  State<_AddInvestorCard> createState() => _AddInvestorCardState();
}

class _AddInvestorCardState extends State<_AddInvestorCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isWide ? 320 : double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.border,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                AppLocalizations.of(context)?.addInvestor ?? 'Add Investor',
                style: TextStyle(
                  color: _isHovered ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 15,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddInvestor;

  const _EmptyState({required this.onAddInvestor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.myInvestors ?? 'My Investors',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.noInvestorsTrackedYet ?? 'No investors tracked yet',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.addInvestorsToTrack ?? 'Add investors to track their holdings and get AI-powered insights.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAddInvestor,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n?.addYourFirstInvestor ?? 'Add Your First Investor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackedInvestorsListSkeleton extends StatelessWidget {
  const _TrackedInvestorsListSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 70,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isWide)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(2, (_) => const _CardSkeleton()),
          )
        else
          Column(
            children: List.generate(2, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _CardSkeleton(),
            )),
          ),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Container(
      width: isWide ? 320 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 90,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(4),
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
