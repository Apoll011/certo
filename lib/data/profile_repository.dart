import 'package:supabase_flutter/supabase_flutter.dart';

/// Data-access layer for the `profiles` table.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;
  static const String _table = 'profiles';

  Future<String?> fetchName(String userId) async {
    final data = await _client
        .from(_table)
        .select('name')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return data['name'] as String?;
  }

  Future<void> updateName(String userId, String name) async {
    await _client.from(_table).update({'name': name}).eq('id', userId);
  }
}
