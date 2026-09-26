import '../models/caregiver.dart';
import '../models/dose_log_entry.dart';
import '../models/medication.dart';
import 'schedule.dart';

/// Local calendar day key (yyyy-MM-dd).
String adherenceDayKey(DateTime d) {
  final local = d.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Newest action per medication for a given local calendar day.
///
/// When [eventsNewestFirst] is true (DB / in-memory default), the first
/// matching event per medication wins. Otherwise the last one wins.
Map<String, String> latestDoseActionsForDay(
  List<DoseLogEntry> events,
  DateTime day, {
  bool eventsNewestFirst = true,
}) {
  final key = adherenceDayKey(day);
  final latestAction = <String, String>{};
  final latestAt = <String, DateTime>{};

  for (final e in events) {
    if (adherenceDayKey(e.at) != key) continue;
    final prevAt = latestAt[e.medicationId];
    if (prevAt == null) {
      latestAt[e.medicationId] = e.at;
      latestAction[e.medicationId] = e.action;
      continue;
    }
    if (e.at.isAfter(prevAt)) {
      latestAt[e.medicationId] = e.at;
      latestAction[e.medicationId] = e.action;
    } else if (e.at.isAtSameMomentAs(prevAt) && !eventsNewestFirst) {
      latestAction[e.medicationId] = e.action;
    }
    // Equal timestamp + newest-first: keep the first (already stored).
  }
  return latestAction;
}

/// Medication ids whose latest action that day is `taken`.
Set<String> takenMedIdsForDay(
  List<DoseLogEntry> events,
  DateTime day, {
  bool eventsNewestFirst = true,
}) {
  final latest = latestDoseActionsForDay(
    events,
    day,
    eventsNewestFirst: eventsNewestFirst,
  );
  return latest.entries
      .where((e) => e.value == 'taken')
      .map((e) => e.key)
      .toSet();
}

/// Active meds scheduled on [day] (start date + frequency + has times).
Set<String> scheduledMedIdsForDay(List<Medication> meds, DateTime day) {
  final ids = <String>{};
  for (final m in meds) {
    if (m.status != MedicationStatus.active) continue;
    if (m.times.isEmpty) continue;
    if (!isScheduledOn(m, day)) continue;
    ids.add(m.id);
  }
  return ids;
}

/// Calendar heatmap: one cell per day.
///
/// Uses **latest action per medication per day** (not cumulative counts), so a
/// later `taken` after `skipped`/`uncertain` shows green, not red/yellow.
///
/// - green: every scheduled med's latest action is `taken`
/// - yellow: partial progress, or latest `uncertain`
/// - red: latest `mismatch` / `skipped`, or a past day with nothing taken
/// - none: no schedule / future / today with no events yet
List<AdherenceDay> buildAdherenceHeatmap({
  required List<Medication> medications,
  required List<DoseLogEntry> events,
  int days = 28,
  DateTime? now,
}) {
  final today = (now ?? DateTime.now()).toLocal();
  final todayDate = DateTime(today.year, today.month, today.day);
  final active = medications
      .where((m) => m.status == MedicationStatus.active)
      .toList();

  // Newest-first: first write per med per day wins when timestamps equal.
  final byDayLatest = <String, Map<String, String>>{};
  final byDayLatestAt = <String, Map<String, DateTime>>{};
  for (final e in events) {
    final dayKey = adherenceDayKey(e.at);
    final atMap = byDayLatestAt[dayKey] ??= {};
    final actionMap = byDayLatest[dayKey] ??= {};
    final prev = atMap[e.medicationId];
    if (prev == null || e.at.isAfter(prev)) {
      atMap[e.medicationId] = e.at;
      actionMap[e.medicationId] = e.action;
    }
  }

  final out = <AdherenceDay>[];
  for (var i = days - 1; i >= 0; i--) {
    final day = todayDate.subtract(Duration(days: i));
    final key = adherenceDayKey(day);
    final scheduled = scheduledMedIdsForDay(active, day);
    final latest = byDayLatest[key] ?? const <String, String>{};
    final isFuture = day.isAfter(todayDate);
    final isToday = day == todayDate;

    var taken = 0;
    var skipped = 0;
    var mismatch = 0;
    var uncertain = 0;
    var pending = 0;

    for (final id in scheduled) {
      switch (latest[id]) {
        case 'taken':
          taken++;
        case 'skipped':
          skipped++;
        case 'mismatch':
          mismatch++;
        case 'uncertain':
          uncertain++;
        default:
          pending++;
      }
    }

    final missed = skipped + mismatch + (isToday ? 0 : pending);
    final AdherenceDayTone tone;
    if (isFuture || scheduled.isEmpty) {
      tone = AdherenceDayTone.none;
    } else if (mismatch > 0 || skipped > 0) {
      tone = AdherenceDayTone.alert;
    } else if (taken == scheduled.length) {
      tone = AdherenceDayTone.good;
    } else if (uncertain > 0) {
      tone = AdherenceDayTone.uncertain;
    } else if (taken > 0 && pending > 0) {
      tone = AdherenceDayTone.uncertain;
    } else if (isToday && taken == 0 && pending == scheduled.length) {
      tone = AdherenceDayTone.none;
    } else if (!isToday && pending == scheduled.length) {
      tone = AdherenceDayTone.alert;
    } else if (!isToday && taken > 0) {
      tone = AdherenceDayTone.uncertain;
    } else {
      tone = AdherenceDayTone.none;
    }

    out.add(
      AdherenceDay(
        date: day,
        tone: tone,
        takenCount: taken,
        scheduledCount: scheduled.length,
        uncertainCount: uncertain,
        mismatchCount: mismatch,
        missedCount: missed,
      ),
    );
  }
  return out;
}
