import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Premium Editorial Finance Dashboard
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header with greeting
            _DashboardHeader(),
            const SizedBox(height: 28),

            // Portfolio Stats
            _StatsSection(),
            const SizedBox(height: 32),

            // Recent Activity
            const _SectionHeader(title: 'RECENT ACTIVITY', action: 'View All'),
            const SizedBox(height: 16),
            _ActivityList(),
            const SizedBox(height: 32),

            // Top Movers
            const _SectionHeader(title: 'TOP MOVERS'),
            const SizedBox(height: 16),
            _TopMoversSection(),
            const SizedBox(height: 32),

            // Quick Actions
            const _SectionHeader(title: 'QUICK ACTIONS'),
            const SizedBox(height: 16),
            _QuickActionsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.dmSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your watchlist and market movements',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Live indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.positive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.positive,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.positive.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.positive,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return const Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Watching',
                      value: '1',
                      icon: Icons.visibility_outlined,
                      trend: null)),
              SizedBox(width: 16),
              Expanded(
                  child: _StatCard(
                      label: 'Updates Today',
                      value: '3',
                      icon: Icons.update_rounded,
                      trend: '+2')),
              SizedBox(width: 16),
              Expanded(
                  child: _StatCard(
                      label: 'Portfolio Changes',
                      value: '12',
                      icon: Icons.swap_horiz_rounded,
                      trend: '+5')),
            ],
          );
        }

        return const Column(
          children: [
            _StatCard(
                label: 'Watching',
                value: '1',
                icon: Icons.visibility_outlined,
                trend: null),
            SizedBox(height: 12),
            _StatCard(
                label: 'Updates Today',
                value: '3',
                icon: Icons.update_rounded,
                trend: '+2'),
            SizedBox(height: 12),
            _StatCard(
                label: 'Portfolio Changes',
                value: '12',
                icon: Icons.swap_horiz_rounded,
                trend: '+5'),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? trend;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.mono(
                        size: 28,
                        weight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (trend != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trend!,
                          style: AppTextStyles.positive(size: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action!,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _ActivityRow(
            title: 'ARK Innovation ETF',
            subtitle: '5 trades executed',
            timestamp: '2h ago',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.positive,
            onTap: () => context.go('/investors/ark-arkk'),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
          _ActivityRow(
            title: 'ARK Genomic Revolution',
            subtitle: '2 trades executed',
            timestamp: '1d ago',
            icon: Icons.biotech_rounded,
            iconColor: AppColors.info,
            onTap: () => context.go('/investors/ark-arkg'),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
          _ActivityRow(
            title: 'Berkshire Hathaway',
            subtitle: '13F filed with SEC',
            timestamp: '3d ago',
            icon: Icons.description_outlined,
            iconColor: AppColors.warning,
            onTap: () => context.go('/investors/berkshire'),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timestamp;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textTertiary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMoversSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MoverChip(ticker: 'TSLA', change: '+2', isPositive: true),
        _MoverChip(ticker: 'NVDA', change: '+3', isPositive: true),
        _MoverChip(ticker: 'COIN', change: '-1', isPositive: false),
        _MoverChip(ticker: 'SQ', change: '+1', isPositive: true),
        _MoverChip(ticker: 'ROKU', change: '-2', isPositive: false),
      ],
    );
  }
}

class _MoverChip extends StatelessWidget {
  final String ticker;
  final String change;
  final bool isPositive;

  const _MoverChip({
    required this.ticker,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ticker,
            style: AppTextStyles.ticker,
          ),
          const SizedBox(width: 8),
          Icon(
            isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 2),
          Text(
            change,
            style: isPositive
                ? AppTextStyles.positive(size: 13)
                : AppTextStyles.negative(size: 13),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Add to Watchlist',
            icon: Icons.add_rounded,
            onTap: () => context.go('/watchlist'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Browse Investors',
            icon: Icons.search_rounded,
            onTap: () => context.go('/investors'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
