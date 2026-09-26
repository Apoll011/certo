import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../utils/status.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/icon_badge.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';
import 'manual_medication_form_screen.dart';

/// Full info for a single medication.
class MedicationDetailScreen extends StatelessWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});

  final String medicationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final med = state.medicationById(medicationId);

    if (med == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(l10n.medicationNotFound)),
      );
    }

    final taken = state.isTaken(med.id);

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
                      child: Text(
                        l10n.medicationDetail,
                        style: AppTheme.headerMedium,
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ManualMedicationFormScreen(medication: med),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Column(
                    children: [
                      PillIcon(colorIndex: med.pillColorIndex, size: 88),
                      const SizedBox(height: 18),
                      Text(
                        med.name,
                        textAlign: TextAlign.center,
                        style: AppTheme.headerMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(med.category, style: AppTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final status in MedicationStatus.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: status == MedicationStatus.values.last
                                  ? 0
                                  : 8,
                            ),
                            child: _statusTile(context, med, status),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          icon: Icons.medication_outlined,
                          label: l10n.dosage,
                          value:
                              '${l10n.takeDosage(med.dosage)}\n${med.instruction}',
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.schedule_rounded,
                          label: l10n.scheduleLabel,
                          value:
                              '${displayTimes(med.times, l10n)}\n'
                              '${med.frequencyDays == 1 ? l10n.everyDay : l10n.everyNDays(med.frequencyDays)}',
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.calendar_today_outlined,
                          label: l10n.started,
                          value: fullDate(med.startedAt, locale),
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.sticky_note_2_outlined,
                          label: l10n.notes,
                          value: med.notes,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryButton(
                label: taken ? l10n.taken : l10n.markAsTaken,
                icon: taken ? Icons.check_rounded : null,
                color: taken ? AppColors.success : AppColors.primary,
                onPressed: taken
                    ? null
                    : () {
                        state.markTaken(med.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.markedAsTaken),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(
    BuildContext context,
    Medication med,
    MedicationStatus status,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final selected = med.status == status;
    final color = statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        if (selected) return;
        final messenger = ScaffoldMessenger.of(context);
        await state.setMedicationStatus(med.id, status);
        if (!context.mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.statusUpdated),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : const Color(0xFFE2E2EA)),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Column(
          children: [
            Icon(
              statusIcon(status),
              color: selected ? Colors.white : color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              statusLabel(l10n, status),
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.bodySmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.35,
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFF0F0F4));
  }
}
