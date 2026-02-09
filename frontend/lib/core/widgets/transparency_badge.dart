import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Transparency level enum
enum TransparencyLevel {
  high,
  medium,
  low,
}

/// Transparency badge showing HIGH/MED/LOW with tooltip explanation.
///
/// Used to indicate data transparency and reliability.
class TransparencyBadge extends StatelessWidget {
  final TransparencyLevel level;
  final bool showLabel;
  final bool compact;

  const TransparencyBadge({
    super.key,
    required this.level,
    this.showLabel = true,
    this.compact = false,
  });

  /// Create from transparency score (0-100)
  factory TransparencyBadge.fromScore(int score, {bool showLabel = true, bool compact = false}) {
    TransparencyLevel level;
    if (score >= 70) {
      level = TransparencyLevel.high;
    } else if (score >= 40) {
      level = TransparencyLevel.medium;
    } else {
      level = TransparencyLevel.low;
    }
    return TransparencyBadge(level: level, showLabel: showLabel, compact: compact);
  }

  Color get _backgroundColor {
    switch (level) {
      case TransparencyLevel.high:
        return AppColors.successBackground;
      case TransparencyLevel.medium:
        return AppColors.warningBackground;
      case TransparencyLevel.low:
        return AppColors.errorBackground;
    }
  }

  Color get _textColor {
    switch (level) {
      case TransparencyLevel.high:
        return AppColors.success;
      case TransparencyLevel.medium:
        return AppColors.warning;
      case TransparencyLevel.low:
        return AppColors.error;
    }
  }

  String get _label {
    switch (level) {
      case TransparencyLevel.high:
        return 'HIGH';
      case TransparencyLevel.medium:
        return 'MED';
      case TransparencyLevel.low:
        return 'LOW';
    }
  }

  String get _tooltipMessage {
    switch (level) {
      case TransparencyLevel.high:
        return 'High transparency: Frequent disclosures with detailed position data. '
            'Information is typically up-to-date within days.';
      case TransparencyLevel.medium:
        return 'Medium transparency: Regular disclosures but with some delay. '
            'Data may be weeks old by the time it\'s available.';
      case TransparencyLevel.low:
        return 'Low transparency: Infrequent disclosures with significant delay. '
            'Information may be months old and incomplete.';
    }
  }

  IconData get _icon {
    switch (level) {
      case TransparencyLevel.high:
        return Icons.visibility;
      case TransparencyLevel.medium:
        return Icons.visibility_outlined;
      case TransparencyLevel.low:
        return Icons.visibility_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            color: _textColor,
            size: compact ? 12 : 14,
          ),
          if (showLabel) ...[
            SizedBox(width: compact ? 3 : 4),
            Text(
              _label,
              style: TextStyle(
                color: _textColor,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: _tooltipMessage,
      preferBelow: true,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
      ),
      padding: const EdgeInsets.all(12),
      child: badge,
    );
  }
}

/// Inline transparency indicator (smaller, for list items)
class TransparencyIndicator extends StatelessWidget {
  final TransparencyLevel level;

  const TransparencyIndicator({
    super.key,
    required this.level,
  });

  factory TransparencyIndicator.fromScore(int score) {
    TransparencyLevel level;
    if (score >= 70) {
      level = TransparencyLevel.high;
    } else if (score >= 40) {
      level = TransparencyLevel.medium;
    } else {
      level = TransparencyLevel.low;
    }
    return TransparencyIndicator(level: level);
  }

  Color get _color {
    switch (level) {
      case TransparencyLevel.high:
        return AppColors.success;
      case TransparencyLevel.medium:
        return AppColors.warning;
      case TransparencyLevel.low:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }
}
