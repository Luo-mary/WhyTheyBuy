import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Holdings change summaries and alerts',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '3 unread',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: true,
                          onSelected: (v) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Unread'),
                          selected: false,
                          onSelected: (v) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Alerts'),
                          selected: false,
                          onSelected: (v) {},
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Weekly Digest'),
                          selected: false,
                          onSelected: (v) {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reports list
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ReportCard(
                  title: 'ARK Innovation ETF: Tesla Accumulation Continues',
                  type: 'Holdings Change',
                  investorName: 'ARK Innovation ETF',
                  date: 'Today, 2:45 PM',
                  preview:
                      'ARKK added 15,000 shares of Tesla (TSLA) and initiated a new position in Coinbase...',
                  isUnread: true,
                  buys: 2,
                  sells: 1,
                  onTap: () => _showReportDetail(context),
                ),
                _ReportCard(
                  title: 'ARK Genomic Revolution: Biotech Rotation',
                  type: 'Holdings Change',
                  investorName: 'ARK Genomic Revolution',
                  date: 'Yesterday, 6:00 PM',
                  preview:
                      'ARKG made significant changes to biotech holdings, reducing EDIT and adding...',
                  isUnread: true,
                  buys: 3,
                  sells: 2,
                  onTap: () => _showReportDetail(context),
                ),
                _ReportCard(
                  title: 'Weekly Digest: Dec 9-15, 2024',
                  type: 'Weekly Digest',
                  investorName: 'All Watched Investors',
                  date: 'Dec 15, 8:00 AM',
                  preview:
                      'This week your watched investors made 47 trades across 23 companies...',
                  isUnread: true,
                  onTap: () => _showReportDetail(context),
                ),
                _ReportCard(
                  title: 'Berkshire Hathaway Q3 2024 13F Filing',
                  type: '13F Filing',
                  investorName: 'Berkshire Hathaway',
                  date: 'Nov 14, 4:30 PM',
                  preview:
                      'Berkshire disclosed new positions in Occidental Petroleum and reduced Apple stake...',
                  isUnread: false,
                  buys: 5,
                  sells: 8,
                  onTap: () => _showReportDetail(context),
                ),
                _ReportCard(
                  title: 'Weekly Digest: Dec 2-8, 2024',
                  type: 'Weekly Digest',
                  investorName: 'All Watched Investors',
                  date: 'Dec 8, 8:00 AM',
                  preview:
                      'This week your watched investors made 32 trades across 18 companies...',
                  isUnread: false,
                  onTap: () => _showReportDetail(context),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Mark all read button
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All reports marked as read'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.done_all),
                label: const Text('Mark all as read'),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _showReportDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ReportDetailSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String type;
  final String investorName;
  final String date;
  final String preview;
  final bool isUnread;
  final int? buys;
  final int? sells;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.type,
    required this.investorName,
    required this.date,
    required this.preview,
    required this.isUnread,
    this.buys,
    this.sells,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color:
            isUnread ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? AppColors.primary.withOpacity(0.3)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'Weekly Digest'
                            ? AppColors.info.withOpacity(0.1)
                            : type == '13F Filing'
                                ? AppColors.warning.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: type == 'Weekly Digest'
                              ? AppColors.info
                              : type == '13F Filing'
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  investorName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (buys != null || sells != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (buys != null && buys! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$buys buys',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (buys != null && buys! > 0) const SizedBox(width: 8),
                      if (sells != null && sells! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_down,
                                size: 14,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$sells sells',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  final ScrollController scrollController;

  const _ReportDetailSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Holdings Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'ARK Innovation ETF: Tesla Accumulation Continues',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'ARK Innovation ETF (ARKK) • Today, 2:45 PM',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              // Summary content
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ARK Innovation ETF continued its Tesla accumulation strategy today, '
                      'adding approximately 15,000 shares across the trading session. The fund '
                      'also initiated a new position in Coinbase Global (COIN) with 8,500 shares, '
                      'while trimming its Roku (ROKU) holdings by 12,000 shares.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Top buys
              Text(
                '🟢 Top Buys',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.success,
                    ),
              ),
              const SizedBox(height: 12),
              const _DetailTradeItem(
                ticker: 'TSLA',
                name: 'Tesla Inc.',
                action: 'Added',
                shares: '+15,000',
                priceRange: '\$180 - \$195',
                isPositive: true,
              ),
              const _DetailTradeItem(
                ticker: 'COIN',
                name: 'Coinbase Global',
                action: 'New Position',
                shares: '+8,500',
                priceRange: '\$220 - \$245',
                isPositive: true,
              ),
              const SizedBox(height: 20),

              // Top sells
              Text(
                '🔴 Top Sells',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                    ),
              ),
              const SizedBox(height: 12),
              const _DetailTradeItem(
                ticker: 'ROKU',
                name: 'Roku Inc.',
                action: 'Reduced',
                shares: '-12,000',
                priceRange: '\$62 - \$68',
                isPositive: false,
              ),
              const SizedBox(height: 24),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Not financial advice. This summary describes publicly disclosed '
                        'holdings changes and does not constitute an investment recommendation.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warningLight,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // View investor button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/investors/ark-innovation-arkk');
                  },
                  child: const Text('View Investor Details'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTradeItem extends StatelessWidget {
  final String ticker;
  final String name;
  final String action;
  final String shares;
  final String priceRange;
  final bool isPositive;

  const _DetailTradeItem({
    required this.ticker,
    required this.name,
    required this.action,
    required this.shares,
    required this.priceRange,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                ticker[0],
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticker,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? AppColors.successBackground
                            : AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              isPositive ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shares,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
              ),
              Text(
                'Market: $priceRange',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
