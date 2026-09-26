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
    this.frequencyDays = 1,
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

  /// How often the medication is taken, in days (1 = daily, 3 = every 3 days).
  final int frequencyDays;

  /// "1 tablet · After meal"
  String get dosageLine => '$dosage · $instruction';

  /// "9:00 AM · 1:00 PM · 9:00 PM"
  String get timesLine => times.join(' · ');

  /// The first scheduled time, with a safe fallback.
  String get firstTime => times.isEmpty ? '9:00 AM' : times.first;

  /// Returns a copy with the given fields replaced (everything else retained).
  Medication copyWith({
    String? name,
    String? dosage,
    String? instruction,
    String? category,
    String? notes,
    List<String>? times,
    int? pillColorIndex,
    MedicationStatus? status,
    DateTime? startedAt,
    int? frequencyDays,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instruction: instruction ?? this.instruction,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      times: times ?? this.times,
      pillColorIndex: pillColorIndex ?? this.pillColorIndex,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      frequencyDays: frequencyDays ?? this.frequencyDays,
    );
  }

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
      frequencyDays: (json['frequency_days'] as num?)?.toInt() ?? 1,
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
    'frequency_days': frequencyDays,
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
  if (value is DateTime) {
    // Normalize to local calendar date (avoid UTC midnight shifting the day).
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
  if (value is String) {
    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final m = dateOnly.firstMatch(value.trim());
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      final local = parsed.toLocal();
      return DateTime(local.year, local.month, local.day);
    }
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// "YYYY-MM-DD" for a Postgres `date` column.
String _dateToDb(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
