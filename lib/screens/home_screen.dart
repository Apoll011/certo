import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/pill_icon.dart';
import '../widgets/screen_header.dart';
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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();

    final todays = active.where((m) => isScheduledOn(m, now)).toList();

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
        padding: AppSpacing.pagePadding,
        children: [
          ScreenHeader(
            title: l10n.greeting(state.userName),
            subtitle: fullDate(now, locale),
            large: true,
            trailing: CircleIconButton(
              icon: Icons.settings_outlined,
              tooltip: l10n.settings,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
              AnimatedSize(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _isExpanded(primary)
                    ? _expandedReminder(primary, missed: missed.isNotEmpty)
                    : _dueBanner(primary, missed: missed.isNotEmpty),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Text(l10n.today, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            if (todays.isEmpty)
              EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.nothingDueToday,
                subtitle: l10n.nothingDueTodayBody,
                iconColor: scheme.secondary,
                iconBackground: scheme.secondaryContainer,
              )
            else
              for (final m in todays)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                      semanticLabel: m.name,
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
    final bg = missed ? AppColors.danger : AppColors.primary;

    return AppCard(
      onTap: () => _toggleExpanded(dose),
      color: bg,
      bordered: false,
      semanticLabel: missed ? l10n.missedDose : l10n.timeForMedication,
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
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 26,
          ),
        ],
      ),
    );
  }

  Widget _expandedReminder(DueDose dose, {required bool missed}) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final med = dose.medication;
    final clockLabel = isMealToken(dose.time)
        ? clock12(resolveTimeOnDay(dose.time, DateTime.now())!)
        : dose.time;
    final accent = missed ? scheme.error : scheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                missed ? Icons.warning_amber_rounded : Icons.alarm_rounded,
                color: accent,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missed ? l10n.missedDose : l10n.timeForMedication,
                  style: textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => _toggleExpanded(dose),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              clockLabel,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadii.mdAll,
            ),
            child: Row(
              children: [
                PillIcon(colorIndex: med.pillColorIndex, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(med.dosageLine, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    state.markTaken(med.id);
                    _toggleExpanded(dose);
                  },
                  child: Text(l10n.takeNow),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await state.snooze(med.id);
                    if (!mounted) return;
                    _toggleExpanded(dose);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(l10n.snoozed)));
                  },
                  icon: const Icon(Icons.snooze_rounded, size: 20),
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
