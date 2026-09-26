import 'dart:async';

import 'models/chat_message.dart';
import 'openai_client.dart';
import 'tools/ai_tool.dart';
import 'tools/tool_registry.dart';
import 'tools/vision_tools.dart';

/// Events emitted during the AI assistant execution loop.
sealed class AiAssistantEvent {
  const AiAssistantEvent();
}

class AiThinkingEvent extends AiAssistantEvent {
  const AiThinkingEvent();
}

class AiToolCallStartedEvent extends AiAssistantEvent {
  const AiToolCallStartedEvent({
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });

  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;
}

class AiToolCallCompletedEvent extends AiAssistantEvent {
  const AiToolCallCompletedEvent({
    required this.toolCallId,
    required this.toolName,
    required this.result,
  });

  final String toolCallId;
  final String toolName;
  final ToolResult result;
}

class AiResponseCompletedEvent extends AiAssistantEvent {
  const AiResponseCompletedEvent({required this.message});

  final String message;
}

class AiErrorEvent extends AiAssistantEvent {
  const AiErrorEvent({required this.error});

  final String error;
}

/// Result of a completed assistant invocation.
class AiAssistantResult {
  const AiAssistantResult({
    required this.response,
    required this.updatedHistory,
    required this.executedTools,
  });

  final String response;
  final List<ChatMessage> updatedHistory;
  final List<String> executedTools;
}

/// High-level AI assistant coordinating DeepSeek chat completions with tools.
class AiAssistantService {
  AiAssistantService({
    required this.client,
    required this.tools,
    this.systemPromptProvider,
    this.maxToolIterations = 8,
  });

  final OpenAiCompatibleClient client;
  final AiToolRegistry tools;
  final String Function()? systemPromptProvider;
  final int maxToolIterations;

  static String defaultSystemPrompt({
    String? userName,
    DateTime? now,
    bool voiceMode = false,
    bool visualMode = false,
    VisualModeIntent? visualIntent,
  }) {
    final timeStr = (now ?? DateTime.now()).toIso8601String();
    final intentNote = visualIntent != null
        ? '- Active visual intent: ${visualIntent.toApiString()}\n'
        : '';

    final modeRules = StringBuffer();
    if (voiceMode) {
      modeRules.writeln('''
Voice Mode Rules (CRITICAL):
- ALWAYS reply with speak_to_user / speak (short, calm, 1–2 sentences).
- For clarifying questions prefer ask_user (waits for the answer).
- Camera handoff — call start_visual_mode with the CORRECT intent + auto_capture=true:
  • "is this my medication" / "check this" → intent="verify"
  • "add this medication" / "scan to add" → intent="add_medication"
  • "what is this" / "identify" → intent="identify"
- After starting visual mode for a scan, call close_voice_mode so the camera takes over.
- After goodbye / "thanks", speak briefly then close_voice_mode.
- Wrong intent causes false "not your medication" — never verify when the user wants to add.
''');
    }
    if (visualMode) {
      modeRules.writeln('''
Visual Mode Rules (CRITICAL):
$intentNote- ALWAYS call show_visual_verification_result after inspecting an image.
- Use ask_user when times/dosage are missing (especially add_medication). Do not invent times.
- Use speak_to_user for short spoken confirmations.
- Use capture_photo if you need another clearer frame.
- Intent behavior:
  • verify → confirmed_match / confirmed_mismatch / uncertain
  • add_medication → identified (or uncertain); ask_user; create_medication. NEVER confirmed_mismatch.
  • identify → identified + next dose if in list; not_in_list + can_add=true if unknown
''');
    }

    return '''
You are Certo — a calm, safety-first medication assistant.
Never invent medical advice. Prefer tools over guessing. Patient safety first.

Context:
- User name: ${userName ?? 'User'}
- Device date & time: $timeStr

Tools:
Schedule: get_next_medications, get_today_schedule, list_medications, get_medication_details, get_user_summary
Doses: mark_medication_taken, skip_medication, snooze_medication, get_last_dose, get_dose_history, read_instructions
CRUD: create_medication (name, dosage, ≥1 time), update_medication, delete_medication
Session: speak_to_user/speak, ask_user, close_voice_mode
Vision: start_visual_mode (intent + auto_capture + prompt), show_visual_verification_result, capture_photo

${modeRules.toString()}
Guidelines:
1. Schedule → get_next_medications / get_today_schedule first.
2. Instructions → read_instructions; speak stored text as-is.
3. History → get_last_dose / get_dose_history.
4. Verify → start_visual_mode(intent=verify, auto_capture=true) then close_voice_mode.
5. Add from package → start_visual_mode(intent=add_medication, auto_capture=true) then close_voice_mode.
6. "What is this?" → start_visual_mode(intent=identify, auto_capture=true) then close_voice_mode.
7. Goodbye → speak + close_voice_mode.
8. Tone: calm, brief, reassuring.
'''.trim();
  }

  static String addMedicationKickoffPrompt() => '''
The user opened Add Medication.
Greet briefly. Ask if they want to describe it or scan the package.
If scan: start_visual_mode(intent="add_medication", auto_capture=true) then close_voice_mode.
If describe: collect name, dosage, ≥1 time via ask_user, then create_medication.
'''.trim();

  static String visualAddMedicationPrompt({String? extra}) => '''
INTENT: add_medication (NOT verification).
Scan package to ADD it. Extract name, dosage, form, schedule hints.
If times missing → ask_user once. Then create_medication when ready.
show_visual_verification_result status="identified" (or "uncertain").
NEVER use confirmed_mismatch / "not your medication".
Speak a short summary.
${extra != null && extra.trim().isNotEmpty ? 'Extra: $extra' : ''}
'''.trim();

  static String visualIdentifyPrompt({String? extra}) => '''
INTENT: identify. What medicine is this?
Check list_medications / get_next_medications.
show_visual_verification_result: identified (with next_dose_time if in list),
not_in_list (can_add=true), or uncertain.
Speak a short summary.
${extra != null && extra.trim().isNotEmpty ? 'Extra: $extra' : ''}
'''.trim();

  static String visualVerificationPrompt({
    String? expectedMedicationName,
    String? extra,
  }) {
    final expected = expectedMedicationName != null &&
            expectedMedicationName.trim().isNotEmpty
        ? 'Expected scheduled medication: "$expectedMedicationName".'
        : 'Use get_next_medications for what is due now.';
    return '''
INTENT: verify.
$expected
show_visual_verification_result: confirmed_match / confirmed_mismatch / uncertain.
Speak a short confirmation. Never guess.
${extra != null && extra.trim().isNotEmpty ? 'Extra: $extra' : ''}
'''.trim();
  }

  Future<AiAssistantResult> sendMessage(
    dynamic userMessage, {
    List<ChatMessage>? history,
    void Function(AiAssistantEvent event)? onEvent,
  }) async {
    final conversation = <ChatMessage>[];

    final systemPrompt = systemPromptProvider != null
        ? systemPromptProvider!()
        : defaultSystemPrompt();
    conversation.add(ChatMessage.system(systemPrompt));

    if (history != null) {
      for (final msg in history) {
        if (msg.role != 'system') conversation.add(msg);
      }
    }

    if (userMessage is ChatMessage) {
      conversation.add(userMessage);
    } else {
      conversation.add(ChatMessage.user(userMessage.toString()));
    }

    onEvent?.call(const AiThinkingEvent());

    final openAiTools = tools.toOpenAiTools();
    final executedToolNames = <String>[];
    var iterations = 0;

    while (iterations < maxToolIterations) {
      iterations++;

      ChatCompletionResponse completion;
      try {
        completion = await client.chatCompletion(
          messages: conversation,
          tools: openAiTools.isNotEmpty ? openAiTools : null,
        );
      } catch (e) {
        final err = 'AI error: $e';
        onEvent?.call(AiErrorEvent(error: err));
        return AiAssistantResult(
          response: err,
          updatedHistory: conversation,
          executedTools: executedToolNames,
        );
      }

      final choice =
          completion.choices.isNotEmpty ? completion.choices.first : null;
      if (choice == null) {
        const err = 'Received empty response from AI model.';
        onEvent?.call(const AiErrorEvent(error: err));
        return AiAssistantResult(
          response: err,
          updatedHistory: conversation,
          executedTools: executedToolNames,
        );
      }

      final assistantMsg = choice.message;
      conversation.add(assistantMsg);

      if (assistantMsg.hasToolCalls) {
        for (final toolCall in assistantMsg.toolCalls!) {
          final toolName = toolCall.function.name;
          final args = toolCall.function.parsedArguments;
          executedToolNames.add(toolName);

          onEvent?.call(AiToolCallStartedEvent(
            toolCallId: toolCall.id,
            toolName: toolName,
            arguments: args,
          ));

          final result = await tools.execute(toolName, args);

          onEvent?.call(AiToolCallCompletedEvent(
            toolCallId: toolCall.id,
            toolName: toolName,
            result: result,
          ));

          conversation.add(ChatMessage.tool(
            toolCallId: toolCall.id,
            name: toolName,
            content: result.toOutputString(),
          ));
        }
        continue;
      }

      final finalContent = assistantMsg.content ?? '';
      onEvent?.call(AiResponseCompletedEvent(message: finalContent));
      return AiAssistantResult(
        response: finalContent,
        updatedHistory: conversation,
        executedTools: executedToolNames,
      );
    }

    const fallback = 'I completed the requested actions.';
    onEvent?.call(const AiResponseCompletedEvent(message: fallback));
    return AiAssistantResult(
      response: fallback,
      updatedHistory: conversation,
      executedTools: executedToolNames,
    );
  }

  Future<AiAssistantResult> verifyMedicationImage({
    required String imageBase64,
    String userPrompt = 'Is this my medication for now?',
    List<ChatMessage>? history,
    void Function(AiAssistantEvent event)? onEvent,
  }) {
    final msg = ChatMessage.userWithImage(userPrompt, imageBase64: imageBase64);
    return sendMessage(msg, history: history, onEvent: onEvent);
  }
}
