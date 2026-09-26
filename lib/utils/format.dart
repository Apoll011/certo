import 'package:intl/intl.dart';

/// Localized full date, e.g. "Sunday, April 12" / "domingo, 12 de abril".
String fullDate(DateTime d, String locale) =>
    DateFormat.MMMMEEEEd(locale).format(d);

/// Localized short weekday, e.g. "Sun" / "dom.".
String shortWeekday(DateTime d, String locale) =>
    DateFormat.E(locale).format(d);

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
