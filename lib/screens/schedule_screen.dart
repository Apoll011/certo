import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/taken_checkbox.dart';
import 'medication_detail_screen.dart';

/// Schedule tab — a navigable month calendar up top, with the selected day's
/// doses below. Navigation is unbounded into the past (as far as data exists)
/// and limited to two months into the future.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = DateTime(now.year, now.month + 2, now.day);

    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();
    final minDate = _earliestStart(active) ?? today;

    final canGoPrev = _monthKey(_visibleMonth) > _monthKey(minDate);
    final canGoNext = _monthKey(_visibleMonth) < _monthKey(maxDate);

    // Medications that were already active on the selected day.
    final medsForDay = active
        .where((m) => _startedOnOrBefore(m.startedAt, _selectedDate))
        .toList();

    final isToday = _sameDay(_selectedDate, today);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(l10n.schedule, style: AppTheme.headerLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _calendar(
              context,
              locale: locale,
              today: today,
              maxDate: maxDate,
              canGoPrev: canGoPrev,
              canGoNext: canGoNext,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isToday ? l10n.today : fullDate(_selectedDate, locale),
              style: AppTheme.sectionLabel,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: medsForDay.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: l10n.noScheduleTitle,
                        subtitle: l10n.noScheduleBody,
                        iconColor: AppColors.info,
                        iconBackground: AppColors.infoSoft,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _section(
                        context,
                        l10n.morning,
                        medsForDay
                            .where(
                              (m) => minuteFromTime(m.times.first) < 12 * 60,
                            )
                            .toList(),
                        isToday: isToday,
                      ),
                      _section(
                        context,
                        l10n.afternoon,
                        medsForDay.where((m) {
                          final t = minuteFromTime(m.times.first);
                          return t >= 12 * 60 && t < 17 * 60;
                        }).toList(),
                        isToday: isToday,
                      ),
                      _section(
                        context,
                        l10n.evening,
                        medsForDay
                            .where(
                              (m) => minuteFromTime(m.times.first) >= 17 * 60,
                            )
                            .toList(),
                        isToday: isToday,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------------

  Widget _calendar(
    BuildContext context, {
    required String locale,
    required DateTime today,
    required DateTime maxDate,
    required bool canGoPrev,
    required bool canGoNext,
  }) {
    final y = _visibleMonth.year;
    final m = _visibleMonth.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final leading = DateTime(y, m, 1).weekday - 1; // Monday-start grid.

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _navButton(
                Icons.chevron_left_rounded,
                canGoPrev ? _goPrevMonth : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthYear(_visibleMonth, locale),
                    style: AppTheme.titleMedium,
                  ),
                ),
              ),
              _navButton(
                Icons.chevron_right_rounded,
                canGoNext ? _goNextMonth : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      shortWeekday(DateTime(2021, 1, 4 + i), locale),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _dayCell(DateTime(y, m, d), today, maxDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap == null
              ? AppColors.textSecondary.withValues(alpha: 0.4)
              : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, DateTime today, DateTime maxDate) {
    final selected = _sameDay(day, _selectedDate);
    final isToday = _sameDay(day, today);
    final enabled = !day.isAfter(maxDate);

    Color textColor;
    if (!enabled) {
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else if (selected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = AppColors.primary;
    } else {
      textColor = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _selectedDate = day) : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : Colors.transparent,
            border: isToday && !selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  // ---------------------------------------------------------------------------
  // Day list
  // ---------------------------------------------------------------------------

  Widget _section(
    BuildContext context,
    String label,
    List<Medication> meds, {
    required bool isToday,
  }) {
    if (meds.isEmpty) return const SizedBox.shrink();
    final state = context.read<AppState>();
    meds.sort(
      (a, b) =>
          minuteFromTime(a.times.first)
              .compareTo(minuteFromTime(b.times.first)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final m in meds)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MedicationCard(
              medication: m,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicationDetailScreen(medicationId: m.id),
                ),
              ),
              // Only today's doses are markable.
              trailing: isToday
                  ? TakenCheckbox(
                      taken: state.isTaken(m.id),
                      onToggle: () => state.toggleTaken(m.id),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime? _earliestStart(List<Medication> meds) {
    DateTime? earliest;
    for (final m in meds) {
      final d = DateTime(m.startedAt.year, m.startedAt.month, m.startedAt.day);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    return earliest;
  }

  bool _startedOnOrBefore(DateTime startedAt, DateTime day) {
    final a = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final b = DateTime(day.year, day.month, day.day);
    return !a.isAfter(b);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _monthKey(DateTime d) => d.year * 12 + d.month;
}
