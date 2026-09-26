import 'dart:math' as math;

import '../models/dose_log_entry.dart';
import '../models/medication.dart';

/// Demo user shown across the app until real profiles exist.
const String demoUserName = 'Tiago';

/// A lightweight offline persona for “Open as demo user”.
class DemoPersona {
  const DemoPersona({
    required this.id,
    required this.name,
    required this.emailHint,
    required this.tagline,
    required this.medications,
    this.isCaregiver = false,
  });

  final String id;
  final String name;
  final String emailHint;
  final String tagline;
  final List<Medication> medications;
  final bool isCaregiver;
}

Medication _med({
  required String id,
  required String name,
  required String dosage,
  required String instruction,
  required String category,
  required String notes,
  required List<String> times,
  required int pillColorIndex,
  required MedicationStatus status,
  required DateTime startedAt,
  int frequencyDays = 1,
}) {
  return Medication(
    id: id,
    name: name,
    dosage: dosage,
    instruction: instruction,
    category: category,
    notes: notes,
    times: times,
    pillColorIndex: pillColorIndex,
    status: status,
    startedAt: startedAt,
    frequencyDays: frequencyDays,
  );
}

/// Curated demo people with varied schedules and a bit of history.
final List<DemoPersona> demoPersonas = [
  DemoPersona(
    id: 'maya',
    name: 'Maya Chen',
    emailHint: 'maya.demo@verifi.app',
    tagline: 'Busy professional · 4 active meds',
    medications: [
      _med(
        id: 'maya-metformin',
        name: 'Metformin 850mg',
        dosage: '1 tablet',
        instruction: 'With breakfast',
        category: 'Diabetes · Oral tablet',
        notes: 'Check blood sugar before taking.',
        times: const ['8:00 AM', '8:00 PM'],
        pillColorIndex: 1,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 2, 12),
      ),
      _med(
        id: 'maya-atorvastatin',
        name: 'Atorvastatin 20mg',
        dosage: '1 tablet',
        instruction: 'At night',
        category: 'Cholesterol · Oral tablet',
        notes: 'Take around the same time daily.',
        times: const ['9:00 PM'],
        pillColorIndex: 0,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 1, 8),
      ),
      _med(
        id: 'maya-vitamin-d',
        name: 'Vitamin D3',
        dosage: '1 capsule',
        instruction: 'After breakfast',
        category: 'Supplement · Capsule',
        notes: 'Every 3 days with food.',
        times: const ['breakfast'],
        pillColorIndex: 2,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 3, 1),
        frequencyDays: 3,
      ),
      _med(
        id: 'maya-ibuprofen',
        name: 'Ibuprofen 400mg',
        dosage: '1 tablet',
        instruction: 'With food',
        category: 'Pain relief · Oral tablet',
        notes: 'As needed for tension headaches.',
        times: const ['lunch'],
        pillColorIndex: 1,
        status: MedicationStatus.paused,
        startedAt: DateTime(2026, 4, 2),
      ),
    ],
  ),
  DemoPersona(
    id: 'jonas',
    name: 'Jonas Berg',
    emailHint: 'jonas.demo@verifi.app',
    tagline: 'Recovering from infection · short course',
    medications: [
      _med(
        id: 'jonas-amox',
        name: 'Amoxicillin 500mg',
        dosage: '1 tablet',
        instruction: 'After meal',
        category: 'Antibiotic · Oral tablet',
        notes: 'Finish the full course.',
        times: const ['9:00 AM', '1:00 PM', '9:00 PM'],
        pillColorIndex: 0,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 4, 9),
      ),
      _med(
        id: 'jonas-probiotic',
        name: 'Probiotic',
        dosage: '1 capsule',
        instruction: '2 hours after antibiotic',
        category: 'Supplement · Capsule',
        notes: 'Space away from Amoxicillin.',
        times: const ['11:00 AM'],
        pillColorIndex: 2,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 4, 9),
      ),
      _med(
        id: 'jonas-paracetamol',
        name: 'Paracetamol 500mg',
        dosage: '1–2 tablets',
        instruction: 'If fever',
        category: 'Pain / fever · Oral tablet',
        notes: 'Max 6 tablets / day.',
        times: const ['8:00 AM', '8:00 PM'],
        pillColorIndex: 3,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 4, 8),
      ),
    ],
  ),
  DemoPersona(
    id: 'sofia',
    name: 'Sofia Martins',
    emailHint: 'sofia.demo@verifi.app',
    tagline: 'Blood pressure + sleep routine',
    medications: [
      _med(
        id: 'sofia-losartan',
        name: 'Losartan 50mg',
        dosage: '1 tablet',
        instruction: 'With water',
        category: 'Blood pressure · Oral tablet',
        notes: 'Same time every morning.',
        times: const ['8:00 AM'],
        pillColorIndex: 0,
        status: MedicationStatus.active,
        startedAt: DateTime(2025, 11, 3),
      ),
      _med(
        id: 'sofia-amlodipine',
        name: 'Amlodipine 5mg',
        dosage: '1 tablet',
        instruction: 'Morning',
        category: 'Blood pressure · Oral tablet',
        notes: 'May cause mild ankle swelling.',
        times: const ['8:00 AM'],
        pillColorIndex: 1,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 1, 20),
      ),
      _med(
        id: 'sofia-melatonin',
        name: 'Melatonin 3mg',
        dosage: '1 tablet',
        instruction: 'Before bed',
        category: 'Sleep aid · Oral tablet',
        notes: '30 minutes before sleep.',
        times: const ['10:00 PM'],
        pillColorIndex: 3,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 3, 15),
      ),
      _med(
        id: 'sofia-omeprazole',
        name: 'Omeprazole 20mg',
        dosage: '1 capsule',
        instruction: 'Before breakfast',
        category: 'Stomach · Capsule',
        notes: 'Course finished last month.',
        times: const ['7:30 AM'],
        pillColorIndex: 2,
        status: MedicationStatus.finished,
        startedAt: DateTime(2026, 2, 1),
      ),
    ],
  ),
  DemoPersona(
    id: 'alex',
    name: 'Alex Rivera',
    emailHint: 'alex.demo@verifi.app',
    tagline: 'Family caregiver demo profile',
    isCaregiver: true,
    medications: [
      _med(
        id: 'alex-vitamin-c',
        name: 'Vitamin C 500mg',
        dosage: '1 tablet',
        instruction: 'With breakfast',
        category: 'Supplement · Oral tablet',
        notes: 'Personal supplement.',
        times: const ['breakfast'],
        pillColorIndex: 2,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 1, 5),
      ),
      _med(
        id: 'alex-allergy',
        name: 'Cetirizine 10mg',
        dosage: '1 tablet',
        instruction: 'Evening',
        category: 'Allergy · Oral tablet',
        notes: 'Seasonal allergies.',
        times: const ['8:00 PM'],
        pillColorIndex: 0,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 3, 22),
      ),
    ],
  ),
  DemoPersona(
    id: 'priya',
    name: 'Priya Nair',
    emailHint: 'priya.demo@verifi.app',
    tagline: 'Thyroid + supplements',
    medications: [
      _med(
        id: 'priya-levothyroxine',
        name: 'Levothyroxine 75mcg',
        dosage: '1 tablet',
        instruction: 'Empty stomach',
        category: 'Thyroid · Oral tablet',
        notes: 'Wait 30–60 min before coffee or food.',
        times: const ['6:30 AM'],
        pillColorIndex: 0,
        status: MedicationStatus.active,
        startedAt: DateTime(2025, 8, 14),
      ),
      _med(
        id: 'priya-iron',
        name: 'Iron 65mg',
        dosage: '1 tablet',
        instruction: 'With lunch',
        category: 'Supplement · Oral tablet',
        notes: 'Avoid taking with calcium.',
        times: const ['lunch'],
        pillColorIndex: 1,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 2, 28),
      ),
      _med(
        id: 'priya-b12',
        name: 'Vitamin B12',
        dosage: '1 tablet',
        instruction: 'Morning',
        category: 'Supplement · Oral tablet',
        notes: 'Once daily.',
        times: const ['8:00 AM'],
        pillColorIndex: 3,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 3, 10),
      ),
    ],
  ),
];

/// Sample medication list used to drive the UI shell (default offline seed).
final List<Medication> mockMedications = [
  _med(
    id: 'amoxicillin',
    name: 'Amoxicillin 500mg',
    dosage: '1 tablet',
    instruction: 'After meal',
    category: 'Antibiotic · Oral tablet',
    notes: 'Finish the full course.',
    times: const ['9:00 AM', '1:00 PM', '9:00 PM'],
    pillColorIndex: 0,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 4, 9),
  ),
  _med(
    id: 'metformin',
    name: 'Metformin 850mg',
    dosage: '1 tablet',
    instruction: 'With breakfast',
    category: 'Diabetes · Oral tablet',
    notes: 'Check your blood sugar before taking.',
    times: const ['8:00 AM', '8:00 PM'],
    pillColorIndex: 1,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 3, 28),
  ),
  _med(
    id: 'vitamin-d',
    name: 'Vitamin D3',
    dosage: '1 capsule',
    instruction: 'After breakfast',
    category: 'Supplement · Capsule',
    notes: 'Once every 3 days, with food.',
    times: const ['breakfast'],
    pillColorIndex: 2,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 4, 1),
    frequencyDays: 3,
  ),
  _med(
    id: 'ibuprofen',
    name: 'Ibuprofen 400mg',
    dosage: '1 tablet',
    instruction: 'With food',
    category: 'Pain relief · Oral tablet',
    notes: 'Do not exceed 3 tablets per day.',
    times: const ['lunch', '8:00 PM'],
    pillColorIndex: 1,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 4, 6),
  ),
  _med(
    id: 'melatonin',
    name: 'Melatonin 3mg',
    dosage: '1 tablet',
    instruction: 'Before bed',
    category: 'Sleep aid · Oral tablet',
    notes: 'Take 30 minutes before sleep.',
    times: const ['10:00 PM'],
    pillColorIndex: 3,
    status: MedicationStatus.active,
    startedAt: DateTime(2026, 4, 3),
  ),
  _med(
    id: 'losartan',
    name: 'Losartan 50mg',
    dosage: '1 tablet',
    instruction: 'With water',
    category: 'Blood pressure · Oral tablet',
    notes: 'Take at the same time each day.',
    times: const ['8:00 AM'],
    pillColorIndex: 0,
    status: MedicationStatus.paused,
    startedAt: DateTime(2026, 2, 14),
  ),
  _med(
    id: 'azithromycin',
    name: 'Azithromycin 250mg',
    dosage: '1 tablet',
    instruction: 'Before meal',
    category: 'Antibiotic · Oral tablet',
    notes: 'Course completed.',
    times: const ['10:00 AM'],
    pillColorIndex: 3,
    status: MedicationStatus.finished,
    startedAt: DateTime(2026, 1, 20),
  ),
];

/// Picks a random demo persona (optionally excluding [exceptId]).
DemoPersona pickRandomDemoPersona({String? exceptId, math.Random? random}) {
  final rng = random ?? math.Random();
  final pool = exceptId == null
      ? demoPersonas
      : demoPersonas.where((p) => p.id != exceptId).toList();
  final list = pool.isEmpty ? demoPersonas : pool;
  return list[rng.nextInt(list.length)];
}

/// Builds a few realistic “taken / skipped” events for [persona].
List<DoseLogEntry> buildDemoDoseHistory(
  DemoPersona persona, {
  math.Random? random,
  DateTime? now,
}) {
  final rng = random ?? math.Random();
  final clock = now ?? DateTime.now();
  final active = persona.medications
      .where((m) => m.status == MedicationStatus.active)
      .toList();
  if (active.isEmpty) return const [];

  final entries = <DoseLogEntry>[];
  for (var dayOffset = 0; dayOffset < 5; dayOffset++) {
    final day = clock.subtract(Duration(days: dayOffset));
    for (final med in active) {
      if (rng.nextDouble() < 0.35) continue; // leave some gaps
      final hour = 7 + rng.nextInt(14);
      final minute = [0, 15, 30, 45][rng.nextInt(4)];
      final action = rng.nextDouble() < 0.12 ? 'skipped' : 'taken';
      entries.add(
        DoseLogEntry(
          id: 'demo-${persona.id}-${med.id}-$dayOffset',
          medicationId: med.id,
          medicationName: med.name,
          action: action,
          at: DateTime(day.year, day.month, day.day, hour, minute),
        ),
      );
    }
  }
  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}
