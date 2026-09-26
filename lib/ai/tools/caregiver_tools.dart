import '../../models/caregiver.dart';
import '../../state/app_state.dart';
import 'ai_tool.dart';

/// List people the signed-in caregiver supports.
class ListCareRecipientsTool extends AiTool {
  ListCareRecipientsTool(this.state);

  final AppState state;

  @override
  String get name => 'list_care_recipients';

  @override
  String get description =>
      'List people this caregiver supports (active consent links). '
      'Use in caregiver mode for "who am I watching?" or before checking adherence.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    if (!state.isCaregiver) {
      return ToolResult.failure(
        'Caregiver mode is off. Enable it in Settings, or the user is not a caregiver.',
      );
    }
    await state.refreshCaregiverData();
    final list = state.careRecipients.map((l) {
      final snap = state.careSnapshots[l.id];
      return {
        'link_id': l.id,
        'patient_id': l.patientId,
        'name': l.displayName,
        'label': l.label,
        'today_tone': snap?.todayTone.name ?? 'none',
        'active_medications': snap?.activeMedCount ?? 0,
      };
    }).toList();
    return ToolResult.ok({
      'count': list.length,
      'recipients': list,
      'message': list.isEmpty
          ? 'No care recipients yet. Redeem an invite code from the person you support.'
          : 'Found ${list.length} care recipient(s).',
    });
  }
}

/// Summarize adherence / heatmap for one care recipient.
class GetCareAdherenceTool extends AiTool {
  GetCareAdherenceTool(this.state);

  final AppState state;

  @override
  String get name => 'get_care_adherence';

  @override
  String get description =>
      'Get a care recipient\'s adherence summary and heatmap tones '
      '(green=good, yellow=uncertain, red=missed/mismatch). Pass link_id or name.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'link_id': {'type': 'string'},
          'name': {
            'type': 'string',
            'description': 'Display name / label of the care recipient.',
          },
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    if (!state.isCaregiver) {
      return ToolResult.failure('Caregiver mode is off.');
    }
    final linkId = (arguments['link_id'] as String?)?.trim();
    final name = (arguments['name'] as String?)?.trim().toLowerCase();
    CaregiverLink? link;
    for (final l in state.careRecipients) {
      if (linkId != null && l.id == linkId) {
        link = l;
        break;
      }
      if (name != null &&
          name.isNotEmpty &&
          l.displayName.toLowerCase().contains(name)) {
        link = l;
        break;
      }
    }
    if (link == null && state.careRecipients.length == 1) {
      link = state.careRecipients.first;
    }
    if (link == null) {
      return ToolResult.failure(
        'Care recipient not found. Call list_care_recipients first.',
      );
    }
    final snap = await state.loadCareRecipient(link.id);
    if (snap == null) {
      return ToolResult.failure('Could not load adherence for ${link.displayName}.');
    }
    final recent = snap.heatmap.reversed.take(7).map((d) => {
          'date': d.date.toIso8601String().split('T').first,
          'tone': d.tone.name,
          'summary': d.summary,
          'taken': d.takenCount,
          'scheduled': d.scheduledCount,
        }).toList();
    return ToolResult.ok({
      'name': snap.link.displayName,
      'link_id': snap.link.id,
      'today_tone': snap.todayTone.name,
      'active_medications': snap.activeMedCount,
      'taken_today_count': snap.takenTodayIds.length,
      'last_7_days': recent,
      'message':
          '${snap.link.displayName}: today is ${snap.todayTone.name}. '
          '${snap.activeMedCount} active meds, ${snap.takenTodayIds.length} taken today.',
    });
  }
}

/// Create a patient invite code (for the signed-in user to share).
class CreateCaregiverInviteTool extends AiTool {
  CreateCaregiverInviteTool(this.state);

  final AppState state;

  @override
  String get name => 'create_caregiver_invite';

  @override
  String get description =>
      'Generate (or reuse) an invite code so a caregiver can view this user\'s '
      'adherence. The user can revoke later. Use when the user wants to share '
      'visibility with a family member or aide.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    if (!state.isAuthenticated) {
      return ToolResult.failure('Sign in required to create an invite.');
    }
    try {
      final link = await state.createCaregiverInvite();
      if (link == null) {
        return ToolResult.failure('Could not create invite.');
      }
      return ToolResult.ok({
        'invite_code': link.inviteCode,
        'status': link.status.apiValue,
        'message':
            'Share code ${link.inviteCode} with your caregiver. You can revoke anytime in Sharing.',
      });
    } catch (e) {
      return ToolResult.failure('$e');
    }
  }
}

/// Redeem an invite as a caregiver.
class RedeemCaregiverInviteTool extends AiTool {
  RedeemCaregiverInviteTool(this.state);

  final AppState state;

  @override
  String get name => 'redeem_caregiver_invite';

  @override
  String get description =>
      'Redeem a patient\'s invite code to start supporting them (caregiver mode).';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'code': {'type': 'string'},
          'label': {
            'type': 'string',
            'description': 'Optional nickname, e.g. "Mom".',
          },
        },
        'required': ['code'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final code = (arguments['code'] as String?)?.trim() ?? '';
    if (code.isEmpty) {
      return ToolResult.failure('Parameter "code" is required.');
    }
    try {
      final link = await state.redeemCaregiverInvite(
        code: code,
        label: (arguments['label'] as String?)?.trim() ?? '',
      );
      return ToolResult.ok({
        'link_id': link.id,
        'name': link.displayName,
        'message': 'Now supporting ${link.displayName}. Consent is revocable by them.',
      });
    } catch (e) {
      return ToolResult.failure('$e');
    }
  }
}
