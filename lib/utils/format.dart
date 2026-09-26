import 'package:intl/intl.dart';

/// Localized full date, e.g. "Sunday, April 12" / "domingo, 12 de abril".
String fullDate(DateTime d, String locale) =>
    DateFormat.MMMMEEEEd(locale).format(d);

/// Localized short weekday, e.g. "Sun" / "dom.".
String shortWeekday(DateTime d, String locale) =>
    DateFormat.E(locale).format(d);

/// Localized month name + year, e.g. "April 2026" / "abril de 2026".
String monthYear(DateTime d, String locale) =>
    '${DateFormat.MMMM(locale).format(d)} ${d.year}';

/// Localized short month + year, e.g. "Apr 2026" / "abr. 2026".
String shortMonthYear(DateTime d, String locale) =>
    '${DateFormat.MMM(locale).format(d)} ${d.year}';

/// Whole days elapsed since [d] (relative to today).
int daysSince(DateTime d, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(ref.year, ref.month, ref.day);
  return b.difference(a).inDays;
}

/// Parses "9:00 AM" / "2:30 PM" into a 24h hour (0–23).
int hourFromTime(String time) {
  final parts = time.split(':');
  var hour = int.tryParse(parts.first.trim()) ?? 0;
  final upper = time.toUpperCase();
  if (upper.contains('PM') && hour != 12) hour += 12;
  if (upper.contains('AM') && hour == 12) hour = 0;
  return hour;
}

/// Parses "9:00 AM" / "2:30 PM" / "14:30" into a [DateTime] on [day].
///
/// Returns null when the string is not a recognizable time.
DateTime? timeToDateTime(String time, DateTime day) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$')
      .firstMatch(time.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final ampm = (match.group(3) ?? '').toUpperCase();
  if (ampm == 'PM' && hour != 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Minutes since midnight for a time string ("9:00 AM" -> 540).
int minuteFromTime(String time) {
  final parsed = timeToDateTime(time, DateTime(2000, 1, 1));
  if (parsed == null) return 0;
  return parsed.hour * 60 + parsed.minute;
}

/// Formats a [DateTime] as a 12-hour clock string, e.g. "9:00 AM".
String clock12(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $ampm';
}
