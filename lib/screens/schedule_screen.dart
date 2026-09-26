import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/taken_checkbox.dart';
import 'medication_detail_screen.dart';

/// A single item in the horizontal day strip (a day pill or a month label).
class _StripItem {
  const _StripItem({required this.widget, required this.width, this.day});

  final Widget widget;
  final double width;
  final DateTime? day;
}

/// Schedule tab — horizontally scrolling day strip with morning/afternoon/
/// evening sections for the selected day.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  static const double _dayItemWidth = 58; // 48 pill + 10 gap
  static const double _sepItemWidth = 88; // 78 label + 10 gap

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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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

    final medsForDay = active
        .where((m) => isScheduledOn(m, _selectedDate))
        .toList();

    final isToday = _sameDay(_selectedDate, today);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              AppSpacing.pageTop,
              AppSpacing.pageX,
              AppSpacing.md,
            ),
            child: ScreenHeader(title: l10n.schedule, large: true),
          ),
          SizedBox(
            height: 68,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
              itemCount: items.length,
              itemBuilder: (context, i) => items[i].widget,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
            child: Text(
              isToday ? l10n.today : fullDate(_selectedDate, locale),
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: medsForDay.isEmpty
                ? EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: l10n.noScheduleTitle,
                    subtitle: l10n.noScheduleBody,
                    iconColor: scheme.secondary,
                    iconBackground: scheme.secondaryContainer,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageX,
                      AppSpacing.sm,
                      AppSpacing.pageX,
                      AppSpacing.pageBottom,
                    ),
                    children: [
                      _section(
                        context,
                        l10n.morning,
                        medsForDay
                            .where(
                              (m) => resolveTimeMinutes(m.firstTime) < 12 * 60,
                            )
                            .toList(),
                        isToday: isToday,
                      ),
                      _section(
                        context,
                        l10n.afternoon,
                        medsForDay.where((m) {
                          final t = resolveTimeMinutes(m.firstTime);
                          return t >= 12 * 60 && t < 17 * 60;
                        }).toList(),
                        isToday: isToday,
                      ),
                      _section(
                        context,
                        l10n.evening,
                        medsForDay
                            .where(
                              (m) =>
                                  resolveTimeMinutes(m.firstTime) >= 17 * 60,
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
      final newMonth = lastMonth == null ||
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _sepItemWidth - 10,
      height: 56,
      margin: const EdgeInsets.only(right: 10),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
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
    final scheme = Theme.of(context).colorScheme;
    final textColor = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      selected: selected,
      button: true,
      label: fullDate(day, locale),
      child: InkWell(
        onTap: () => setState(() => _selectedDate = day),
        borderRadius: AppRadii.mdAll,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 48,
          height: 56,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : (isToday ? scheme.primary : scheme.outlineVariant),
              width: isToday && !selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortWeekday(day, locale),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    List<Medication> meds, {
    required bool isToday,
  }) {
    if (meds.isEmpty) return const SizedBox.shrink();
    final state = context.read<AppState>();
    final textTheme = Theme.of(context).textTheme;
    meds.sort(
      (a, b) => resolveTimeMinutes(a.firstTime)
          .compareTo(resolveTimeMinutes(b.firstTime)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Text(label, style: textTheme.labelMedium),
        ),
        for (final m in meds)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MedicationCard(
              medication: m,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicationDetailScreen(medicationId: m.id),
                ),
              ),
              trailing: isToday
                  ? TakenCheckbox(
                      taken: state.isTaken(m.id),
                      semanticLabel: m.name,
                      onToggle: () => state.toggleTaken(m.id),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  DateTime? _earliestStart(List<Medication> meds) {
    DateTime? earliest;
    for (final m in meds) {
      final d = DateTime(m.startedAt.year, m.startedAt.month, m.startedAt.day);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    return earliest;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
