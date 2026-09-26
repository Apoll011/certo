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

  /// Voice ID for TTS. Defaults to "Rachel" (a natural, warm voice).
  /// Override via --dart-define=ELEVENLABS_VOICE_ID=...
  static const String elevenLabsVoiceId = String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: 'wWWn96OtTHu1sn8SRGEr', // Jessica — conversational
  );

  /// ElevenLabs TTS model: "eleven_v3" = Conversacional v3.
  static const String elevenLabsTtsModel = 'eleven_v3';

  /// ElevenLabs STT model: Scribe v2 Realtime.
  static const String elevenLabsSttModel = 'scribe_v2_realtime';
}
