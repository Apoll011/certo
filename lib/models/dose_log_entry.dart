/// A recorded dose action (taken / skipped / mismatch / uncertain).
class DoseLogEntry {
  const DoseLogEntry({
    required this.medicationId,
    required this.medicationName,
    required this.action,
    required this.at,
    this.id,
  });

  final String? id;
  final String medicationId;
  final String medicationName;
  final String action;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'medication_id': medicationId,
        'medication_name': medicationName,
        'action': action,
        'at': at.toIso8601String(),
      };
}
