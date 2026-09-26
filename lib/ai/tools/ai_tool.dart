import 'dart:convert';

/// Result of executing an [AiTool].
class ToolResult {
  const ToolResult({
    required this.success,
    this.data,
    this.error,
  });

  factory ToolResult.ok([dynamic data]) => ToolResult(success: true, data: data);

  factory ToolResult.failure(String error, [dynamic data]) =>
      ToolResult(success: false, error: error, data: data);

  final bool success;
  final dynamic data;
  final String? error;

  Map<String, dynamic> toJson() => {
    'success': success,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
  };

  /// Output formatted for consumption by LLM in a tool message.
  String toOutputString() => jsonEncode(toJson());

  @override
  String toString() => toOutputString();
}

/// Base contract for an internal tool callable by AI or MCP clients.
///
/// Implements formats compatible with both:
/// 1. OpenAI Function Calling (`tools: [{ type: 'function', function: { ... } }]`)
/// 2. Model Context Protocol (MCP) tool schema (`{ name, description, inputSchema }`)
abstract class AiTool {
  const AiTool();

  /// Tool name matching `^[a-zA-Z0-9_-]{1,64}$`
  String get name;

  /// Clear, detailed instructions telling the LLM when and how to call this tool.
  String get description;

  /// JSON Schema describing the input arguments object.
  Map<String, dynamic> get parameters;

  /// Executes the tool given validated or raw arguments.
  Future<ToolResult> execute(Map<String, dynamic> arguments);

  /// Converts this tool into the OpenAI Chat Completion tool definition.
  Map<String, dynamic> toOpenAiTool() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }

  /// Converts this tool into the Model Context Protocol (MCP) tool specification.
  Map<String, dynamic> toMcpTool() {
    return {
      'name': name,
      'description': description,
      'inputSchema': parameters,
    };
  }
}
