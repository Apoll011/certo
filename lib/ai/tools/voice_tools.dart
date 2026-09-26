import 'ai_tool.dart';

/// Internal tool enabling the AI to speak directly to the user via ElevenLabs TTS.
class SpeakTool extends AiTool {
  SpeakTool({this.onSpeak, String? toolName})
      : _toolName = toolName ?? 'speak_to_user';

  final Future<void> Function(String text)? onSpeak;
  final String _toolName;

  @override
  String get name => _toolName;

  @override
  String get description =>
      'Speak text back to the user out loud using ElevenLabs text-to-speech audio synthesis. Call this tool when operating in voice mode or when the user asks you to speak.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'text': {
        'type': 'string',
        'description': 'The exact message or spoken reply to read aloud to the user.',
      },
    },
    'required': ['text'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final text = (arguments['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      return ToolResult.failure('Parameter "text" is required for speaking.');
    }

    try {
      if (onSpeak != null) {
        await onSpeak!(text);
      }
      return ToolResult.ok({
        'spoken': true,
        'text': text,
        'message': 'Voice audio generated and delivered to user.',
      });
    } catch (e) {
      return ToolResult.failure('Failed to speak text: $e');
    }
  }
}
