import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';
import '../widgets/home_disclaimer.dart';
import '../widgets/investor_search_modal.dart';
import '../widgets/recommended_investors.dart';
import '../widgets/tracked_investors.dart';

/// Home page - the primary interaction surface.
///
/// Layout:
/// - Top: Tracked investors (user's watchlist) with add button
/// - Bottom: Recommended investors for discovery (click to add to watchlist)
/// - Footer: Disclaimer
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isDesktop) {
              return _DesktopLayout(
                onAddInvestor: () => InvestorSearchModal.show(context),
              );
            } else if (isTablet) {
              return _TabletLayout(
                onAddInvestor: () => InvestorSearchModal.show(context),
              );
            } else {
              return _MobileLayout(
                onAddInvestor: () => InvestorSearchModal.show(context),
              );
            }
          },
        ),
      ),
    );
  }
}

/// Desktop layout: Tracked investors at top, recommended below
class _DesktopLayout extends ConsumerWidget {
  final VoidCallback onAddInvestor;

  const _DesktopLayout({required this.onAddInvestor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trackedInvestorsProvider);
        ref.invalidate(recommendedInvestorsProvider);
        ref.invalidate(featuredInvestorProvider);
        await ref.read(trackedInvestorsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Tracked investors (user's watchlist)
            TrackedInvestors(onAddInvestor: onAddInvestor),
            const SizedBox(height: 48),
            // Bottom: Recommended investors for discovery
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: const RecommendedInvestors(),
            ),
            const SizedBox(height: 40),
            // Disclaimer footer
            const HomeDisclaimer(),
          ],
        ),
      ),
    );
  }
}

/// Tablet layout: Similar to desktop but more compact
class _TabletLayout extends ConsumerWidget {
  final VoidCallback onAddInvestor;

  const _TabletLayout({required this.onAddInvestor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trackedInvestorsProvider);
        ref.invalidate(recommendedInvestorsProvider);
        ref.invalidate(featuredInvestorProvider);
        await ref.read(trackedInvestorsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Tracked investors
            TrackedInvestors(onAddInvestor: onAddInvestor),
            const SizedBox(height: 40),
            // Bottom: Recommended investors
            const RecommendedInvestors(),
            const SizedBox(height: 32),
            // Disclaimer footer
            const HomeDisclaimer(),
          ],
        ),
      ),
    );
  }
}

/// Mobile layout: Stacked vertically
class _MobileLayout extends ConsumerWidget {
  final VoidCallback onAddInvestor;

  const _MobileLayout({required this.onAddInvestor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trackedInvestorsProvider);
        ref.invalidate(recommendedInvestorsProvider);
        ref.invalidate(featuredInvestorProvider);
        await ref.read(trackedInvestorsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Tracked investors
            TrackedInvestors(onAddInvestor: onAddInvestor),
            const SizedBox(height: 32),
            // Bottom: Recommended investors
            const RecommendedInvestors(),
            const SizedBox(height: 24),
            // Disclaimer footer
            const HomeDisclaimer(),
          ],
        ),
      ),
    );
  }
}
