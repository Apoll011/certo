import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_header.dart';

/// Caregiver tab — placeholder until the feature is built.
class CaregiverScreen extends StatelessWidget {
  const CaregiverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ScreenHeader(title: l10n.caregiver, large: true),
          const SizedBox(height: AppSpacing.xxl),
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: l10n.caregiverSupport,
            subtitle: l10n.caregiverBody,
            iconColor: scheme.secondary,
            iconBackground: scheme.secondaryContainer,
          ),
        ],
      ),
    );
  }
}
