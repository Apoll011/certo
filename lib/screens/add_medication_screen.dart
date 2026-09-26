import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/icon_badge.dart';
import '../widgets/pill_icon.dart';
import 'medication_detail_screen.dart';

/// Entry point for adding a medication (scan or manual).
class AddMedicationScreen extends StatelessWidget {
  const AddMedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final recent = state.recentMedications.take(4).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Text(l10n.addMedication, style: AppTheme.headerMedium),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _optionCard(
                    icon: Icons.camera_alt_outlined,
                    title: l10n.scanPackage,
                    subtitle: l10n.scanPackageSubtitle,
                    onTap: () => showComingSoon(context, l10n.cameraComingSoon),
                  ),
                  const SizedBox(height: 12),
                  _optionCard(
                    icon: Icons.edit_outlined,
                    title: l10n.addManually,
                    subtitle: l10n.addManuallySubtitle,
                    onTap: () => showComingSoon(context, l10n.manualComingSoon),
                  ),
                  const SizedBox(height: 28),
                  Text(l10n.recent, style: AppTheme.sectionLabel),
                  const SizedBox(height: 12),
                  for (final m in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MedicationDetailScreen(medicationId: m.id),
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
                                  Text(m.name, style: AppTheme.titleMedium),
                                  const SizedBox(height: 3),
                                  Text(
                                    _addedAgo(l10n, m.startedAt),
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                Text(title, style: AppTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 26,
          ),
        ],
      ),
    );
  }
}
