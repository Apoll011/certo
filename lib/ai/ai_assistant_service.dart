import 'dart:async';

import 'models/chat_message.dart';

import 'openai_client.dart';
import 'tools/ai_tool.dart';
import 'tools/tool_registry.dart';

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

  /// The final text response from the assistant.
  final String response;

  /// Full conversation history including tool calls and outputs.
  final List<ChatMessage> updatedHistory;

  /// List of tools executed during this turn.
  final List<String> executedTools;
}

/// High-level AI assistant coordinating OpenAI/DeepSeek chat completions with internal tools.
class AiAssistantService {
  AiAssistantService({
    required this.client,
    required this.tools,
    this.systemPromptProvider,
    this.maxToolIterations = 6,
  });

  final OpenAiCompatibleClient client;
  final AiToolRegistry tools;
  final String Function()? systemPromptProvider;
  final int maxToolIterations;

  /// Default system prompt template with full voice, vision, and medication safety rules.
  static String defaultSystemPrompt({
    String? userName,
    DateTime? now,
    bool voiceMode = false,
  }) {
    final timeStr = (now ?? DateTime.now()).toIso8601String();
    final voiceRules = voiceMode
        ? '''
Voice Mode Rules (CRITICAL):
- ALWAYS reply by calling `speak_to_user` (or `speak`) with a short, calm sentence the user can hear.
- Do not depend on on-screen text alone — the user is listening.
- Ask at most ONE clarifying question per turn via `speak_to_user`, then wait for their answer.
- Keep spoken replies to 1–2 short sentences. Prefer tools over guessing.
- When the user wants to scan/verify a package, call `start_visual_mode`.
'''
        : '';

    return '''
You are Certo — a calm, safety-first medication assistant.
Help the user manage medications, schedules, doses, adherence, and verification.
Never invent medical advice. Prefer stored instructions and schedule data from tools.
Patient safety first: when unsure, say so and ask a clarifying question.

Context:
- User name: ${userName ?? 'User'}
- Device date & time: $timeStr

Tools (always use these instead of guessing):
Schedule & status
- `get_next_medications` — what is due now / soon
- `get_today_schedule` — full schedule for today with taken/missed/upcoming
- `list_medications` / `get_medication_details` — inventory and details
- `get_user_summary` — quick adherence overview

Dose tracking
- `mark_medication_taken` — log a dose as taken today
- `skip_medication` — log that the user is skipping a dose
- `snooze_medication` — snooze a reminder
- `get_last_dose` — when was this medication last taken / last action
- `get_dose_history` — recent taken/skipped/mismatch/uncertain events
- `read_instructions` — read the saved instruction text exactly as stored

Medication CRUD
- `create_medication` — add a medication (needs name, dosage, at least one time)
- `update_medication` / `delete_medication` — change or remove

Voice & vision
- `speak_to_user` / `speak` — speak aloud (required in voice mode)
- `start_visual_mode` — open the camera scanner
- `show_visual_verification_result` — show match / mismatch / uncertain on the scanner

$voiceRules
Operating guidelines:
1. Schedule questions ("what do I take now/today?"):
   Call `get_next_medications` and/or `get_today_schedule` first, then answer clearly.
2. Instructions ("how do I take X?" / "read the instructions"):
   Call `read_instructions` and speak the stored text without rewriting medically relevant content.
3. Last dose / history ("did I take it?" / "when did I last take X?"):
   Call `get_last_dose` or `get_dose_history` before answering.
4. Visual verification ("is this my medication?"):
   A) `get_next_medications` for what is expected now
   B) If no photo yet → `start_visual_mode`
   C) Inspect the package image carefully
   D) ALWAYS `show_visual_verification_result` with exactly one of:
      • confirmed_match — clearly the expected medication/dose
      • confirmed_mismatch — a different medication
      • uncertain — blurry/unreadable/not confident (NEVER guess)
   E) `speak_to_user` with a short calm confirmation
5. Adding medications (voice or from a package photo):
   Gather name, dosage, and ≥1 schedule time. Ask for anything essential that is missing.
   Then `create_medication` and confirm. Do not invent times — ask.
6. Marking taken / skip / snooze: use the matching tool, then confirm briefly.
7. Tone: calm, brief, reassuring. Never shame the user about missed doses.
'''.trim();
  }

  /// Kickoff prompt used when the user opens Add Medication via AI/voice.
  static String addMedicationKickoffPrompt() => '''
The user opened Add Medication. Help them add a new medication.
If they have not given details yet, greet briefly and ask what medication they want to add.
Collect name, dosage, and at least one time. Ask for missing essentials with speak_to_user.
When you have enough, call create_medication and confirm aloud.
If they want to scan a package instead, call start_visual_mode.
'''.trim();

  /// Prompt when scanning a package specifically to ADD it (not verify against schedule).
  static String visualAddMedicationPrompt() => '''
The user is scanning a medication package to ADD it to their list (not verify a due dose).
Inspect the image and extract whatever you can: name, strength/dosage, form, and any schedule hints on the label.
If name + dosage are clear but schedule times are missing, ask ONE question via speak_to_user for when they take it.
When you have name, dosage, and at least one time, call create_medication.
Also call show_visual_verification_result:
- confirmed_match if you confidently read the package (use identified_medication_name / category / message about adding it)
- uncertain if the label is unreadable
Never invent a schedule time — ask if needed.
Speak a short calm summary of what you found.
'''.trim();

  /// Prompt used when analyzing a captured medication photo for verification.
  static String visualVerificationPrompt({
    String? expectedMedicationName,
  }) {
    final expected = expectedMedicationName != null &&
            expectedMedicationName.trim().isNotEmpty
        ? 'The currently expected / scheduled medication is: "$expectedMedicationName".'
        : 'Check get_next_medications to learn what is due now.';
    return '''
The user just captured this photo of a medication package / pill / organizer for VERIFICATION.
$expected
Inspect the image carefully. Then ALWAYS call show_visual_verification_result with confirmed_match, confirmed_mismatch, or uncertain.
Also call speak_to_user with a short calm confirmation of the result.
Never guess if the label is unclear.
'''.trim();
  }

  /// Sends a message (either a [String] or a [ChatMessage], including multimodal messages with images)
  /// and executes any required tool calls in an autonomous loop.
  Future<AiAssistantResult> sendMessage(
    dynamic userMessage, {
    List<ChatMessage>? history,
    void Function(AiAssistantEvent event)? onEvent,
  }) async {
    final conversation = <ChatMessage>[];

    // 1. System prompt
    final systemPrompt = systemPromptProvider != null
        ? systemPromptProvider!()
        : defaultSystemPrompt();
    conversation.add(ChatMessage.system(systemPrompt));

    // 2. Past history (exclude previous system prompts to avoid duplication)
    if (history != null) {
      for (final msg in history) {
        if (msg.role != 'system') {
          conversation.add(msg);
        }
      }
    }

    // 3. User message (support plain String or ChatMessage)
    if (userMessage is ChatMessage) {
      conversation.add(userMessage);
    } else {
      conversation.add(ChatMessage.user(userMessage.toString()));
    }


    onEvent?.call(const AiThinkingEvent());

    final openAiTools = tools.toOpenAiTools();
    final executedToolNames = <String>[];
    int iterations = 0;

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

      final choice = completion.choices.isNotEmpty ? completion.choices.first : null;
      if (choice == null) {
        final err = 'Received empty response from AI model.';
        onEvent?.call(AiErrorEvent(error: err));
        return AiAssistantResult(
          response: err,
          updatedHistory: conversation,
          executedTools: executedToolNames,
        );
      }

      final assistantMsg = choice.message;
      conversation.add(assistantMsg);

      // Check if tool calls were requested
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

        // Loop again so LLM processes tool outputs
        continue;
      }

      // No tool calls — final textual answer
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

  /// Convenience helper to verify a medication photo against the user's schedule.
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

