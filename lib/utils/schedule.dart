import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import 'format.dart';

/// Default meal anchor times (minutes since midnight).
const int breakfastMinutes = 8 * 60; // 08:00
const int lunchMinutes = 14 * 60; // 14:00
const int dinnerMinutes = 20 * 60; // 20:00

/// Meal tokens allowed inside [Medication.times].
const Set<String> mealTokens = {'breakfast', 'lunch', 'dinner'};

/// Whether [time] is a meal anchor rather than a clock time.
bool isMealToken(String time) => mealTokens.contains(time.trim().toLowerCase());

/// Localized display label for a schedule entry ("lunch" -> "After lunch").
String displayTime(String time, AppLocalizations l10n) {
  switch (time.trim().toLowerCase()) {
    case 'breakfast':
      return l10n.mealBreakfast;
    case 'lunch':
      return l10n.mealLunch;
    case 'dinner':
      return l10n.mealDinner;
    default:
      return time;
  }
}

/// Localized "9:00 AM · After lunch" style line for a medication's times.
String displayTimes(List<String> times, AppLocalizations l10n) =>
    times.map((t) => displayTime(t, l10n)).join(' · ');

/// Resolves a schedule entry ("9:00 AM", "14:00" or "lunch") to minutes since
/// midnight. Meal anchors fall back to their default time.
int resolveTimeMinutes(String time) {
  switch (time.trim().toLowerCase()) {
    case 'breakfast':
      return breakfastMinutes;
    case 'lunch':
      return lunchMinutes;
    case 'dinner':
      return dinnerMinutes;
    default:
      return minuteFromTime(time);
  }
}

/// Resolves a schedule entry to a [DateTime] on [day], or null if unparseable.
DateTime? resolveTimeOnDay(String time, DateTime day) {
  final minutes = resolveTimeMinutes(time);
  return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [m] has a scheduled dose on [day], honoring its start date and
/// every-N-days frequency (frequency 1 = every day, 2 = every other day, …).
bool isScheduledOn(Medication m, DateTime day) {
  final start = dateOnly(m.startedAt);
  final d = dateOnly(day);
  if (d.isBefore(start)) return false;
  final freq = m.frequencyDays <= 0 ? 1 : m.frequencyDays;
  final days = d.difference(start).inDays;
  return days % freq == 0;
}

/// The next dose occurrences of [m] strictly after [from], up to [days] ahead.
List<DateTime> upcomingOccurrences(
  Medication m,
  DateTime from, {
  int days = 14,
}) {
  final result = <DateTime>[];
  var day = dateOnly(from);
  final end = dateOnly(from.add(Duration(days: days)));
  while (!day.isAfter(end)) {
    if (isScheduledOn(m, day)) {
      for (final time in m.times) {
        final at = resolveTimeOnDay(time, day);
        if (at != null && at.isAfter(from)) result.add(at);
      }
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  result.sort();
  return result;
}

/// A single dose that falls inside a "due now" window.
class DueDose {
  const DueDose({
    required this.medication,
    required this.time,
    required this.at,
  });

  final Medication medication;
  final String time;
  final DateTime at;
}

/// Doses whose scheduled time falls inside `[now - lookback, now + lookahead]`.
///
/// Checks the surrounding day range so late-night / early-morning boundaries
/// are handled correctly.
List<DueDose> dueDoses(
  List<Medication> meds,
  DateTime now, {
  Duration lookback = const Duration(minutes: 10),
  Duration lookahead = const Duration(minutes: 5),
}) {
  final result = <DueDose>[];
  final from = now.subtract(lookback);
  final to = now.add(lookahead);

  for (final m in meds) {
    for (final dayOffset in const [-1, 0, 1]) {
      final day = dateOnly(now).add(Duration(days: dayOffset));
      if (!isScheduledOn(m, day)) continue;
      for (final time in m.times) {
        final at = resolveTimeOnDay(time, day);
        if (at == null) continue;
        if (!at.isBefore(from) && !at.isAfter(to)) {
          result.add(DueDose(medication: m, time: time, at: at));
        }
      }
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}
