import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full expandable disclaimer component containing all required disclaimers.
///
/// Contains the 5 required disclaimers:
/// 1. App is NOT investment advice
/// 2. AI reasoning is hypothetical
/// 3. Data may be delayed or incomplete
/// 4. No inference of investor intent
/// 5. Not for trading decisions
class DisclaimerBlock extends StatefulWidget {
  final bool initiallyExpanded;
  final bool showIcon;

  const DisclaimerBlock({
    super.key,
    this.initiallyExpanded = false,
    this.showIcon = true,
  });

  @override
  State<DisclaimerBlock> createState() => _DisclaimerBlockState();
}

class _DisclaimerBlockState extends State<DisclaimerBlock>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _heightFactor;

  static const List<DisclaimerItem> _disclaimers = [
    DisclaimerItem(
      title: 'Not Investment Advice',
      description:
          'WhyTheyBuy provides financial information and analytical tools only. '
          'Nothing in this app constitutes investment advice, recommendation, or solicitation '
          'to buy or sell any securities.',
      icon: Icons.gavel_outlined,
    ),
    DisclaimerItem(
      title: 'AI Reasoning is Hypothetical',
      description:
          'All AI-generated insights and interpretations are hypothetical analyses based on '
          'publicly disclosed data. They represent possible explanations, not confirmed facts '
          'about investor intent or strategy.',
      icon: Icons.psychology_outlined,
    ),
    DisclaimerItem(
      title: 'Data May Be Delayed',
      description:
          'Disclosed holdings data may be days, weeks, or months old depending on the disclosure type. '
          'Current positions may differ significantly from what is shown.',
      icon: Icons.schedule_outlined,
    ),
    DisclaimerItem(
      title: 'No Inference of Intent',
      description:
          'We do not claim to know why any investor made any particular trade or holds any position. '
          'All interpretations are speculative and for educational purposes only.',
      icon: Icons.help_outline,
    ),
    DisclaimerItem(
      title: 'Not for Trading Decisions',
      description:
          'Do not use this information to make investment or trading decisions. '
          'Always conduct your own research and consult with qualified financial advisors.',
      icon: Icons.warning_amber_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor =
        _animationController.drive(CurveTween(curve: Curves.easeInOut));
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
              bottom: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.showIcon) ...[
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important Disclaimers',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Please read before using this information',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          ClipRect(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Align(
                  heightFactor: _heightFactor.value,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: AppColors.warning.withValues(alpha: 0.2),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: _disclaimers
                          .map((d) => _DisclaimerItemWidget(item: d))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DisclaimerItem {
  final String title;
  final String description;
  final IconData icon;

  const DisclaimerItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _DisclaimerItemWidget extends StatelessWidget {
  final DisclaimerItem item;

  const _DisclaimerItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              item.icon,
              color: AppColors.warning,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
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

/// Short inline disclaimer banner for headers
class DisclaimerBanner extends StatelessWidget {
  final String? text;
  final bool showIcon;

  const DisclaimerBanner({
    super.key,
    this.text,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            const Icon(
              Icons.info_outline,
              color: AppColors.warning,
              size: 14,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text ?? 'For educational purposes only. Not investment advice.',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
