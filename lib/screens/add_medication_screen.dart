import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';

import '../widgets/icon_badge.dart';
import '../widgets/pill_icon.dart';
import '../widgets/screen_header.dart';
import 'manual_medication_form_screen.dart';
import 'medication_detail_screen.dart';
import 'visual_verification_screen.dart';


/// Entry point for adding a medication (scan or manual).
class AddMedicationScreen extends StatelessWidget {
  const AddMedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final recent = state.recentMedications.take(4).toList();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                12,
                AppSpacing.pageX,
                AppSpacing.sm,
              ),
              child: ScreenHeader.back(
                title: l10n.addMedication,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.pagePaddingTight,
                children: [
                  _optionCard(
                    context,
                    icon: Icons.camera_alt_outlined,
                    title: l10n.scanPackage,
                    subtitle: l10n.scanPackageSubtitle,
                    onTap: () => showVisualVerificationScreen(context),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  _optionCard(
                    context,
                    icon: Icons.edit_outlined,
                    title: l10n.addManually,
                    subtitle: l10n.addManuallySubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManualMedicationFormScreen(),
                      ),
                    ),
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text(l10n.recent, style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.md),
                    for (final m in recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MedicationDetailScreen(
                                medicationId: m.id,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              PillIcon(
                                colorIndex: m.pillColorIndex,
                                size: 44,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: textTheme.titleMedium),
                                    const SizedBox(height: 3),
                                    Text(
                                      _addedAgo(l10n, m.startedAt),
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _addedAgo(AppLocalizations l10n, DateTime startedAt) {
    final days = daysSince(startedAt);
    if (days <= 0) return l10n.addedToday;
    if (days == 1) return l10n.addedYesterday;
    return l10n.addedDaysAgo(days);
  }

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: icon, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
            size: 26,
          ),
        ],
      ),
    );
  }
}
