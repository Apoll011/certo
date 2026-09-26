const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _weekdaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// e.g. "Sunday, April 12"
String fullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// e.g. "Sun"
String shortWeekday(DateTime d) => _weekdaysShort[d.weekday - 1];

/// Parses "9:00 AM" / "2:30 PM" into a 24h hour (0–23).
int hourFromTime(String time) {
  final parts = time.split(':');
  var hour = int.tryParse(parts.first.trim()) ?? 0;
  final upper = time.toUpperCase();
  if (upper.contains('PM') && hour != 12) hour += 12;
  if (upper.contains('AM') && hour == 12) hour = 0;
  return hour;
}

/// e.g. "Added today", "Added yesterday", "Added 3 days ago"
String addedAgo(DateTime d, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(ref.year, ref.month, ref.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'Added today';
  if (days == 1) return 'Added yesterday';
  return 'Added $days days ago';
}
