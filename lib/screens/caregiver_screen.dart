import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/icon_badge.dart';

/// Caregiver tab — placeholder until the feature is built.
class CaregiverScreen extends StatelessWidget {
  const CaregiverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l10n.caregiver, style: AppTheme.headerLarge),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                const SizedBox(height: 8),
                IconBadge(
                  icon: Icons.people_outline_rounded,
                  size: 64,
                  color: AppColors.infoSoft,
                  iconColor: AppColors.info,
                ),
                const SizedBox(height: 18),
                Text(l10n.caregiverSupport, style: AppTheme.headerMedium),
                const SizedBox(height: 8),
                Text(
                  l10n.caregiverBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
