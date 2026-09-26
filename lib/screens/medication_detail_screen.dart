import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/icon_badge.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';

/// Full info for a single medication.
class MedicationDetailScreen extends StatelessWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});

  final String medicationId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final med = state.medicationById(medicationId);

    if (med == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Medication not found')),
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Medication detail',
                        style: AppTheme.headerMedium,
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => showComingSoon(context, 'Edit medication'),
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
                          label: 'Dosage',
                          value: 'Take ${med.dosage}\n${med.instruction}',
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.schedule_rounded,
                          label: 'Schedule',
                          value: med.timesLine,
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Started',
                          value: fullDate(med.startedAt),
                        ),
                        const _Divider(),
                        _detailRow(
                          icon: Icons.sticky_note_2_outlined,
                          label: 'Notes',
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
                label: taken ? 'Taken' : 'Mark as taken',
                icon: taken ? Icons.check_rounded : null,
                color: taken ? AppColors.success : AppColors.primary,
                onPressed: taken
                    ? null
                    : () {
                        state.markTaken(med.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Marked as taken ✓'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
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
