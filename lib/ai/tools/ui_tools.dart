import '../../models/medication.dart';
import '../../state/app_state.dart';
import 'ai_tool.dart';
import 'medication_tools.dart';

/// Rich UI payload the chat screens render inside an assistant bubble.
sealed class ChatUiAttachment {
  const ChatUiAttachment({this.caption});

  /// Optional short text shown above the visual card(s).
  final String? caption;

  Map<String, dynamic> toJson();
}

/// One medication highlight card (name, dosage, times, badge, etc.).
class MedicationCardAttachment extends ChatUiAttachment {
  const MedicationCardAttachment({
    required this.medicationId,
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.category,
    required this.times,
    required this.pillColorIndex,
    this.status = 'active',
    this.badge,
    this.highlight,
    this.notes,
    this.isTakenToday = false,
    this.isSnoozed = false,
    super.caption,
  });

  final String medicationId;
  final String name;
  final String dosage;
  final String instruction;
  final String category;
  final List<String> times;
  final int pillColorIndex;
  final String status;

  /// Small pill label, e.g. "Next", "Due now", "Taken".
  final String? badge;

  /// Emphasized line, e.g. "8:00 AM · After breakfast".
  final String? highlight;
  final String? notes;
  final bool isTakenToday;
  final bool isSnoozed;

  factory MedicationCardAttachment.fromMedication(
    Medication m,
    AppState state, {
    String? caption,
    String? badge,
    String? highlight,
  }) {
    return MedicationCardAttachment(
      medicationId: m.id,
      name: m.name,
      dosage: m.dosage,
      instruction: m.instruction,
      category: m.category,
      times: List<String>.of(m.times),
      pillColorIndex: m.pillColorIndex,
      status: m.status.name,
      badge: badge,
      highlight: highlight ??
          (m.times.isNotEmpty ? '${m.firstTime} · ${m.instruction}' : null),
      notes: m.notes.isNotEmpty ? m.notes : null,
      isTakenToday: state.isTaken(m.id),
      isSnoozed: state.snoozedUntilFor(m.id) != null,
      caption: caption,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'medication_card',
        'medication_id': medicationId,
        'name': name,
        'dosage': dosage,
        'instruction': instruction,
        'category': category,
        'times': times,
        'pill_color_index': pillColorIndex,
        'status': status,
        if (badge != null) 'badge': badge,
        if (highlight != null) 'highlight': highlight,
        if (notes != null) 'notes': notes,
        'is_taken_today': isTakenToday,
        'is_snoozed': isSnoozed,
        if (caption != null) 'caption': caption,
      };
}

/// A vertical list of medication cards (today's schedule, search results, etc.).
class MedicationListAttachment extends ChatUiAttachment {
  const MedicationListAttachment({
    required this.title,
    required this.items,
    super.caption,
  });

  final String title;
  final List<MedicationCardAttachment> items;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'medication_list',
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        if (caption != null) 'caption': caption,
      };
}

/// Compact status / reminder strip (taken, skipped, snoozed).
class DoseStatusAttachment extends ChatUiAttachment {
  const DoseStatusAttachment({
    required this.medicationName,
    required this.statusLabel,
    required this.tone,
    this.detail,
    this.pillColorIndex = 0,
    super.caption,
  });

  final String medicationName;
  final String statusLabel;
  final String tone; // success | warning | info | danger
  final String? detail;
  final int pillColorIndex;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'dose_status',
        'medication_name': medicationName,
        'status_label': statusLabel,
        'tone': tone,
        if (detail != null) 'detail': detail,
        'pill_color_index': pillColorIndex,
        if (caption != null) 'caption': caption,
      };
}

/// Renders a single medication card in the chat UI.
class ShowMedicationTool extends AiTool {
  ShowMedicationTool(this.state, {this.onShowUi});

  final AppState state;
  final void Function(ChatUiAttachment attachment)? onShowUi;

  @override
  String get name => 'show_medication';

  @override
  String get description =>
      'Show a rich medication card in the chat bubble (pill icon, name, dosage, '
      'times, optional badge like "Next" / "Due now"). Use whenever you mention a '
      'specific medication so the user sees a visual card — e.g. next dose, '
      'details, or after identifying a package. Prefer this over only speaking.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Medication id if known.',
          },
          'name': {
            'type': 'string',
            'description': 'Medication name to look up (if id unknown).',
          },
          'badge': {
            'type': 'string',
            'description':
                'Short badge on the card, e.g. "Next", "Due now", "Active", "Paused".',
          },
          'highlight': {
            'type': 'string',
            'description':
                'Emphasized subtitle, e.g. "8:00 AM · After breakfast".',
          },
          'caption': {
            'type': 'string',
            'description': 'Optional short text shown above the card in chat.',
          },
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final med = findMedication(
      state,
      id: arguments['id'] as String?,
      name: arguments['name'] as String?,
    );
    if (med == null) {
      return ToolResult.failure(
        'Medication not found. Pass a valid id or name from list_medications / get_next_medications.',
      );
    }

    final attachment = MedicationCardAttachment.fromMedication(
      med,
      state,
      caption: (arguments['caption'] as String?)?.trim(),
      badge: (arguments['badge'] as String?)?.trim(),
      highlight: (arguments['highlight'] as String?)?.trim(),
    );

    try {
      onShowUi?.call(attachment);
    } catch (e) {
      return ToolResult.failure('Failed to show medication card: $e');
    }

    return ToolResult.ok({
      'shown': true,
      'medication': medicationToJson(med, state),
      'badge': attachment.badge,
      'message': 'Medication card displayed in chat.',
    });
  }
}

/// Renders a list of medication cards (schedule / several meds).
class ShowMedicationsTool extends AiTool {
  ShowMedicationsTool(this.state, {this.onShowUi});

  final AppState state;
  final void Function(ChatUiAttachment attachment)? onShowUi;

  @override
  String get name => 'show_medications';

  @override
  String get description =>
      'Show multiple medication cards in chat (today\'s schedule, search results, '
      'or several due doses). Pass names and/or ids; omit both to show active meds.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'List heading, e.g. "Today\'s schedule", "Due now".',
          },
          'caption': {
            'type': 'string',
            'description': 'Optional text above the list.',
          },
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Medication ids to show (order preserved).',
          },
          'names': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Medication names to show if ids unknown.',
          },
          'badge': {
            'type': 'string',
            'description': 'Optional badge applied to every card.',
          },
          'only_active': {
            'type': 'boolean',
            'description':
                'When ids/names omitted, only include active medications (default true).',
          },
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final title =
        ((arguments['title'] as String?)?.trim().isNotEmpty ?? false)
            ? (arguments['title'] as String).trim()
            : 'Medications';
    final caption = (arguments['caption'] as String?)?.trim();
    final badge = (arguments['badge'] as String?)?.trim();
    final onlyActive = arguments['only_active'] as bool? ?? true;

    final ids = <String>[];
    final idsRaw = arguments['ids'];
    if (idsRaw is List) {
      for (final e in idsRaw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) ids.add(s);
      }
    }
    final names = <String>[];
    final namesRaw = arguments['names'];
    if (namesRaw is List) {
      for (final e in namesRaw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) names.add(s);
      }
    }

    final meds = <Medication>[];
    if (ids.isNotEmpty || names.isNotEmpty) {
      for (final id in ids) {
        final m = findMedication(state, id: id);
        if (m != null && !meds.any((x) => x.id == m.id)) meds.add(m);
      }
      for (final name in names) {
        final m = findMedication(state, name: name);
        if (m != null && !meds.any((x) => x.id == m.id)) meds.add(m);
      }
    } else {
      meds.addAll(
        onlyActive
            ? state.medicationsWithStatus(MedicationStatus.active)
            : state.medications,
      );
    }

    if (meds.isEmpty) {
      return ToolResult.failure('No medications to show.');
    }

    final items = meds
        .map(
          (m) => MedicationCardAttachment.fromMedication(
            m,
            state,
            badge: badge,
          ),
        )
        .toList();

    final attachment = MedicationListAttachment(
      title: title,
      items: items,
      caption: caption,
    );

    try {
      onShowUi?.call(attachment);
    } catch (e) {
      return ToolResult.failure('Failed to show medication list: $e');
    }

    return ToolResult.ok({
      'shown': true,
      'count': items.length,
      'title': title,
      'medications': meds.map((m) => medicationToJson(m, state)).toList(),
      'message': 'Medication list displayed in chat.',
    });
  }
}

/// Shows a compact dose status card (taken / skipped / snoozed / reminder).
class ShowDoseStatusTool extends AiTool {
  ShowDoseStatusTool(this.state, {this.onShowUi});

  final AppState state;
  final void Function(ChatUiAttachment attachment)? onShowUi;

  @override
  String get name => 'show_dose_status';

  @override
  String get description =>
      'Show a compact status card in chat after marking taken, skipping, or '
      'snoozing — visual confirmation with medication name and status.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'name': {'type': 'string'},
          'status_label': {
            'type': 'string',
            'description':
                'e.g. "Marked as taken", "Snoozed 15 min", "Skipped".',
          },
          'tone': {
            'type': 'string',
            'enum': ['success', 'warning', 'info', 'danger'],
            'description': 'Color tone for the status card (default success).',
          },
          'detail': {
            'type': 'string',
            'description': 'Optional extra line, e.g. next dose time.',
          },
          'caption': {'type': 'string'},
        },
        'required': ['status_label'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final statusLabel = (arguments['status_label'] as String?)?.trim();
    if (statusLabel == null || statusLabel.isEmpty) {
      return ToolResult.failure('Parameter "status_label" is required.');
    }

    final med = findMedication(
      state,
      id: arguments['id'] as String?,
      name: arguments['name'] as String?,
    );

    final attachment = DoseStatusAttachment(
      medicationName: med?.name ??
          ((arguments['name'] as String?)?.trim().isNotEmpty == true
              ? (arguments['name'] as String).trim()
              : 'Medication'),
      statusLabel: statusLabel,
      tone: (arguments['tone'] as String?)?.trim() ?? 'success',
      detail: (arguments['detail'] as String?)?.trim(),
      pillColorIndex: med?.pillColorIndex ?? 0,
      caption: (arguments['caption'] as String?)?.trim(),
    );

    try {
      onShowUi?.call(attachment);
    } catch (e) {
      return ToolResult.failure('Failed to show dose status: $e');
    }

    return ToolResult.ok({
      'shown': true,
      'status_label': statusLabel,
      if (med != null) 'medication': medicationToJson(med, state),
      'message': 'Dose status card displayed in chat.',
    });
  }
}
