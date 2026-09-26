/// Build-time configuration, injected via `--dart-define`.
///
/// Only the Supabase URL and the **anon/publishable** key belong here. They are
/// safe to ship in the client by design (RLS enforces access). Never put the
/// service-role key, database password, or any private secret in this file.
///
/// Usage:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ... \
///               --dart-define=ELEVENLABS_API_KEY=sk_...
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  // ── ElevenLabs ────────────────────────────────────────────────────────────
  /// ElevenLabs API key (publishable). Pass via --dart-define=ELEVENLABS_API_KEY=...
  static const String elevenLabsApiKey = String.fromEnvironment(
    'ELEVENLABS_API_KEY',
  );

  /// Voice ID for TTS. Defaults to "Rachel" (21m00Tcm4TlvDq8ikWAM) - ElevenLabs' premier natural English voice.
  /// Override via --dart-define=ELEVENLABS_VOICE_ID=...
  static const String elevenLabsVoiceId = String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: '21m00Tcm4TlvDq8ikWAM', // Rachel — premier natural English voice
  );

  /// ElevenLabs TTS model: "eleven_flash_v2_5" (~75ms latency for conversational voice)
  /// Override via --dart-define=ELEVENLABS_TTS_MODEL=...
  static const String elevenLabsTtsModel = String.fromEnvironment(
    'ELEVENLABS_TTS_MODEL',
    defaultValue: 'eleven_flash_v2_5',
  );

  /// ElevenLabs STT model: Scribe v2 Realtime.
  static const String elevenLabsSttModel = 'scribe_v2_realtime';

  // ── AI Assistant (OpenAI / DeepSeek compatible) ───────────────────────────
  /// AI API key (e.g. DeepSeek or OpenAI). Pass via --dart-define=AI_API_KEY=...
  static const String aiApiKey = String.fromEnvironment('AI_API_KEY');

  /// AI API base URL. Defaults to DeepSeek endpoint 'https://api.deepseek.com'.
  /// Override via --dart-define=AI_BASE_URL=...
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://api.deepseek.com',
  );

  /// AI Model name. Defaults to 'deepseek-flash' (multimodal + tools).
  /// Override via --dart-define=AI_MODEL=...
  static const String aiModel = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'deepseek-flash',
  );

  /// Whether the DeepSeek / AI API key is configured.
  static bool get hasAiApiKey => aiApiKey.isNotEmpty;
}

