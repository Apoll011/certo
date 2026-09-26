import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/taken_checkbox.dart';
import 'medication_detail_screen.dart';

/// A single item in the horizontal day strip (a day pill or a month label).
class _StripItem {
  const _StripItem({required this.widget, required this.width, this.day});

  final Widget widget;
  final double width;
  final DateTime? day;
}

/// Schedule tab — a single-line, horizontally scrolling day strip with month
/// separators. Navigation is unbounded into the past (as far as data exists)
/// and limited to two months into the future.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  // Fixed item widths keep the initial scroll-to-today offset deterministic.
  static const double _dayItemWidth = 62; // 52 pill + 10 gap
  static const double _sepItemWidth = 92; // 82 label + 10 gap

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    var minDate = _earliestStart(active) ?? today;
    if (minDate.isAfter(today)) minDate = today;

    final days = _daysBetween(minDate, maxDate);
    final items = _buildStrip(days, locale: locale, today: today);

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final offset = _offsetForToday(items, today);
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset.clamp(0.0, max));
      });
    }

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Text(l10n.schedule, style: AppTheme.headerLarge),
          ),
          SizedBox(
            height: 72,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, i) => items[i].widget,
            ),
          ),
          const SizedBox(height: 12),
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
                ? EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: l10n.noScheduleTitle,
                    subtitle: l10n.noScheduleBody,
                    iconColor: AppColors.info,
                    iconBackground: AppColors.infoSoft,
                    card: false,
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
  // Day strip
  // ---------------------------------------------------------------------------

  List<DateTime> _daysBetween(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var d = start;
    while (!d.isAfter(end)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  List<_StripItem> _buildStrip(
    List<DateTime> days, {
    required String locale,
    required DateTime today,
  }) {
    final items = <_StripItem>[];
    DateTime? lastMonth;
    for (final day in days) {
      final newMonth =
          lastMonth == null ||
          day.year != lastMonth.year ||
          day.month != lastMonth.month;
      if (newMonth) {
        items.add(
          _StripItem(
            widget: _monthSeparator(shortMonthYear(day, locale)),
            width: _sepItemWidth,
          ),
        );
        lastMonth = DateTime(day.year, day.month);
      }
      items.add(
        _StripItem(
          widget: _dayPill(
            day,
            locale: locale,
            selected: _sameDay(day, _selectedDate),
            isToday: _sameDay(day, today),
          ),
          width: _dayItemWidth,
          day: day,
        ),
      );
    }
    return items;
  }

  double _offsetForToday(List<_StripItem> items, DateTime today) {
    double offset = 0;
    for (final item in items) {
      if (item.day != null && _sameDay(item.day!, today)) return offset;
      offset += item.width;
    }
    return 0;
  }

  Widget _monthSeparator(String label) {
    return Container(
      width: _sepItemWidth - 10,
      height: 60,
      margin: const EdgeInsets.only(right: 10),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _dayPill(
    DateTime day, {
    required String locale,
    required bool selected,
    required bool isToday,
  }) {
    final textColor = selected ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = day),
      child: Container(
        width: 52,
        height: 60,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isToday && !selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : (selected ? null : Border.all(color: const Color(0xFFE2E2EA))),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortWeekday(day, locale),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
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
}
