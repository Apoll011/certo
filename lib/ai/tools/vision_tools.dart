import 'ai_tool.dart';

/// The 3 canonical verification outcomes defined by the Certo safety principle.
enum VisualVerificationStatus {
  identifying,
  confirmedMatch,
  confirmedMismatch,
  uncertain;

  static VisualVerificationStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'confirmed_match':
      case 'match':
        return VisualVerificationStatus.confirmedMatch;
      case 'confirmed_mismatch':
      case 'mismatch':
      case 'not_your_medication':
        return VisualVerificationStatus.confirmedMismatch;
      case 'uncertain':
      case 'not_sure':
      default:
        return VisualVerificationStatus.uncertain;
    }
  }

  String toApiString() {
    switch (this) {
      case VisualVerificationStatus.identifying:
        return 'identifying';
      case VisualVerificationStatus.confirmedMatch:
        return 'confirmed_match';
      case VisualVerificationStatus.confirmedMismatch:
        return 'confirmed_mismatch';
      case VisualVerificationStatus.uncertain:
        return 'uncertain';
    }
  }
}

/// Structured card data to render the visual verification bottom sheet matching the mockup.
class VisualVerificationCardData {
  const VisualVerificationCardData({
    required this.status,
    this.identifiedMedicationName,
    this.category,
    this.message,
    this.expectedMedicationName,
    this.nextDoseTime,
    this.nextDoseInstruction,
    this.canConfirm = false,
  });

  final VisualVerificationStatus status;
  final String? identifiedMedicationName;
  final String? category;
  final String? message;
  final String? expectedMedicationName;
  final String? nextDoseTime;
  final String? nextDoseInstruction;
  final bool canConfirm;

  Map<String, dynamic> toJson() => {
    'status': status.toApiString(),
    if (identifiedMedicationName != null)
      'identified_medication_name': identifiedMedicationName,
    if (category != null) 'category': category,
    if (message != null) 'message': message,
    if (expectedMedicationName != null)
      'expected_medication_name': expectedMedicationName,
    if (nextDoseTime != null) 'next_dose_time': nextDoseTime,
    if (nextDoseInstruction != null)
      'next_dose_instruction': nextDoseInstruction,
    'can_confirm': canConfirm,
  };
}

/// Request to activate visual scanning mode.
class VisualModeRequest {
  const VisualModeRequest({
    this.reason,
    this.expectedMedicationId,
    this.expectedMedicationName,
  });

  final String? reason;
  final String? expectedMedicationId;
  final String? expectedMedicationName;
}

/// Tool that instructs the app to open the camera / visual scanning viewfinder.
class StartVisualModeTool extends AiTool {
  StartVisualModeTool({this.onStartVisualMode});

  final Future<void> Function(VisualModeRequest request)? onStartVisualMode;

  @override
  String get name => 'start_visual_mode';

  @override
  String get description =>
      'Enter visual camera mode to capture and inspect a medication package, pill, or pill organizer. Call this when the user asks "is this my medication?", wants to verify what they are holding, or requests camera identification.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'reason': {
        'type': 'string',
        'description':
            'Why visual mode is being triggered, e.g. "Verifying Amoxicillin dose".',
      },
      'expected_medication_id': {
        'type': 'string',
        'description': 'Medication ID expected according to the current schedule.',
      },
      'expected_medication_name': {
        'type': 'string',
        'description': 'Name of the scheduled medication, e.g. "Amoxicillin 500mg".',
      },
    },
    'required': [],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final request = VisualModeRequest(
      reason: arguments['reason'] as String?,
      expectedMedicationId: arguments['expected_medication_id'] as String?,
      expectedMedicationName: arguments['expected_medication_name'] as String?,
    );

    try {
      if (onStartVisualMode != null) {
        await onStartVisualMode!(request);
      }
      return ToolResult.ok({
        'visual_mode_active': true,
        'reason': request.reason ?? 'Visual inspection started',
        'expected_medication_name': request.expectedMedicationName,
      });
    } catch (e) {
      return ToolResult.failure('Failed to enter visual mode: $e');
    }
  }
}

/// Tool that displays the visual verification card on the camera screen.
class ShowVisualVerificationResultTool extends AiTool {
  ShowVisualVerificationResultTool({this.onShowResult});

  final void Function(VisualVerificationCardData data)? onShowResult;

  @override
  String get name => 'show_visual_verification_result';

  @override
  String get description =>
      'Display the verification result on the camera scanner sheet. Must strictly follow Certo safety rules: choose only "confirmed_match", "confirmed_mismatch", or "uncertain". Never guess if uncertain.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['confirmed_match', 'confirmed_mismatch', 'uncertain'],
        'description':
            'The conclusive verification result: confirmed_match (matches scheduled medication), confirmed_mismatch (matches a different medication), or uncertain (unclear/blurry/inconclusive).',
      },
      'identified_medication_name': {
        'type': 'string',
        'description':
            'The medication name detected on the package, e.g. "Amoxicillin 500mg".',
      },
      'category': {
        'type': 'string',
        'description':
            'Form/category detected, e.g. "Antibiotic · Oral tablet".',
      },
      'message': {
        'type': 'string',
        'description':
            'Explanation text, e.g. "This is your medication. It\'s scheduled for now."',
      },
      'expected_medication_name': {
        'type': 'string',
        'description':
            'The medication name that was scheduled, e.g. "Amoxicillin 500mg".',
      },
      'next_dose_time': {
        'type': 'string',
        'description': 'Scheduled dose time, e.g. "9:00 AM".',
      },
      'next_dose_instruction': {
        'type': 'string',
        'description': 'Dose instruction, e.g. "1 tablet · After meal".',
      },
      'can_confirm': {
        'type': 'boolean',
        'description':
            'Whether the user can tap "Confirm" to log the dose as taken (typically true for confirmed_match).',
      },
    },
    'required': ['status'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final statusStr = arguments['status'] as String?;
    final status = VisualVerificationStatus.fromString(statusStr);

    final data = VisualVerificationCardData(
      status: status,
      identifiedMedicationName:
          arguments['identified_medication_name'] as String?,
      category: arguments['category'] as String?,
      message: arguments['message'] as String?,
      expectedMedicationName:
          arguments['expected_medication_name'] as String?,
      nextDoseTime: arguments['next_dose_time'] as String?,
      nextDoseInstruction:
          arguments['next_dose_instruction'] as String?,
      canConfirm: (arguments['can_confirm'] as bool?) ??
          (status == VisualVerificationStatus.confirmedMatch),
    );

    try {
      onShowResult?.call(data);
      return ToolResult.ok({
        'displayed': true,
        ...data.toJson(),
      });
    } catch (e) {
      return ToolResult.failure('Failed to show verification result: $e');
    }
  }
}
