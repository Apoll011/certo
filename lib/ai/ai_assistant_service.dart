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

  /// Default system prompt template.
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

Guidelines:
1. Always check the current schedule or run tools when the user asks about their medications, doses, or what to take.
2. When creating or editing medications, confirm the details (name, dosage, times) clearly with the user.
3. Be reassuring, concise, and helpful. Prioritize safety and clarity above all else. Never invent or hallucinate medication instructions.
'''.trim();
  }

  /// Sends a message and executes any required tool calls in an autonomous loop.
  Future<AiAssistantResult> sendMessage(
    String userMessage, {
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

    // 3. User message
    conversation.add(ChatMessage.user(userMessage));

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
}
