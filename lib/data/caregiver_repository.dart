import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/caregiver.dart';
import '../models/dose_log_entry.dart';
import '../models/medication.dart';
import '../utils/adherence.dart';

/// Data-access for caregiver links + cross-user adherence reads.
class CaregiverRepository {
  CaregiverRepository(this._client);

  final SupabaseClient _client;
  static const _links = 'caregiver_links';
  static const _profiles = 'profiles';
  static const _meds = 'medications';
  static const _doses = 'dose_events';

  String? get _uid => _client.auth.currentUser?.id;

  /// Generate a short uppercase invite code (e.g. VER-7K2P).
  static String generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final body = List.generate(
      4,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return 'VER-$body';
  }

  // ── Patient side ──────────────────────────────────────────────────────────

  /// Patient creates a pending invite the caregiver can redeem.
  Future<CaregiverLink> createInvite() async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    // Reuse an unused pending invite if one already exists.
    final existing = await _client
        .from(_links)
        .select()
        .eq('patient_id', uid)
        .eq('status', 'pending')
        .filter('caregiver_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return CaregiverLink.fromJson(Map<String, dynamic>.from(existing));
    }

    var code = generateInviteCode();
    for (var i = 0; i < 5; i++) {
      try {
        final row = await _client
            .from(_links)
            .insert({
              'patient_id': uid,
              'invite_code': code,
              'status': 'pending',
            })
            .select()
            .single();
        return CaregiverLink.fromJson(Map<String, dynamic>.from(row));
      } catch (_) {
        code = generateInviteCode();
      }
    }
    throw StateError('Could not create invite code');
  }

  /// Links where I am the patient (people who can see me / pending invites).
  Future<List<CaregiverLink>> fetchMyGrantedLinks() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from(_links)
        .select()
        .eq('patient_id', uid)
        .order('created_at', ascending: false);
    final list = <CaregiverLink>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final caregiverId = map['caregiver_id']?.toString();
      if (caregiverId != null && caregiverId.isNotEmpty) {
        map['caregiver_name'] = await _fetchProfileName(caregiverId) ?? '';
      }
      list.add(CaregiverLink.fromJson(map));
    }
    return list;
  }

  Future<void> revokeLink(String linkId) async {
    await _client.from(_links).update({
      'status': 'revoked',
      'revoked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', linkId);
  }

  // ── Caregiver side ────────────────────────────────────────────────────────

  /// Redeem a patient's invite code.
  Future<CaregiverLink> redeemInvite({
    required String code,
    String label = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Invite code is required');
    }

    final row = await _client
        .from(_links)
        .select()
        .eq('invite_code', normalized)
        .eq('status', 'pending')
        .filter('caregiver_id', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Invite code not found or already used');
    }
    final map = Map<String, dynamic>.from(row);
    if (map['patient_id']?.toString() == uid) {
      throw StateError('You cannot redeem your own invite');
    }

    final updated = await _client
        .from(_links)
        .update({
          'caregiver_id': uid,
          'status': 'active',
          'consented_at': DateTime.now().toUtc().toIso8601String(),
          if (label.trim().isNotEmpty) 'label': label.trim(),
        })
        .eq('id', map['id'])
        .select()
        .single();

    final out = Map<String, dynamic>.from(updated);
    out['patient_name'] =
        await _fetchProfileName(out['patient_id']?.toString() ?? '') ?? '';
    return CaregiverLink.fromJson(out);
  }

  /// People I care for (active links where I am the caregiver).
  Future<List<CaregiverLink>> fetchMyCareRecipients() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from(_links)
        .select()
        .eq('caregiver_id', uid)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    final list = <CaregiverLink>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      map['patient_name'] =
          await _fetchProfileName(map['patient_id']?.toString() ?? '') ?? '';
      list.add(CaregiverLink.fromJson(map));
    }
    return list;
  }

  Future<void> updateRecipientLabel(String linkId, String label) async {
    await _client
        .from(_links)
        .update({'label': label.trim()})
        .eq('id', linkId);
  }

  Future<List<Medication>> fetchPatientMedications(String patientId) async {
    final data = await _client
        .from(_meds)
        .select()
        .eq('user_id', patientId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Medication.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<DoseLogEntry>> fetchPatientDoseEvents(
    String patientId, {
    int days = 35,
  }) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();
    final rows = await _client
        .from(_doses)
        .select('id, medication_id, action, created_at')
        .eq('user_id', patientId)
        .gte('created_at', since)
        .order('created_at', ascending: false);
    final list = <DoseLogEntry>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      list.add(
        DoseLogEntry(
          id: map['id']?.toString(),
          medicationId: map['medication_id']?.toString() ?? '',
          medicationName: map['medication_id']?.toString() ?? '',
          action: map['action']?.toString() ?? 'taken',
          at: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }
    return list;
  }

  /// Log a dose event on behalf of a consenting patient.
  Future<void> recordDoseForPatient({
    required String patientId,
    required String medicationId,
    required String action,
  }) async {
    await _client.from(_doses).insert({
      'user_id': patientId,
      'medication_id': medicationId,
      'action': action,
    });
  }

  Future<String?> _fetchProfileName(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final row = await _client
          .from(_profiles)
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Build a heatmap + today summary for one patient.
  Future<CareRecipientSnapshot> loadRecipientSnapshot(
    CaregiverLink link, {
    int heatmapDays = 28,
  }) async {
    final meds = await fetchPatientMedications(link.patientId);
    final events = await fetchPatientDoseEvents(
      link.patientId,
      days: heatmapDays + 2,
    );
    // Enrich names on events.
    final byId = {for (final m in meds) m.id: m};
    final enriched = events
        .map(
          (e) => DoseLogEntry(
            id: e.id,
            medicationId: e.medicationId,
            medicationName: byId[e.medicationId]?.name ?? e.medicationName,
            action: e.action,
            at: e.at,
          ),
        )
        .toList();

    final heatmap = buildAdherenceHeatmap(
      medications: meds,
      events: enriched,
      days: heatmapDays,
    );
    final today = DateTime.now();
    final todayKey = adherenceDayKey(today);
    final todayCell = heatmap.cast<AdherenceDay?>().firstWhere(
          (d) => d != null && adherenceDayKey(d.date) == todayKey,
          orElse: () => null,
        ) ??
        AdherenceDay(date: today, tone: AdherenceDayTone.none);

    // Latest action wins — a later skip must clear "taken".
    final takenToday = takenMedIdsForDay(enriched, today);

    return CareRecipientSnapshot(
      link: link.copyWith(patientName: link.patientName),
      medications: meds,
      heatmap: heatmap,
      takenTodayIds: takenToday,
      todayTone: todayCell.tone,
    );
  }
}
