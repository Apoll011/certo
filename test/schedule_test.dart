import 'package:flutter_test/flutter_test.dart';

import 'package:medication_reminder/models/medication.dart';
import 'package:medication_reminder/utils/schedule.dart';

Medication _med({
  String id = 'm1',
  List<String> times = const ['9:00 AM'],
  int frequencyDays = 1,
  DateTime? startedAt,
}) {
  return Medication(
    id: id,
    name: 'Test med',
    dosage: '1 tablet',
    instruction: 'With water',
    category: 'Test',
    notes: '',
    times: times,
    pillColorIndex: 0,
    status: MedicationStatus.active,
    startedAt: startedAt ?? DateTime(2026, 1, 1),
    frequencyDays: frequencyDays,
  );
}

void main() {
  group('time resolution', () {
    test('parses 12-hour clock times', () {
      expect(resolveTimeMinutes('9:00 AM'), 540);
      expect(resolveTimeMinutes('2:30 PM'), 870);
      expect(resolveTimeMinutes('8:00 PM'), 1200);
    });

    test('parses 24-hour clock times', () {
      expect(resolveTimeMinutes('14:00'), 840);
      expect(resolveTimeMinutes('08:00'), 480);
    });

    test('resolves meal anchors to default times', () {
      expect(resolveTimeMinutes('breakfast'), breakfastMinutes);
      expect(resolveTimeMinutes('lunch'), lunchMinutes);
      expect(resolveTimeMinutes('dinner'), dinnerMinutes);
      expect(lunchMinutes, 14 * 60); // "lunch is like 14h"
    });

    test('detects meal tokens', () {
      expect(isMealToken('lunch'), isTrue);
      expect(isMealToken('Lunch'), isTrue);
      expect(isMealToken('9:00 AM'), isFalse);
    });
  });

  group('frequency scheduling', () {
    test('daily medication is scheduled every day', () {
      final m = _med(frequencyDays: 1);
      expect(isScheduledOn(m, DateTime(2026, 1, 1)), isTrue);
      expect(isScheduledOn(m, DateTime(2026, 1, 7)), isTrue);
    });

    test('every-3-days medication only on matching days', () {
      final m = _med(frequencyDays: 3);
      expect(isScheduledOn(m, DateTime(2026, 1, 1)), isTrue); // day 0
      expect(isScheduledOn(m, DateTime(2026, 1, 4)), isTrue); // day 3
      expect(isScheduledOn(m, DateTime(2026, 1, 2)), isFalse); // day 1
      expect(isScheduledOn(m, DateTime(2026, 1, 3)), isFalse); // day 2
    });

    test('not scheduled before the start date', () {
      final m = _med(startedAt: DateTime(2026, 1, 10));
      expect(isScheduledOn(m, DateTime(2026, 1, 9)), isFalse);
      expect(isScheduledOn(m, DateTime(2026, 1, 10)), isTrue);
    });
  });

  group('occurrences', () {
    test('emits daily doses ahead of the start time', () {
      final m = _med(times: const ['8:00 AM'], frequencyDays: 1);
      final from = DateTime(2026, 1, 1, 7, 0);
      final occ = upcomingOccurrences(m, from, days: 3);
      expect(occ.length, 4); // Jan 1, 2, 3, 4 at 08:00
      expect(occ.first, DateTime(2026, 1, 1, 8, 0));
    });

    test('emits every-2-days doses', () {
      final m = _med(times: const ['8:00 AM'], frequencyDays: 2);
      final from = DateTime(2026, 1, 1, 0, 0);
      final occ = upcomingOccurrences(m, from, days: 5);
      expect(occ.length, 3); // Jan 1, 3, 5
      expect(occ[1], DateTime(2026, 1, 3, 8, 0));
    });
  });

  group('due window', () {
    test('finds a dose within the lookback window', () {
      final m = _med(times: const ['9:00 AM']);
      final now = DateTime(2026, 1, 1, 9, 2);
      final due = dueDoses([m], now);
      expect(due.length, 1);
      expect(due.first.at, DateTime(2026, 1, 1, 9, 0));
    });

    test('ignores doses outside the window', () {
      final m = _med(times: const ['9:00 AM']);
      expect(dueDoses([m], DateTime(2026, 1, 1, 9, 20)), isEmpty);
      expect(dueDoses([m], DateTime(2026, 1, 1, 8, 40)), isEmpty);
    });

    test('handles meal anchors and frequency together', () {
      final m = _med(times: const ['lunch'], frequencyDays: 3);
      // Jan 4 is 3 days after start, lunch = 14:00.
      final now = DateTime(2026, 1, 4, 14, 3);
      final due = dueDoses([m], now);
      expect(due.length, 1);
      expect(due.first.at, DateTime(2026, 1, 4, 14, 0));
    });
  });
}
