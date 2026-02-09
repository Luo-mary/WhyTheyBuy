import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Short footer disclaimer for home page.
///
/// Displays: "For educational purposes only. Not investment advice."
class HomeDisclaimer extends StatelessWidget {
  const HomeDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.textTertiary,
            size: 14,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(context)?.disclaimer ?? 'For educational purposes only. Not investment advice.',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
