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
}
