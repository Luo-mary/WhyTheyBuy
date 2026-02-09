import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/transparency_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/investor_card_model.dart';
import '../../providers/home_provider.dart';

/// Helper to get localized investor type display
String getLocalizedInvestorType(BuildContext context, String investorType) {
  final l10n = AppLocalizations.of(context);
  switch (investorType.toLowerCase()) {
    case 'etf_manager':
      return l10n?.etfManager ?? 'ETF Manager';
    case 'hedge_fund':
      return l10n?.hedgeFund ?? 'Hedge Fund';
    case 'institutional':
      return l10n?.institutional ?? 'Institutional';
    case 'individual':
      return l10n?.individual ?? 'Individual';
    case 'insider':
      return l10n?.insider ?? 'Insider';
    default:
      return l10n?.unknown ?? investorType;
  }
}

/// Helper to get localized disclosure type display
String getLocalizedDisclosureType(BuildContext context, String? disclosureType) {
  final l10n = AppLocalizations.of(context);
  switch (disclosureType?.toLowerCase()) {
    case 'etf_holdings':
      return l10n?.dailyEtf ?? 'Daily ETF';
    case 'sec_13f':
      return l10n?.sec13f ?? 'SEC 13F';
    case 'n_port':
      return l10n?.nPort ?? 'N-PORT';
    case 'form_4':
      return l10n?.form4 ?? 'Form 4';
    default:
      return l10n?.unknown ?? disclosureType ?? 'Unknown';
  }
}

/// Featured investor card displayed prominently on home page.
///
/// Shows a well-known investor like Berkshire Hathaway as an entry point.
class FeaturedInvestor extends ConsumerWidget {
  const FeaturedInvestor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    final featuredAsync = ref.watch(featuredInvestorProvider);

    return featuredAsync.when(
      data: (investor) {
        if (investor == null) {
          return const SizedBox.shrink();
        }
        return _FeaturedInvestorCard(investor: investor);
      },
      loading: () => const _FeaturedInvestorSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FeaturedInvestorCard extends StatefulWidget {
  final InvestorCardModel investor;

  const _FeaturedInvestorCard({required this.investor});

  @override
  State<_FeaturedInvestorCard> createState() => _FeaturedInvestorCardState();
}

class _FeaturedInvestorCardState extends State<_FeaturedInvestorCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.push('/investor/${widget.investor.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon/Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.featured ?? 'Featured',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.investor.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
              const SizedBox(width: 8),
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

class _FeaturedInvestorSkeleton extends StatelessWidget {
  const _FeaturedInvestorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
