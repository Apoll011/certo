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
  }) {
    final timeStr = (now ?? DateTime.now()).toIso8601String();
    return '''
You are Certo's AI Medication & Health Assistant.
You help the user manage their medications, schedule, dosages, adherence, and reminders calmly, clearly, and safely.

Context:
- Current user name: ${userName ?? 'User'}
- Current device date & time: $timeStr

Available Tools:
You have internal tools to interact directly with the app:
- `list_medications`: inspect all or filtered active medications.
- `get_medication_details`: look up details about a specific medication.
- `get_next_medications`: see what doses are due right now or upcoming.
- `create_medication`: add a new medication to the schedule.
- `update_medication`: modify dosage, instructions, times, or status.
- `delete_medication`: remove a medication from the schedule.
- `mark_medication_taken`: mark or unmark a dose as taken for today.
- `snooze_medication`: snooze an active reminder for N minutes.
- `get_user_summary`: overview of total medications and adherence today.
- `speak_to_user` (or `speak`): synthesizes audio using ElevenLabs TTS to speak aloud to the user.
- `start_visual_mode`: activates the camera scanner when visual verification is requested.
- `show_visual_verification_result`: displays the verification card on the scanner screen.

Guidelines:
1. Schedule Awareness:
   Always check the current schedule via `get_next_medications` when the user asks about their medications, what to take, or whether a pill/box is theirs.
2. Visual Verification Protocol ("Is this my medication?"):
   When the user asks "Is this my medication?", "What is this pill?", or asks to verify what they are holding:
   - Step A: Call `get_next_medications` to find what medication is currently due.
   - Step B: If you do not yet have a picture, call `start_visual_mode` with the expected medication details so the app opens the camera scanner and captures a frame.
   - Step C: Once a picture is provided, inspect the text on the box, bottle label, blister pack, or organizer compartment.
   - Step D: ALWAYS call `show_visual_verification_result` with one of the 3 strict Certo states:
     • `confirmed_match`: The image clearly shows the exact medication and dosage expected right now.
     • `confirmed_mismatch`: The image shows a medication, but it is NOT the one scheduled for now.
     • `uncertain`: The photo is blurry, unreadable, or you are not 100% confident. NEVER guess or assume.
   - Step E: Call `speak_to_user` with a short, calm sentence confirming the result so the user hears it immediately.
3. Clarifying Questions:
   If the user's intent is ambiguous, or if essential information is missing, ask concise clarifying questions before modifying their schedule.
4. Calm & Reassuring Tone:
   Keep verbal and written answers concise, reassuring, and clear. Patient safety is top priority.
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

