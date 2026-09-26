/// Build-time configuration, injected via `--dart-define`.
///
/// Only the Supabase URL and the **anon/publishable** key belong here. They are
/// safe to ship in the client by design (RLS enforces access). Never put the
/// service-role key, database password, or any private secret in this file.
///
/// Usage:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}
