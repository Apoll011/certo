import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../state/app_state.dart';
import 'ai_tool.dart';
import 'caregiver_tools.dart';
import 'medication_tools.dart';
import 'ui_tools.dart';
import 'vision_tools.dart';
import 'voice_tools.dart';

/// Central registry and dispatcher for internal AI and MCP tools.
class AiToolRegistry {
  AiToolRegistry();

  final Map<String, AiTool> _tools = {};

  /// Creates a registry pre-loaded with all standard medication tools for [state].
  factory AiToolRegistry.withMedicationTools(
    AppState state, {
    DateTime Function()? clock,
  }) {
    final registry = AiToolRegistry();
    registry.registerAll([
      ListMedicationsTool(state),
      GetMedicationDetailsTool(state),
      GetNextMedicationsTool(state, clock: clock),
      CreateMedicationTool(state),
      UpdateMedicationTool(state),
      DeleteMedicationTool(state),
      MarkMedicationTakenTool(state),
      SnoozeMedicationTool(state),
      GetUserSummaryTool(state),
      GetLastDoseTool(state),
      GetDoseHistoryTool(state),
      SkipMedicationTool(state),
      ReadInstructionsTool(state),
      GetTodayScheduleTool(state, clock: clock),
      ListCareRecipientsTool(state),
      GetCareAdherenceTool(state),
      CreateCaregiverInviteTool(state),
      RedeemCaregiverInviteTool(state),
    ]);
    return registry;
  }

  /// Creates a complete registry with medication, voice, visual, and UI tools.
  factory AiToolRegistry.withAllTools(
    AppState state, {
    DateTime Function()? clock,
    Future<void> Function(String text)? onSpeak,
    Future<void> Function(VisualModeRequest request)? onStartVisualMode,
    void Function(VisualVerificationCardData data)? onShowVisualResult,
    Future<String> Function(String question)? onAskUser,
    Future<void> Function()? onCloseVoiceMode,
    Future<void> Function()? onCapturePhoto,
    void Function(ChatUiAttachment attachment)? onShowUi,
  }) {
    final registry = AiToolRegistry.withMedicationTools(state, clock: clock);
    registry.registerVoiceTools(onSpeak: onSpeak);
    registry.registerVisionTools(
      onStartVisualMode: onStartVisualMode,
      onShowResult: onShowVisualResult,
      onAskUser: onAskUser,
      onCloseVoiceMode: onCloseVoiceMode,
      onCapturePhoto: onCapturePhoto,
    );
    registry.registerUiTools(state, onShowUi: onShowUi);
    return registry;
  }

  /// Registers TTS voice tools (both `speak_to_user` and alias `speak`).
  void registerVoiceTools({Future<void> Function(String text)? onSpeak}) {
    register(SpeakTool(onSpeak: onSpeak, toolName: 'speak_to_user'));
    register(SpeakTool(onSpeak: onSpeak, toolName: 'speak'));
  }

  /// Registers camera / session tools.
  void registerVisionTools({
    Future<void> Function(VisualModeRequest request)? onStartVisualMode,
    void Function(VisualVerificationCardData data)? onShowResult,
    Future<String> Function(String question)? onAskUser,
    Future<void> Function()? onCloseVoiceMode,
    Future<void> Function()? onCapturePhoto,
  }) {
    register(StartVisualModeTool(onStartVisualMode: onStartVisualMode));
    register(ShowVisualVerificationResultTool(onShowResult: onShowResult));
    register(AskUserTool(onAskUser: onAskUser));
    register(CloseVoiceModeTool(onClose: onCloseVoiceMode));
    register(CapturePhotoTool(onCapture: onCapturePhoto));
  }

  /// Registers rich chat UI tools (medication cards, lists, dose status).
  void registerUiTools(
    AppState state, {
    void Function(ChatUiAttachment attachment)? onShowUi,
  }) {
    register(ShowMedicationTool(state, onShowUi: onShowUi));
    register(ShowMedicationsTool(state, onShowUi: onShowUi));
    register(ShowDoseStatusTool(state, onShowUi: onShowUi));
  }

  void register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(Iterable<AiTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  bool unregister(String name) {
    return _tools.remove(name) != null;
  }

  AiTool? getTool(String name) => _tools[name];

  List<String> get toolNames => _tools.keys.toList();

  List<Map<String, dynamic>> toOpenAiTools() {
    return _tools.values.map((t) => t.toOpenAiTool()).toList();
  }

  List<Map<String, dynamic>> toMcpTools() {
    return _tools.values.map((t) => t.toMcpTool()).toList();
  }

  Future<ToolResult> execute(String name, dynamic arguments) async {
    final tool = _tools[name];
    if (tool == null) {
      debugPrint('AiToolRegistry: Unknown tool requested: "$name"');
      return ToolResult.failure('Tool "$name" is not registered.');
    }

    Map<String, dynamic> parsedArgs = {};
    if (arguments is Map) {
      parsedArgs = Map<String, dynamic>.from(arguments);
    } else if (arguments is String) {
      final trimmed = arguments.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            parsedArgs = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('AiToolRegistry: Failed to parse arguments JSON: $e');
          return ToolResult.failure(
            'Invalid JSON arguments for tool "$name": $e',
          );
        }
      }
    }

    try {
      debugPrint('AiToolRegistry: Executing tool "$name" with args: $parsedArgs');
      final result = await tool.execute(parsedArgs);
      debugPrint(
        'AiToolRegistry: Tool "$name" completed with success: ${result.success}',
      );
      return result;
    } catch (e, st) {
      debugPrint('AiToolRegistry: Tool "$name" threw exception: $e\n$st');
      return ToolResult.failure('Error executing tool "$name": $e');
    }
  }
}
