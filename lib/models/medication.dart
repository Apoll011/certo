enum MedicationStatus { active, paused, finished }

/// A single medication with its schedule and dosing instructions.
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.category,
    required this.notes,
    required this.times,
    required this.pillColorIndex,
    required this.status,
    required this.startedAt,
  });

  final String id;
  final String name;

  /// e.g. "1 tablet"
  final String dosage;

  /// e.g. "After meal"
  final String instruction;

  /// e.g. "Antibiotic · Oral tablet"
  final String category;
  final String notes;

  /// Scheduled times, e.g. ["9:00 AM", "1:00 PM", "9:00 PM"]
  final List<String> times;

  /// Index into [AppColors.pillPalette] for the capsule avatar color.
  final int pillColorIndex;

  final MedicationStatus status;
  final DateTime startedAt;

  /// "1 tablet · After meal"
  String get dosageLine => '$dosage · $instruction';

  /// "9:00 AM · 1:00 PM · 9:00 PM"
  String get timesLine => times.join(' · ');

  /// Parses a row returned by the Supabase Data API (snake_case columns).
  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      category: json['category'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      times: _asStringList(json['times']),
      pillColorIndex: (json['pill_color_index'] as num?)?.toInt() ?? 0,
      status: _statusFromDb(json['status']),
      startedAt: _dateFromDb(json['started_at']),
    );
  }

  /// Payload for create/update (id and user_id are managed separately).
  Map<String, dynamic> toDbJson() => {
    'name': name,
    'dosage': dosage,
    'instruction': instruction,
    'category': category,
    'notes': notes,
    'times': times,
    'pill_color_index': pillColorIndex,
    'status': status.name,
    'started_at': _dateToDb(startedAt),
  };
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').toList();
  }
  return const [];
}

MedicationStatus _statusFromDb(dynamic value) {
  switch (value) {
    case 'paused':
      return MedicationStatus.paused;
    case 'finished':
      return MedicationStatus.finished;
    default:
      return MedicationStatus.active;
  }
}

/// Supabase returns `date` as a string like "2026-04-09"; be lenient.
DateTime _dateFromDb(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

/// "YYYY-MM-DD" for a Postgres `date` column.
String _dateToDb(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
