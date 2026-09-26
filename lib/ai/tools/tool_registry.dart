import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../state/app_state.dart';
import 'ai_tool.dart';
import 'medication_tools.dart';

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
    ]);
    return registry;
  }

  /// Register a single tool.
  void register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  /// Register multiple tools.
  void registerAll(Iterable<AiTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// Unregister a tool by name.
  bool unregister(String name) {
    return _tools.remove(name) != null;
  }

  /// Look up a registered tool by name.
  AiTool? getTool(String name) => _tools[name];

  /// All registered tool names.
  List<String> get toolNames => _tools.keys.toList();

  /// Converts all registered tools into OpenAI Chat Completion `tools` array.
  List<Map<String, dynamic>> toOpenAiTools() {
    return _tools.values.map((t) => t.toOpenAiTool()).toList();
  }

  /// Converts all registered tools into MCP (Model Context Protocol) tool specs.
  List<Map<String, dynamic>> toMcpTools() {
    return _tools.values.map((t) => t.toMcpTool()).toList();
  }

  /// Dispatches execution of a tool by name.
  ///
  /// [arguments] can be either a JSON string (as returned by OpenAI tool_calls)
  /// or a `Map<String, dynamic>`.
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
      debugPrint('AiToolRegistry: Tool "$name" completed with success: ${result.success}');
      return result;
    } catch (e, st) {
      debugPrint('AiToolRegistry: Tool "$name" threw exception: $e\n$st');
      return ToolResult.failure('Error executing tool "$name": $e');
    }
  }
}
