import 'ai_tool.dart';

/// Why the camera / visual scanner was opened.
enum VisualModeIntent {
  /// Match package against the scheduled dose.
  verify,

  /// Scan a package to add it as a new medication.
  addMedication,

  /// Identify whatever is in frame ("what is this medicine?").
  identify;

  static VisualModeIntent fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'add':
      case 'add_medication':
      case 'addmedication':
        return VisualModeIntent.addMedication;
      case 'identify':
      case 'what_is_this':
      case 'inspect':
        return VisualModeIntent.identify;
      case 'verify':
      case 'check':
      default:
        return VisualModeIntent.verify;
    }
  }

  String toApiString() => switch (this) {
        VisualModeIntent.verify => 'verify',
        VisualModeIntent.addMedication => 'add_medication',
        VisualModeIntent.identify => 'identify',
      };
}

/// Outcomes shown on the visual result card.
enum VisualVerificationStatus {
  identifying,
  confirmedMatch,
  confirmedMismatch,
  uncertain,
  /// Package read successfully (identify / add flows).
  identified,
  /// Package read, but not in the user's medication list.
  notInList;

  static VisualVerificationStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'confirmed_match':
      case 'match':
        return VisualVerificationStatus.confirmedMatch;
      case 'confirmed_mismatch':
      case 'mismatch':
      case 'not_your_medication':
        return VisualVerificationStatus.confirmedMismatch;
      case 'identified':
      case 'info':
        return VisualVerificationStatus.identified;
      case 'not_in_list':
      case 'not_found':
      case 'unknown_to_user':
        return VisualVerificationStatus.notInList;
      case 'uncertain':
      case 'not_sure':
        return VisualVerificationStatus.uncertain;
      case 'identifying':
        return VisualVerificationStatus.identifying;
      default:
        return VisualVerificationStatus.uncertain;
    }
  }

  String toApiString() => switch (this) {
        VisualVerificationStatus.identifying => 'identifying',
        VisualVerificationStatus.confirmedMatch => 'confirmed_match',
        VisualVerificationStatus.confirmedMismatch => 'confirmed_mismatch',
        VisualVerificationStatus.uncertain => 'uncertain',
        VisualVerificationStatus.identified => 'identified',
        VisualVerificationStatus.notInList => 'not_in_list',
      };
}

/// Structured card data for the visual mode bottom sheet.
class VisualVerificationCardData {
  const VisualVerificationCardData({
    required this.status,
    this.identifiedMedicationName,
    this.category,
    this.message,
    this.expectedMedicationName,
    this.nextDoseTime,
    this.nextDoseInstruction,
    this.dosage,
    this.canConfirm = false,
    this.canAdd = false,
    this.existsInList = false,
  });

  final VisualVerificationStatus status;
  final String? identifiedMedicationName;
  final String? category;
  final String? message;
  final String? expectedMedicationName;
  final String? nextDoseTime;
  final String? nextDoseInstruction;
  final String? dosage;
  final bool canConfirm;
  final bool canAdd;
  final bool existsInList;

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
        if (dosage != null) 'dosage': dosage,
        'can_confirm': canConfirm,
        'can_add': canAdd,
        'exists_in_list': existsInList,
      };
}

/// Request to activate (or reconfigure) visual scanning mode.
class VisualModeRequest {
  const VisualModeRequest({
    this.reason,
    this.expectedMedicationId,
    this.expectedMedicationName,
    this.intent = VisualModeIntent.verify,
    this.autoCapture = true,
    this.autoCaptureDelayMs = 1000,
    this.prompt,
  });

  final String? reason;
  final String? expectedMedicationId;
  final String? expectedMedicationName;
  final VisualModeIntent intent;

  /// When true, the camera captures automatically after [autoCaptureDelayMs].
  final bool autoCapture;
  final int autoCaptureDelayMs;

  /// Extra instruction the visual-mode AI should follow for this session.
  final String? prompt;
}

/// Opens the camera / visual scanning viewfinder.
class StartVisualModeTool extends AiTool {
  StartVisualModeTool({this.onStartVisualMode});

  final Future<void> Function(VisualModeRequest request)? onStartVisualMode;

  @override
  String get name => 'start_visual_mode';

  @override
  String get description =>
      'Open the camera scanner. Use intent="verify" for "is this my medication?", '
      'intent="add_medication" when the user wants to add a package, '
      'intent="identify" for "what is this medicine?". '
      'Set auto_capture=true (default) so the app snaps a photo ~1s after opening. '
      'Pass prompt for any extra instructions. Prefer this over asking the user to open the camera themselves.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'intent': {
            'type': 'string',
            'enum': ['verify', 'add_medication', 'identify'],
            'description':
                'verify = check against schedule; add_medication = scan to add; identify = what is this.',
          },
          'reason': {
            'type': 'string',
            'description': 'Short reason, e.g. "User wants to add this package".',
          },
          'expected_medication_id': {
            'type': 'string',
            'description': 'Expected medication ID when verifying.',
          },
          'expected_medication_name': {
            'type': 'string',
            'description': 'Expected medication name when verifying.',
          },
          'auto_capture': {
            'type': 'boolean',
            'description':
                'If true (default), automatically take a photo shortly after opening.',
          },
          'auto_capture_delay_ms': {
            'type': 'integer',
            'description': 'Delay before auto-capture in ms (default 1000).',
          },
          'prompt': {
            'type': 'string',
            'description':
                'Extra context for the visual AI, e.g. "User is adding this med from voice".',
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
      intent: VisualModeIntent.fromString(arguments['intent'] as String?),
      autoCapture: arguments['auto_capture'] as bool? ?? true,
      autoCaptureDelayMs:
          (arguments['auto_capture_delay_ms'] as num?)?.toInt() ?? 1000,
      prompt: arguments['prompt'] as String?,
    );

    try {
      if (onStartVisualMode != null) {
        await onStartVisualMode!(request);
      }
      return ToolResult.ok({
        'visual_mode_active': true,
        'intent': request.intent.toApiString(),
        'auto_capture': request.autoCapture,
        'reason': request.reason ?? 'Visual inspection started',
        'expected_medication_name': request.expectedMedicationName,
        'message':
            'Visual mode opened. A photo will be captured${request.autoCapture ? ' automatically' : ' when the user taps'}.',
      });
    } catch (e) {
      return ToolResult.failure('Failed to enter visual mode: $e');
    }
  }
}

/// Displays the visual result card on the scanner sheet.
class ShowVisualVerificationResultTool extends AiTool {
  ShowVisualVerificationResultTool({this.onShowResult});

  final void Function(VisualVerificationCardData data)? onShowResult;

  @override
  String get name => 'show_visual_verification_result';

  @override
  String get description =>
      'Update the visual mode result card. Status values: '
      'confirmed_match / confirmed_mismatch / uncertain (verify flow); '
      'identified (show package info); '
      'not_in_list (package read but not in user meds — set can_add=true). '
      'Never guess if the label is unclear — use uncertain.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'enum': [
              'confirmed_match',
              'confirmed_mismatch',
              'uncertain',
              'identified',
              'not_in_list',
            ],
          },
          'identified_medication_name': {'type': 'string'},
          'category': {'type': 'string'},
          'dosage': {'type': 'string'},
          'message': {'type': 'string'},
          'expected_medication_name': {'type': 'string'},
          'next_dose_time': {'type': 'string'},
          'next_dose_instruction': {'type': 'string'},
          'can_confirm': {'type': 'boolean'},
          'can_add': {
            'type': 'boolean',
            'description': 'Show an Add medication button (not_in_list / identify).',
          },
          'exists_in_list': {
            'type': 'boolean',
            'description': 'Whether this med is already in the user list.',
          },
        },
        'required': ['status'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final status =
        VisualVerificationStatus.fromString(arguments['status'] as String?);

    final data = VisualVerificationCardData(
      status: status,
      identifiedMedicationName:
          arguments['identified_medication_name'] as String?,
      category: arguments['category'] as String?,
      dosage: arguments['dosage'] as String?,
      message: arguments['message'] as String?,
      expectedMedicationName: arguments['expected_medication_name'] as String?,
      nextDoseTime: arguments['next_dose_time'] as String?,
      nextDoseInstruction: arguments['next_dose_instruction'] as String?,
      canConfirm: (arguments['can_confirm'] as bool?) ??
          (status == VisualVerificationStatus.confirmedMatch),
      canAdd: (arguments['can_add'] as bool?) ??
          (status == VisualVerificationStatus.notInList),
      existsInList: (arguments['exists_in_list'] as bool?) ??
          (status == VisualVerificationStatus.confirmedMatch ||
              status == VisualVerificationStatus.identified),
    );

    try {
      onShowResult?.call(data);
      return ToolResult.ok({'displayed': true, ...data.toJson()});
    } catch (e) {
      return ToolResult.failure('Failed to show verification result: $e');
    }
  }
}

/// Ask the user a clarifying question and wait for their spoken/typed answer.
class AskUserTool extends AiTool {
  AskUserTool({this.onAskUser});

  /// Must resolve with the user's reply text.
  final Future<String> Function(String question)? onAskUser;

  @override
  String get name => 'ask_user';

  @override
  String get description =>
      'Ask the user ONE clarifying question and wait for their answer. '
      'Use when adding a medication and times/dosage are missing, or when visual mode needs more info. '
      'Do not invent missing schedule times — ask. Prefer this over guessing.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'question': {
            'type': 'string',
            'description': 'Short clear question to ask the user.',
          },
        },
        'required': ['question'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final question = (arguments['question'] as String?)?.trim();
    if (question == null || question.isEmpty) {
      return ToolResult.failure('Parameter "question" is required.');
    }

    try {
      if (onAskUser == null) {
        return ToolResult.ok({
          'asked': true,
          'question': question,
          'waiting_for_user': true,
          'message':
              'Question shown to user. Wait for their next message with the answer.',
        });
      }
      final answer = await onAskUser!(question);
      return ToolResult.ok({
        'asked': true,
        'question': question,
        'user_answer': answer,
        'message': 'User answered: $answer',
      });
    } catch (e) {
      return ToolResult.failure('Failed to ask user: $e');
    }
  }
}

/// Close the voice-mode screen (e.g. after "thanks" or after handing off to visual).
class CloseVoiceModeTool extends AiTool {
  CloseVoiceModeTool({this.onClose});

  final Future<void> Function()? onClose;

  @override
  String get name => 'close_voice_mode';

  @override
  String get description =>
      'Close / exit voice mode. Call after a polite goodbye ("you\'re welcome"), '
      'or when you have opened visual mode and no longer need the voice sheet. '
      'Do not call this mid-conversation when you still need the user\'s answer.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'reason': {
            'type': 'string',
            'description': 'Why voice mode is closing, e.g. "User said thanks".',
          },
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      await onClose?.call();
      return ToolResult.ok({
        'closed': true,
        'reason': arguments['reason'] ?? 'Voice mode closed',
      });
    } catch (e) {
      return ToolResult.failure('Failed to close voice mode: $e');
    }
  }
}

/// Trigger another photo capture while already in visual mode.
class CapturePhotoTool extends AiTool {
  CapturePhotoTool({this.onCapture});

  final Future<void> Function()? onCapture;

  @override
  String get name => 'capture_photo';

  @override
  String get description =>
      'While visual mode is open, take another photo of the package now. '
      'Use when the previous frame was blurry or the user repositioned the package.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'reason': {'type': 'string'},
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      await onCapture?.call();
      return ToolResult.ok({
        'capture_triggered': true,
        'reason': arguments['reason'] ?? 'Capture requested',
      });
    } catch (e) {
      return ToolResult.failure('Failed to capture photo: $e');
    }
  }
}
