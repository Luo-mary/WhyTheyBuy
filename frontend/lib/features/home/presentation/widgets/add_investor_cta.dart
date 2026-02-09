import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Large circular "+" button as primary CTA on home page.
///
/// Opens InvestorSearchModal when tapped.
class AddInvestorCTA extends StatefulWidget {
  final VoidCallback onTap;

  const AddInvestorCTA({
    super.key,
    required this.onTap,
  });

  @override
  State<AddInvestorCTA> createState() => _AddInvestorCTAState();
}

class _AddInvestorCTAState extends State<AddInvestorCTA>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large "+" button
        MouseRegion(
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: _isHovered ? 0.4 : 0.2),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Label
        Text(
          AppLocalizations.of(context)?.addInvestorToTrack ?? 'Add an investor to track',
          style: TextStyle(
            color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
