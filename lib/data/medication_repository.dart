import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medication.dart';

/// Data-access layer for the `medications` table.
///
/// Row Level Security already restricts every query to the caller's own rows;
/// [create] additionally stamps `user_id` from the authenticated session.
class MedicationRepository {
  MedicationRepository(this._client);

  final SupabaseClient _client;
  static const String _table = 'medications';

  Future<List<Medication>> fetchAll() async {
    final data = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map(
          (row) => Medication.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<Medication?> fetchById(String id) async {
    final data = await _client.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Medication.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Medication> create(Medication m) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot create a medication without a session.');
    }
    final data = await _client
        .from(_table)
        .insert({...m.toDbJson(), 'user_id': uid})
        .select()
        .single();
    return Medication.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Medication> update(Medication m) async {
    final data = await _client
        .from(_table)
        .update(m.toDbJson())
        .eq('id', m.id)
        .select()
        .single();
    return Medication.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
