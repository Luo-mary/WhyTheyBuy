import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// Calm, non-urgent upgrade prompt for subscription limits.
///
/// Design principles:
/// - No blocking alerts
/// - No red warnings or urgent colors
/// - No "act now" language
/// - Calm, informative, and respectful
class UpgradePrompt extends StatelessWidget {
  final String title;
  final String message;
  final String? ctaText;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;
  final bool showDismiss;

  const UpgradePrompt({
    super.key,
    this.title = 'Tracking Limit Reached',
    this.message =
        'You\'re currently tracking the maximum number of investors for your plan. '
        'Upgrade to track more investors and access additional features.',
    this.ctaText,
    this.onUpgrade,
    this.onDismiss,
    this.showDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Message
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Features preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                _FeatureRow(
                  icon: Icons.person_outline,
                  text: 'Track up to 10 investors',
                ),
                SizedBox(height: 8),
                _FeatureRow(
                  icon: Icons.insights_outlined,
                  text: 'Access AI Evidence Panel',
                ),
                SizedBox(height: 8),
                _FeatureRow(
                  icon: Icons.notifications_outlined,
                  text: 'Daily digest emails',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              if (showDismiss) ...[
                Expanded(
                  child: TextButton(
                    onPressed: onDismiss ?? () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: showDismiss ? 1 : 0,
                child: ElevatedButton(
                  onPressed: onUpgrade ?? () {
                    Navigator.of(context).pop();
                    context.push('/pricing');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    ctaText ?? 'View Plans',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    String? ctaText,
    VoidCallback? onUpgrade,
    bool showDismiss = true,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: UpgradePrompt(
          title: title ?? 'Tracking Limit Reached',
          message: message ??
              'You\'re currently tracking the maximum number of investors for your plan. '
                  'Upgrade to track more investors and access additional features.',
          ctaText: ctaText,
          onUpgrade: onUpgrade,
          showDismiss: showDismiss,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 16,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Compact inline upgrade nudge (for list items, cards)
class UpgradeNudge extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const UpgradeNudge({
    super.key,
    this.text = 'Upgrade for more',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/pricing'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.primary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
