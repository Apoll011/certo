import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/data/caregiver_repository.dart';
import 'package:medication_reminder/models/caregiver.dart';
import 'package:medication_reminder/models/dose_log_entry.dart';
import 'package:medication_reminder/models/medication.dart';

void main() {
  final med = Medication(
    id: 'm1',
    name: 'Amoxicillin',
    dosage: '500 mg',
    instruction: 'After food',
    category: 'Antibiotic',
    notes: '',
    times: const ['8:00 AM'],
    pillColorIndex: 1,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 1, 1),
  );

  test('heatmap marks all-taken day as good', () {
    final day = DateTime(2026, 9, 20);
    final events = [
      DoseLogEntry(
        medicationId: 'm1',
        medicationName: 'Amoxicillin',
        action: 'taken',
        at: day.add(const Duration(hours: 8)),
      ),
    ];
    final heat = buildAdherenceHeatmap(
      medications: [med],
      events: events,
      days: 7,
      now: DateTime(2026, 9, 26, 12),
    );
    final cell = heat.firstWhere((d) => d.date.day == 20);
    expect(cell.tone, AdherenceDayTone.good);
  });

  test('heatmap marks mismatch day as alert', () {
    final day = DateTime(2026, 9, 21);
    final events = [
      DoseLogEntry(
        medicationId: 'm1',
        medicationName: 'Amoxicillin',
        action: 'mismatch',
        at: day.add(const Duration(hours: 9)),
      ),
    ];
    final heat = buildAdherenceHeatmap(
      medications: [med],
      events: events,
      days: 7,
      now: DateTime(2026, 9, 26, 12),
    );
    final cell = heat.firstWhere((d) => d.date.day == 21);
    expect(cell.tone, AdherenceDayTone.alert);
  });

  test('heatmap marks uncertain day as yellow', () {
    final day = DateTime(2026, 9, 22);
    final events = [
      DoseLogEntry(
        medicationId: 'm1',
        medicationName: 'Amoxicillin',
        action: 'uncertain',
        at: day.add(const Duration(hours: 9)),
      ),
      DoseLogEntry(
        medicationId: 'm1',
        medicationName: 'Amoxicillin',
        action: 'taken',
        at: day.add(const Duration(hours: 10)),
      ),
    ];
    final heat = buildAdherenceHeatmap(
      medications: [med],
      events: events,
      days: 7,
      now: DateTime(2026, 9, 26, 12),
    );
    final cell = heat.firstWhere((d) => d.date.day == 22);
    expect(cell.tone, AdherenceDayTone.uncertain);
  });
}
