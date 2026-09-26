import 'dart:convert';

/// A function call inside a [ToolCall].
class FunctionCall {
  const FunctionCall({
    required this.name,
    required this.arguments,
  });

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '{}',
    );
  }

  final String name;

  /// Raw JSON string representing the arguments.
  final String arguments;

  /// Parsed arguments map, or empty map if invalid JSON.
  Map<String, dynamic> get parsedArguments {
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const {};
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'arguments': arguments,
  };
}

/// A tool call emitted by an LLM assistant response.
class ToolCall {
  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'function',
      function: FunctionCall.fromJson(
        Map<String, dynamic>.from(json['function'] as Map? ?? {}),
      ),
    );
  }

  final String id;
  final String type;
  final FunctionCall function;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'function': function.toJson(),
  };
}

/// Chat message compliant with OpenAI / DeepSeek API specification.
class ChatMessage {
  const ChatMessage({
    required this.role,
    this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  factory ChatMessage.system(String content) =>
      ChatMessage(role: 'system', content: content);

  factory ChatMessage.user(String content) =>
      ChatMessage(role: 'user', content: content);

  /// Creates a multimodal user message containing text and a base64 encoded image.
  factory ChatMessage.userWithImage(
    String text, {
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) {
    final cleanBase64 = imageBase64.contains(',')
        ? imageBase64.split(',').last
        : imageBase64;
    return ChatMessage(
      role: 'user',
      content: [
        {'type': 'text', 'text': text},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mimeType;base64,$cleanBase64',
          },
        },
      ],
    );
  }

  /// Creates a multimodal user message containing text and an image URL.
  factory ChatMessage.userWithImageUrl(
    String text, {
    required String imageUrl,
  }) {
    return ChatMessage(
      role: 'user',
      content: [
        {'type': 'text', 'text': text},
        {
          'type': 'image_url',
          'image_url': {'url': imageUrl},
        },
      ],
    );
  }

  factory ChatMessage.assistant(
    String? content, {
    List<ToolCall>? toolCalls,
  }) => ChatMessage(
    role: 'assistant',
    content: content,
    toolCalls: toolCalls,
  );

  factory ChatMessage.tool({
    required String toolCallId,
    required String content,
    String? name,
  }) => ChatMessage(
    role: 'tool',
    toolCallId: toolCallId,
    content: content,
    name: name,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final toolCallsRaw = json['tool_calls'];
    List<ToolCall>? toolCalls;
    if (toolCallsRaw is List) {
      toolCalls = toolCallsRaw
          .map((tc) => ToolCall.fromJson(Map<String, dynamic>.from(tc as Map)))
          .toList();
    }

    return ChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'],
      name: json['name'] as String?,
      toolCallId: json['tool_call_id'] as String?,
      toolCalls: toolCalls,
    );
  }

  final String role; // 'system', 'user', 'assistant', 'tool'

  /// Either [String] or [List<Map<String, dynamic>>] for multimodal content.
  final dynamic content;
  final String? name;
  final String? toolCallId;
  final List<ToolCall>? toolCalls;

  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  /// Returns the text content extracted from either plain string or multimodal parts.
  String get textContent {
    if (content is String) return content as String;
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content as List) {
        if (item is Map && item['type'] == 'text') {
          buffer.write(item['text']?.toString() ?? '');
        }
      }
      return buffer.toString();
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'role': role,
    };
    if (content != null) map['content'] = content;
    if (name != null) map['name'] = name;
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls!.map((tc) => tc.toJson()).toList();
    }
    return map;
  }
}


/// Token usage metadata.
class UsageInfo {
  const UsageInfo({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

/// A choice in [ChatCompletionResponse].
class ChatChoice {
  const ChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  factory ChatChoice.fromJson(Map<String, dynamic> json) {
    return ChatChoice(
      index: (json['index'] as num?)?.toInt() ?? 0,
      message: ChatMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map? ?? {}),
      ),
      finishReason: json['finish_reason'] as String?,
    );
  }

  final int index;
  final ChatMessage message;
  final String? finishReason;
}

/// Response returned by the OpenAI / DeepSeek `/chat/completions` endpoint.
class ChatCompletionResponse {
  const ChatCompletionResponse({
    required this.id,
    required this.choices,
    this.created,
    this.model,
    this.usage,
  });

  factory ChatCompletionResponse.fromJson(Map<String, dynamic> json) {
    final choicesRaw = json['choices'] as List? ?? const [];
    final choices = choicesRaw
        .map((c) => ChatChoice.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();

    return ChatCompletionResponse(
      id: json['id'] as String? ?? '',
      choices: choices,
      created: (json['created'] as num?)?.toInt(),
      model: json['model'] as String?,
      usage: json['usage'] != null
          ? UsageInfo.fromJson(
              Map<String, dynamic>.from(json['usage'] as Map),
            )
          : null,
    );
  }

  final String id;
  final List<ChatChoice> choices;
  final int? created;
  final String? model;
  final UsageInfo? usage;

  ChatMessage? get firstMessage =>
      choices.isNotEmpty ? choices.first.message : null;
}
