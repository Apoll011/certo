import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Thin wrapper around the Supabase client: one-time init + convenient access.
///
/// The app never talks to Supabase when [isConfigured] is false (no URL/key
/// provided), so the UI shell still runs as an offline demo.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured =>
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!isConfigured) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
