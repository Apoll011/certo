import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/taken_checkbox.dart';
import 'add_medication_screen.dart';
import 'alarm_screen.dart';
import 'medication_detail_screen.dart';
import 'settings_screen.dart';

/// A single dose that is due right now (upcoming or just missed).
class _DueDose {
  const _DueDose(this.medication, this.time, this.at);

  final Medication medication;
  final String time;
  final DateTime at;
}

/// Home tab — today's checklist with a time-sensitive "due now" banner.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();

    final missed = <_DueDose>[];
    final upcoming = <_DueDose>[];
    _computeDue(active, now, state, missed, upcoming);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.greeting(state.userName),
                      style: AppTheme.headerLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(fullDate(now, locale), style: AppTheme.bodyMedium),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.settings_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (state.medications.isEmpty)
            EmptyState(
              icon: Icons.medication_outlined,
              title: l10n.noMedicationsTitle,
              subtitle: l10n.noMedicationsBody,
              actionLabel: l10n.addMedication,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
              ),
            )
          else if (active.isEmpty)
            EmptyState(
              icon: Icons.pause_circle_outline_rounded,
              title: l10n.noActiveMedicationsTitle,
              subtitle: l10n.noActiveMedicationsBody,
              actionLabel: l10n.addMedication,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
              ),
            )
          else ...[
            if (missed.isNotEmpty)
              _dueBanner(context: context, dose: missed.first, missed: true)
            else if (upcoming.isNotEmpty)
              _dueBanner(context: context, dose: upcoming.first, missed: false),
            const SizedBox(height: 24),
            Text(l10n.today, style: AppTheme.sectionLabel),
            const SizedBox(height: 12),
            for (final m in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MedicationCard(
                  medication: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MedicationDetailScreen(medicationId: m.id),
                    ),
                  ),
                  trailing: TakenCheckbox(
                    taken: state.isTaken(m.id),
                    onToggle: () => state.toggleTaken(m.id),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _computeDue(
    List<Medication> active,
    DateTime now,
    AppState state,
    List<_DueDose> missed,
    List<_DueDose> upcoming,
  ) {
    for (final m in active) {
      for (final time in m.times) {
        final at = timeToDateTime(time, now);
        if (at == null) continue;
        final seconds = at.difference(now).inSeconds;
        // Overdue: scheduled within the last 10 minutes and not yet taken.
        if (seconds < 0 && seconds >= -10 * 60 && !state.isTaken(m.id)) {
          missed.add(_DueDose(m, time, at));
        } else if (seconds >= 0 && seconds <= 5 * 60) {
          upcoming.add(_DueDose(m, time, at));
        }
      }
    }
    missed.sort((a, b) => a.at.compareTo(b.at));
    upcoming.sort((a, b) => a.at.compareTo(b.at));
  }

  Widget _dueBanner({
    required BuildContext context,
    required _DueDose dose,
    required bool missed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final med = dose.medication;

    return AppCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AlarmScreen(medication: med))),
      color: missed ? AppColors.danger : AppColors.primary,
      child: Row(
        children: [
          Icon(
            missed
                ? Icons.warning_amber_rounded
                : Icons.notifications_active_rounded,
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missed ? l10n.missedDose : l10n.timeForMedication,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  missed
                      ? '${med.name} · ${l10n.wasDueAt(dose.time)}'
                      : '${med.name} · ${dose.time}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 26,
          ),
        ],
      ),
    );
  }
}
