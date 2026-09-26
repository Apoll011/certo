import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/pill_icon.dart';
import '../widgets/taken_checkbox.dart';
import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';
import 'settings_screen.dart';

/// Home tab — today's checklist with a time-sensitive, expandable reminder.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _expandedMedId;
  String? _expandedTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final now = DateTime.now();

    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();

    // Active medications due today (frequency-aware).
    final todays = active.where((m) => isScheduledOn(m, now)).toList();

    // Due-window doses, ignoring anything currently snoozed.
    final due = dueDoses(
      active.where((m) => state.snoozedUntilFor(m.id) == null).toList(),
      now,
    );
    final missed = due
        .where((d) => d.at.isBefore(now) && !state.isTaken(d.medication.id))
        .toList();
    final upcoming = due.where((d) => !d.at.isBefore(now)).toList();
    final primary = missed.isNotEmpty
        ? missed.first
        : (upcoming.isNotEmpty ? upcoming.first : null);

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
            if (primary != null)
              _isExpanded(primary)
                  ? _expandedReminder(primary, missed: missed.isNotEmpty)
                  : _dueBanner(primary, missed: missed.isNotEmpty),
            const SizedBox(height: 24),
            Text(l10n.today, style: AppTheme.sectionLabel),
            const SizedBox(height: 12),
            if (todays.isEmpty)
              EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.nothingDueToday,
                subtitle: l10n.nothingDueTodayBody,
                iconColor: AppColors.info,
                iconBackground: AppColors.infoSoft,
              )
            else
              for (final m in todays)
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

  bool _isExpanded(DueDose dose) =>
      _expandedMedId == dose.medication.id && _expandedTime == dose.time;

  void _toggleExpanded(DueDose dose) {
    setState(() {
      if (_isExpanded(dose)) {
        _expandedMedId = null;
        _expandedTime = null;
      } else {
        _expandedMedId = dose.medication.id;
        _expandedTime = dose.time;
      }
    });
  }

  Widget _dueBanner(DueDose dose, {required bool missed}) {
    final l10n = AppLocalizations.of(context)!;
    final med = dose.medication;
    final timeLabel = displayTime(dose.time, l10n);

    return AppCard(
      onTap: () => _toggleExpanded(dose),
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
                      ? '${med.name} · ${l10n.wasDueAt(timeLabel)}'
                      : '${med.name} · $timeLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 26,
          ),
        ],
      ),
    );
  }

  Widget _expandedReminder(DueDose dose, {required bool missed}) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final med = dose.medication;
    final clockLabel = isMealToken(dose.time)
        ? clock12(resolveTimeOnDay(dose.time, DateTime.now())!)
        : dose.time;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                missed ? Icons.warning_amber_rounded : Icons.alarm_rounded,
                color: missed ? AppColors.danger : AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missed ? l10n.missedDose : l10n.timeForMedication,
                  style: AppTheme.titleMedium,
                ),
              ),
              GestureDetector(
                onTap: () => _toggleExpanded(dose),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              clockLabel,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                PillIcon(colorIndex: med.pillColorIndex, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: AppTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(med.dosageLine, style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    state.markTaken(med.id);
                    _toggleExpanded(dose);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.takeNow),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await state.snooze(med.id);
                    if (!mounted) return;
                    _toggleExpanded(dose);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(l10n.snoozed),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
                  icon: const Icon(Icons.snooze_rounded, size: 20),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: Color(0xFFE2E2EA)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: Text(l10n.snooze),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
