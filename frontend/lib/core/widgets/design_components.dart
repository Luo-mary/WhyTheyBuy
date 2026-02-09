import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// WhyTheyBuy Premium Design Components
/// Editorial Finance aesthetic - sophisticated, data-focused

// ═══════════════════════════════════════════════════════════════════════════
// GLASS CARD - Premium card with gradient & subtle glow
// ═══════════════════════════════════════════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? glowColor;
  final bool showGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glowColor,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glowColor ?? AppColors.glowPrimary,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }
}

// Alias for compatibility
class SimpleCard extends GlassCard {
  const SimpleCard({
    super.key,
    required super.child,
    super.padding,
    super.onTap,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// STAT CARD - Premium metric display
// ═══════════════════════════════════════════════════════════════════════════

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (accentColor ?? AppColors.primary).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 18, color: accentColor ?? AppColors.primary),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHANGE INDICATOR - Shows positive/negative change with style
// ═══════════════════════════════════════════════════════════════════════════

class ChangeIndicator extends StatelessWidget {
  final double change;
  final bool showIcon;
  final bool compact;
  final bool showBackground;

  const ChangeIndicator({
    super.key,
    required this.change,
    this.showIcon = true,
    this.compact = false,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change > 0;
    final isNegative = change < 0;
    final color = isPositive
        ? AppColors.positive
        : isNegative
            ? AppColors.negative
            : AppColors.neutral;
    final bgColor = isPositive
        ? AppColors.successBackground
        : isNegative
            ? AppColors.errorBackground
            : AppColors.surfaceAlt;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(
            isPositive
                ? Icons.trending_up
                : isNegative
                    ? Icons.trending_down
                    : Icons.remove,
            size: compact ? 14 : 16,
            color: color,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
          style: GoogleFonts.jetBrainsMono(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );

    if (showBackground) {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: content,
      );
    }
    return content;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TICKER CHIP - Stock ticker display
// ═══════════════════════════════════════════════════════════════════════════

class TickerChip extends StatelessWidget {
  final String ticker;
  final double? change;
  final VoidCallback? onTap;

  const TickerChip({
    super.key,
    required this.ticker,
    this.change,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ticker,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            if (change != null) ...[
              const SizedBox(width: 10),
              ChangeIndicator(change: change!, compact: true, showIcon: false),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INVESTOR AVATAR - Gradient avatar
// ═══════════════════════════════════════════════════════════════════════════

class InvestorAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const InvestorAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor.withAlpha(40), baseColor.withAlpha(20)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withAlpha(50)),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.dmSans(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: baseColor,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVITY ROW - Premium list item
// ═══════════════════════════════════════════════════════════════════════════

class ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ActivityRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
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
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// Alias for compatibility
class ListTileCard extends ActivityRow {
  const ListTileCard({
    super.key,
    required super.title,
    String? subtitle,
    super.leading,
    super.trailing,
    super.onTap,
  }) : super(subtitle: subtitle ?? '');
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRADE BADGE - Buy/Sell indicator
// ═══════════════════════════════════════════════════════════════════════════

class TradeBadge extends StatelessWidget {
  final int count;
  final bool isBuy;

  const TradeBadge({super.key, required this.count, required this.isBuy});

  @override
  Widget build(BuildContext context) {
    final color = isBuy ? AppColors.positive : AppColors.negative;
    final bgColor =
        isBuy ? AppColors.successBackground : AppColors.errorBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBuy ? Icons.add : Icons.remove, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════

enum StatusType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;

  const StatusBadge(
      {super.key,
      required this.label,
      this.type = StatusType.neutral,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor) = _getColors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

  (Color, Color) _getColors() {
    switch (type) {
      case StatusType.success:
        return (AppColors.success, AppColors.successBackground);
      case StatusType.warning:
        return (AppColors.warning, AppColors.warningBackground);
      case StatusType.error:
        return (AppColors.error, AppColors.errorBackground);
      case StatusType.info:
        return (AppColors.info, AppColors.infoBackground);
      case StatusType.neutral:
        return (AppColors.textSecondary, AppColors.surfaceAlt);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM BADGE
// ═══════════════════════════════════════════════════════════════════════════

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          gradient: AppColors.premiumGradient,
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        'PRO',
        style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.background,
            letterSpacing: 0.5),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.description,
      this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: context.textTheme.titleLarge,
                textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description!,
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA ROW
// ═══════════════════════════════════════════════════════════════════════════

class DataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const DataRow(
      {super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: AppColors.textSecondary)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOADING
// ═══════════════════════════════════════════════════════════════════════════

class SimpleLoading extends StatelessWidget {
  final String? message;
  const SimpleLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: context.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
