import 'dart:math';

import '../../models/medication.dart';
import '../../state/app_state.dart';
import '../../utils/schedule.dart';
import 'ai_tool.dart';

/// Helper to serialize a medication with runtime status (taken today, snoozed, etc.).
Map<String, dynamic> medicationToJson(Medication m, AppState state) {
  final snoozed = state.snoozedUntilFor(m.id);
  return {
    'id': m.id,
    'name': m.name,
    'dosage': m.dosage,
    'instruction': m.instruction,
    'category': m.category,
    'notes': m.notes,
    'times': m.times,
    'frequency_days': m.frequencyDays,
    'pill_color_index': m.pillColorIndex,
    'status': m.status.name,
    'started_at': m.startedAt.toIso8601String().split('T').first,
    'is_taken_today': state.isTaken(m.id),
    'is_snoozed': snoozed != null,
    if (snoozed != null) 'snoozed_until': snoozed.toIso8601String(),
  };
}

/// Helper to resolve a medication by id or case-insensitive name.
Medication? findMedication(AppState state, {String? id, String? name}) {
  if (id != null && id.trim().isNotEmpty) {
    final med = state.medicationById(id.trim());
    if (med != null) return med;
  }
  if (name != null && name.trim().isNotEmpty) {
    final query = name.trim().toLowerCase();
    // 1. Exact match (case insensitive)
    for (final m in state.medications) {
      if (m.name.trim().toLowerCase() == query) return m;
    }
    // 2. Starts with query
    for (final m in state.medications) {
      if (m.name.trim().toLowerCase().startsWith(query)) return m;
    }
    // 3. Contains query
    for (final m in state.medications) {
      if (m.name.trim().toLowerCase().contains(query)) return m;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. ListMedicationsTool
// ─────────────────────────────────────────────────────────────────────────────

class ListMedicationsTool extends AiTool {
  ListMedicationsTool(this.state);

  final AppState state;

  @override
  String get name => 'list_medications';

  @override
  String get description =>
      'List all medications for the user. Supports filtering by status (active, paused, finished, all) and search query.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['active', 'paused', 'finished', 'all'],
        'description':
            'Filter medications by status. Defaults to "active" if not specified.',
      },
      'query': {
        'type': 'string',
        'description':
            'Optional search query to filter by name, category, or notes.',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final statusFilter = arguments['status'] as String? ?? 'active';
    final query = (arguments['query'] as String?)?.trim().toLowerCase();

    var list = state.medications;

    if (statusFilter != 'all') {
      final targetStatus = switch (statusFilter) {
        'paused' => MedicationStatus.paused,
        'finished' => MedicationStatus.finished,
        _ => MedicationStatus.active,
      };
      list = list.where((m) => m.status == targetStatus).toList();
    }

    if (query != null && query.isNotEmpty) {
      list = list.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.category.toLowerCase().contains(query) ||
            m.notes.toLowerCase().contains(query) ||
            m.dosage.toLowerCase().contains(query);
      }).toList();
    }

    final data = list.map((m) => medicationToJson(m, state)).toList();
    return ToolResult.ok({
      'count': data.length,
      'status_filter': statusFilter,
      'query': ?query,
      'medications': data,

    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. GetMedicationDetailsTool
// ─────────────────────────────────────────────────────────────────────────────

class GetMedicationDetailsTool extends AiTool {
  GetMedicationDetailsTool(this.state);

  final AppState state;

  @override
  String get name => 'get_medication_details';

  @override
  String get description =>
      'Get full details for a single medication by ID or name.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Unique ID of the medication (if known).',
      },
      'name': {
        'type': 'string',
        'description':
            'Name of the medication to look up (used if ID is not known).',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final id = arguments['id'] as String?;
    final medName = arguments['name'] as String?;

    if ((id == null || id.isEmpty) && (medName == null || medName.isEmpty)) {
      return ToolResult.failure('Please provide either "id" or "name".');
    }

    final med = findMedication(state, id: id, name: medName);
    if (med == null) {
      return ToolResult.failure(
        'Medication not found matching ${id != null ? 'id "$id"' : 'name "$medName"'}.',
      );
    }

    return ToolResult.ok(medicationToJson(med, state));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. GetNextMedicationsTool
// ─────────────────────────────────────────────────────────────────────────────

class GetNextMedicationsTool extends AiTool {
  GetNextMedicationsTool(this.state, {this.clock});

  final AppState state;

  /// Optional clock provider for deterministic testing.
  final DateTime Function()? clock;

  @override
  String get name => 'get_next_medications';

  @override
  String get description =>
      'Get upcoming medication doses for the user. Returns doses due right now, upcoming scheduled doses, and today’s adherence status.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'hours_ahead': {
        'type': 'integer',
        'description':
            'How many hours into the future to inspect. Default is 24 hours.',
      },
      'include_due_now': {
        'type': 'boolean',
        'description':
            'Whether to specifically flag doses due right now within the lookback window. Default is true.',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final now = clock?.call() ?? DateTime.now();
    final hoursAhead = (arguments['hours_ahead'] as num?)?.toInt() ?? 24;
    final includeDue = arguments['include_due_now'] as bool? ?? true;

    final activeMeds = state.medicationsWithStatus(MedicationStatus.active);

    // 1. Due now doses
    final dueNowList = <Map<String, dynamic>>[];
    if (includeDue) {
      final dues = dueDoses(activeMeds, now);
      for (final d in dues) {
        dueNowList.add({
          'medication_id': d.medication.id,
          'medication_name': d.medication.name,
          'dosage': d.medication.dosage,
          'instruction': d.medication.instruction,
          'scheduled_time': d.time,
          'exact_time': d.at.toIso8601String(),
          'is_taken_today': state.isTaken(d.medication.id),
        });
      }
    }

    // 2. Upcoming occurrences within hoursAhead
    final daysToScan = max(1, (hoursAhead / 24).ceil() + 1);
    final upcomingList = <Map<String, dynamic>>[];
    final cutoff = now.add(Duration(hours: hoursAhead));

    for (final m in activeMeds) {
      final occs = upcomingOccurrences(m, now, days: daysToScan);
      for (final occ in occs) {
        if (occ.isAfter(cutoff)) continue;
        upcomingList.add({
          'medication_id': m.id,
          'medication_name': m.name,
          'dosage': m.dosage,
          'instruction': m.instruction,
          'scheduled_datetime': occ.toIso8601String(),
          'is_taken_today': state.isTaken(m.id),
        });
      }
    }

    // Sort upcoming chronologically
    upcomingList.sort(
      (a, b) => (a['scheduled_datetime'] as String).compareTo(
        b['scheduled_datetime'] as String,
      ),
    );

    return ToolResult.ok({
      'current_time': now.toIso8601String(),
      'hours_inspected': hoursAhead,
      'due_now_count': dueNowList.length,
      'due_now': dueNowList,
      'upcoming_count': upcomingList.length,
      'upcoming': upcomingList,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CreateMedicationTool
// ─────────────────────────────────────────────────────────────────────────────

class CreateMedicationTool extends AiTool {
  CreateMedicationTool(this.state);

  final AppState state;

  @override
  String get name => 'create_medication';

  @override
  String get description =>
      'Create and schedule a new medication for the user. Automatically syncs alarms and persistence.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description':
            'Name of the medication, e.g. "Amoxicillin", "Vitamin D3", "Metformin".',
      },
      'dosage': {
        'type': 'string',
        'description':
            'Dosage amount and form, e.g. "500 mg", "1 tablet", "10 ml".',
      },
      'times': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Scheduled times of day, e.g. ["08:00", "20:00"], ["9:00 AM"], or meal anchors ["breakfast", "dinner"].',
      },
      'instruction': {
        'type': 'string',
        'description':
            'Intake instructions, e.g. "After meal", "With water", "Before bed".',
      },
      'category': {
        'type': 'string',
        'description':
            'Category or drug class, e.g. "Antibiotic", "Blood pressure", "Supplement".',
      },
      'notes': {
        'type': 'string',
        'description': 'Additional patient notes, warnings, or physician advice.',
      },
      'frequency_days': {
        'type': 'integer',
        'description':
            'Frequency in days: 1 = every day (default), 2 = every other day, 3 = every 3 days, etc.',
      },
      'pill_color_index': {
        'type': 'integer',
        'description': 'Visual color index for the medication avatar (0 to 7).',
      },
    },
    'required': ['name', 'dosage', 'times'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final medName = (arguments['name'] as String?)?.trim();
    if (medName == null || medName.isEmpty) {
      return ToolResult.failure('Parameter "name" is required.');
    }

    final dosage = (arguments['dosage'] as String?)?.trim();
    if (dosage == null || dosage.isEmpty) {
      return ToolResult.failure('Parameter "dosage" is required.');
    }

    final timesRaw = arguments['times'];
    List<String> times = [];
    if (timesRaw is List) {
      times = timesRaw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (times.isEmpty) {
      return ToolResult.failure(
        'Parameter "times" must contain at least one time string (e.g. ["09:00"]).',
      );
    }

    final instruction = (arguments['instruction'] as String?)?.trim() ?? 'With water';
    final category = (arguments['category'] as String?)?.trim() ?? 'General';
    final notes = (arguments['notes'] as String?)?.trim() ?? '';
    final frequencyDays = (arguments['frequency_days'] as num?)?.toInt() ?? 1;
    final pillColorIndex = (arguments['pill_color_index'] as num?)?.toInt() ?? 0;

    final id = 'med_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    final newMed = Medication(
      id: id,
      name: medName,
      dosage: dosage,
      instruction: instruction,
      category: category,
      notes: notes,
      times: times,
      pillColorIndex: pillColorIndex.clamp(0, 7),
      status: MedicationStatus.active,
      startedAt: DateTime.now(),
      frequencyDays: frequencyDays > 0 ? frequencyDays : 1,
    );

    final created = await state.addMedication(newMed);
    return ToolResult.ok({
      'message': 'Medication "${newMed.name}" created successfully.',
      'medication': medicationToJson(created ?? newMed, state),
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. UpdateMedicationTool
// ─────────────────────────────────────────────────────────────────────────────

class UpdateMedicationTool extends AiTool {
  UpdateMedicationTool(this.state);

  final AppState state;

  @override
  String get name => 'update_medication';

  @override
  String get description =>
      'Update an existing medication’s dosage, instructions, times, notes, frequency, or status.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Unique ID of the medication to update.',
      },
      'name': {
        'type': 'string',
        'description':
            'Current name of the medication (used if ID is unknown).',
      },
      'new_name': {
        'type': 'string',
        'description': 'New name for the medication.',
      },
      'dosage': {
        'type': 'string',
        'description': 'Updated dosage, e.g. "1000 mg" or "2 tablets".',
      },
      'instruction': {
        'type': 'string',
        'description': 'Updated instruction, e.g. "Take with food".',
      },
      'category': {
        'type': 'string',
        'description': 'Updated category, e.g. "Pain relief".',
      },
      'notes': {
        'type': 'string',
        'description': 'Updated notes or comments.',
      },
      'times': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Updated scheduled times list, e.g. ["08:00", "20:00"].',
      },
      'frequency_days': {
        'type': 'integer',
        'description': 'Updated frequency in days.',
      },
      'pill_color_index': {
        'type': 'integer',
        'description': 'Updated avatar color index (0 to 7).',
      },
      'status': {
        'type': 'string',
        'enum': ['active', 'paused', 'finished'],
        'description': 'Updated status of the medication.',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final id = arguments['id'] as String?;
    final medName = arguments['name'] as String?;

    final existing = findMedication(state, id: id, name: medName);
    if (existing == null) {
      return ToolResult.failure(
        'Could not find medication matching ${id != null ? 'id "$id"' : 'name "$medName"'}.',
      );
    }

    final newName = (arguments['new_name'] as String?)?.trim();
    final dosage = (arguments['dosage'] as String?)?.trim();
    final instruction = (arguments['instruction'] as String?)?.trim();
    final category = (arguments['category'] as String?)?.trim();
    final notes = (arguments['notes'] as String?)?.trim();
    final freq = (arguments['frequency_days'] as num?)?.toInt();
    final color = (arguments['pill_color_index'] as num?)?.toInt();

    List<String>? times;
    if (arguments['times'] is List) {
      times = (arguments['times'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    MedicationStatus? status;
    final statusStr = arguments['status'] as String?;
    if (statusStr != null) {
      status = switch (statusStr.toLowerCase()) {
        'paused' => MedicationStatus.paused,
        'finished' => MedicationStatus.finished,
        _ => MedicationStatus.active,
      };
    }

    final updated = existing.copyWith(
      name: (newName != null && newName.isNotEmpty) ? newName : null,
      dosage: (dosage != null && dosage.isNotEmpty) ? dosage : null,
      instruction: (instruction != null && instruction.isNotEmpty)
          ? instruction
          : null,
      category: (category != null && category.isNotEmpty) ? category : null,
      notes: notes,
      times: (times != null && times.isNotEmpty) ? times : null,
      frequencyDays: (freq != null && freq > 0) ? freq : null,
      pillColorIndex: (color != null) ? color.clamp(0, 7) : null,
      status: status,
    );

    await state.updateMedication(updated);

    return ToolResult.ok({
      'message': 'Medication "${updated.name}" updated successfully.',
      'medication': medicationToJson(updated, state),
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. DeleteMedicationTool
// ─────────────────────────────────────────────────────────────────────────────

class DeleteMedicationTool extends AiTool {
  DeleteMedicationTool(this.state);

  final AppState state;

  @override
  String get name => 'delete_medication';

  @override
  String get description =>
      'Delete a medication from the user’s schedule by ID or name.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Unique ID of the medication to delete.',
      },
      'name': {
        'type': 'string',
        'description':
            'Name of the medication to delete (used if ID is unknown).',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final id = arguments['id'] as String?;
    final medName = arguments['name'] as String?;

    final existing = findMedication(state, id: id, name: medName);
    if (existing == null) {
      return ToolResult.failure(
        'Could not find medication matching ${id != null ? 'id "$id"' : 'name "$medName"'}.',
      );
    }

    await state.deleteMedication(existing.id);

    return ToolResult.ok({
      'message': 'Medication "${existing.name}" (ID: ${existing.id}) has been deleted.',
      'deleted_id': existing.id,
      'deleted_name': existing.name,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. MarkMedicationTakenTool
// ─────────────────────────────────────────────────────────────────────────────

class MarkMedicationTakenTool extends AiTool {
  MarkMedicationTakenTool(this.state);

  final AppState state;

  @override
  String get name => 'mark_medication_taken';

  @override
  String get description =>
      'Mark or unmark a medication dose as taken for today, logging the dose event.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Unique ID of the medication.',
      },
      'name': {
        'type': 'string',
        'description':
            'Name of the medication (used if ID is unknown).',
      },
      'taken': {
        'type': 'boolean',
        'description':
            'True to mark as taken (default), false to unmark as not taken.',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final id = arguments['id'] as String?;
    final medName = arguments['name'] as String?;
    final taken = arguments['taken'] as bool? ?? true;

    final existing = findMedication(state, id: id, name: medName);
    if (existing == null) {
      return ToolResult.failure(
        'Could not find medication matching ${id != null ? 'id "$id"' : 'name "$medName"'}.',
      );
    }

    final currentlyTaken = state.isTaken(existing.id);
    if (taken && !currentlyTaken) {
      state.markTaken(existing.id);
    } else if (!taken && currentlyTaken) {
      state.toggleTaken(existing.id);
    }

    return ToolResult.ok({
      'medication_id': existing.id,
      'medication_name': existing.name,
      'is_taken_today': taken,
      'message': taken
          ? 'Marked "${existing.name}" as taken for today.'
          : 'Unmarked "${existing.name}" for today.',
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. SnoozeMedicationTool
// ─────────────────────────────────────────────────────────────────────────────

class SnoozeMedicationTool extends AiTool {
  SnoozeMedicationTool(this.state);

  final AppState state;

  @override
  String get name => 'snooze_medication';

  @override
  String get description =>
      'Snooze a medication reminder for a specified number of minutes (e.g. 10 or 15 minutes).';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Unique ID of the medication.',
      },
      'name': {
        'type': 'string',
        'description': 'Name of the medication to snooze.',
      },
      'minutes': {
        'type': 'integer',
        'description': 'Minutes to snooze the reminder for (default 10).',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final id = arguments['id'] as String?;
    final medName = arguments['name'] as String?;
    final minutes = (arguments['minutes'] as num?)?.toInt() ?? 10;

    final existing = findMedication(state, id: id, name: medName);
    if (existing == null) {
      return ToolResult.failure(
        'Could not find medication matching ${id != null ? 'id "$id"' : 'name "$medName"'}.',
      );
    }

    await state.snooze(existing.id, minutes: minutes);

    final until = state.snoozedUntilFor(existing.id);

    return ToolResult.ok({
      'medication_id': existing.id,
      'medication_name': existing.name,
      'snoozed_minutes': minutes,
      'snoozed_until': until?.toIso8601String(),
      'message': 'Snoozed reminder for "${existing.name}" for $minutes minutes.',
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. GetUserSummaryTool
// ─────────────────────────────────────────────────────────────────────────────

class GetUserSummaryTool extends AiTool {
  GetUserSummaryTool(this.state);

  final AppState state;

  @override
  String get name => 'get_user_summary';

  @override
  String get description =>
      'Get an overview summary of the user profile, total active medications, and adherence stats for today.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final active = state.medicationsWithStatus(MedicationStatus.active);
    final takenCount = state.takenIds.length;

    return ToolResult.ok({
      'user_name': state.userName,
      'is_authenticated': state.isAuthenticated,
      'active_medications_count': active.length,
      'total_medications_count': state.medications.length,
      'doses_taken_today_count': takenCount,
    });
  }
}
