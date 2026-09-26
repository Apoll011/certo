import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/medication_repository.dart';
import '../data/mock_data.dart';
import '../data/profile_repository.dart';
import '../models/dose_log_entry.dart';
import '../models/medication.dart';
import '../config/app_config.dart';
import '../ai/ai.dart';
import '../services/alarm_service.dart';
import '../services/supabase_service.dart';


enum AuthStatus { loading, signedOut, signedIn }

const String _kLocalePref = 'locale_override';
const String _kNamePref = 'user_name';
const String _kAlarmSoundPref = 'alarm_sound_uri';

/// Holds the app's working state: auth session, medications, taken set, tab.
///
/// When Supabase is configured and a user is signed in, data is loaded from the
/// Supabase Data API. When it is not configured (or signed out), the UI falls
/// back to mock data so the shell still runs as a demo.
class AppState extends ChangeNotifier {
  AppState()
    : medications = List.of(mockMedications),
      // Skip the loading splash when there is no backend to talk to.
      authStatus = SupabaseService.isConfigured
          ? AuthStatus.loading
          : AuthStatus.signedOut;

  final List<Medication> medications;

  /// Medication ids marked as taken for today.
  final Set<String> takenIds = {};

  /// In-session dose history (newest first). Backed by Supabase when signed in.
  final List<DoseLogEntry> doseHistory = [];

  /// Medication ids snoozed until a given time (in-app, mirroring the OS alarm).
  final Map<String, DateTime> _snoozedUntil = {};

  String userName = demoUserName;
  int selectedTabIndex = 0;

  AuthStatus authStatus;
  User? _user;

  User? get user => _user;
  String? get userEmail => _user?.email;
  bool get isAuthenticated => _user != null;

  /// Overrides the system locale; null means "follow the device".
  Locale? _localeOverride;
  Locale? get localeOverride => _localeOverride;

  /// The user-selected alarm ringtone URI, or null to use the device default.
  String? _alarmSoundUri;
  String? get alarmSoundUri => _alarmSoundUri;

  SharedPreferences? _prefs;

  StreamSubscription<AuthState>? _authSub;
  MedicationRepository? _medsRepo;
  ProfileRepository? _profileRepo;
  bool _bootstrapped = false;
  AiToolRegistry? _aiToolRegistry;

  /// Internal MCP & OpenAI Tool Registry providing access to all medication tools.
  AiToolRegistry get aiToolRegistry {
    return _aiToolRegistry ??= AiToolRegistry.withMedicationTools(this);
  }

  /// Factory to instantiate an OpenAI / DeepSeek compatible assistant service.
  AiAssistantService createAiAssistant({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? systemPrompt,
    Future<void> Function(String text)? onSpeak,
    Future<void> Function(VisualModeRequest request)? onStartVisualMode,
    void Function(VisualVerificationCardData data)? onShowVisualResult,
    Future<String> Function(String question)? onAskUser,
    Future<void> Function()? onCloseVoiceMode,
    Future<void> Function()? onCapturePhoto,
    void Function(ChatUiAttachment attachment)? onShowUi,
  }) {
    final registry = AiToolRegistry.withAllTools(
      this,
      onSpeak: onSpeak,
      onStartVisualMode: onStartVisualMode,
      onShowVisualResult: onShowVisualResult,
      onAskUser: onAskUser,
      onCloseVoiceMode: onCloseVoiceMode,
      onCapturePhoto: onCapturePhoto,
      onShowUi: onShowUi,
    );
    final client = OpenAiCompatibleClient(
      apiKey: apiKey ?? AppConfig.aiApiKey,
      baseUrl: (baseUrl != null && baseUrl.isNotEmpty)
          ? baseUrl
          : AppConfig.aiBaseUrl,
      model: (model != null && model.isNotEmpty) ? model : AppConfig.aiModel,
    );
    return AiAssistantService(
      client: client,
      tools: registry,
      systemPromptProvider: () =>
          systemPrompt ??
          AiAssistantService.defaultSystemPrompt(
            userName: userName,
            now: DateTime.now(),
          ),
    );
  }


  Medication? medicationById(String id) {
    for (final m in medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Medications ordered by most-recently added first.
  List<Medication> get recentMedications {
    final list = List<Medication>.of(medications);
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<Medication> medicationsWithStatus(MedicationStatus? status) {
    if (status == null) return medications;
    return medications.where((m) => m.status == status).toList();
  }

  bool isTaken(String id) => takenIds.contains(id);

  /// When the medication is snoozed until, or null if not currently snoozed.
  DateTime? snoozedUntilFor(String id) {
    final until = _snoozedUntil[id];
    if (until == null) return null;
    if (until.isBefore(DateTime.now())) {
      _snoozedUntil.remove(id);
      return null;
    }
    return until;
  }

  // ---------------------------------------------------------------------------
  // Bootstrap / session lifecycle
  // ---------------------------------------------------------------------------

  /// Called once after the first frame. Restores the session and starts
  /// listening for auth changes.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // Restore persisted preferences (locale + locally-saved profile name).
    _prefs = await SharedPreferences.getInstance();
    final savedLocale = _prefs?.getString(_kLocalePref);
    if (savedLocale != null && savedLocale.isNotEmpty) {
      _localeOverride = Locale(savedLocale);
    }
    final savedName = _prefs?.getString(_kNamePref);
    if (savedName != null && savedName.isNotEmpty) userName = savedName;
    final savedAlarmSound = _prefs?.getString(_kAlarmSoundPref);
    _alarmSoundUri = (savedAlarmSound != null && savedAlarmSound.isNotEmpty)
        ? savedAlarmSound
        : null;
    AlarmService.setAlarmSoundUri(_alarmSoundUri);

    if (!SupabaseService.isConfigured) {
      authStatus = AuthStatus.signedOut;
      notifyListeners();
      await _syncAlarms();
      return;
    }

    await SupabaseService.initialize();
    final client = SupabaseService.client;
    _medsRepo = MedicationRepository(client);
    _profileRepo = ProfileRepository(client);

    _authSub = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null) {
        _onSignedOut();
      } else {
        _onSignedIn(session.user);
      }
    });

    final session = client.auth.currentSession;
    if (session != null) {
      await _onSignedIn(session.user);
    } else {
      authStatus = AuthStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> _onSignedIn(User user) async {
    _user = user;
    // Drop any demo/stale rows before the server data arrives.
    medications.clear();
    takenIds.clear();
    await _refreshData();
    authStatus = AuthStatus.signedIn;
    notifyListeners();
    await _syncAlarms();
  }

  void _onSignedOut() {
    _user = null;
    authStatus = AuthStatus.signedOut;
    _seedMock();
    notifyListeners();
  }

  Future<void> _refreshData() async {
    final uid = _user?.id;
    if (uid == null) return;
    try {
      final name = await _profileRepo?.fetchName(uid);
      if (name != null && name.isNotEmpty) userName = name;
      final meds = await _medsRepo?.fetchAll();
      medications
        ..clear()
        ..addAll(meds ?? const []);
      await refreshDoseHistory();
    } catch (e) {
      debugPrint('Verifi: failed to load data — $e');
    }
  }

  void _seedMock() {
    medications
      ..clear()
      ..addAll(mockMedications);
    userName = _prefs?.getString(_kNamePref) ?? demoUserName;
    takenIds.clear();
    doseHistory.clear();
  }

  /// Rebuilds the OS alarm schedule from the current medication list.
  Future<void> _syncAlarms() async {
    try {
      await AlarmService.syncMedications(medications);
    } catch (e) {
      debugPrint('Verifi: alarm sync failed — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns an error message, a confirmation notice, or null on success.
  Future<String?> signUp(String email, String password, String name) async {
    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      // With email confirmation enabled, signUp returns no session yet.
      if (res.session == null) return 'confirmation-required';
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      debugPrint('Verifi: sign out failed — $e');
    }
    // Auth listener also handles this; do it defensively in case it hasn't.
    _onSignedOut();
  }

  // ---------------------------------------------------------------------------
  // Settings: locale + profile name
  // ---------------------------------------------------------------------------

  /// Switches the app language. Pass null to follow the system locale again.
  Future<void> setLocale(String? code) async {
    _localeOverride = code == null ? null : Locale(code);
    if (code == null) {
      await _prefs?.remove(_kLocalePref);
    } else {
      await _prefs?.setString(_kLocalePref, code);
    }
    notifyListeners();
  }

  /// Updates the alarm ringtone used for dose notifications (null = default)
  /// and re-schedules alarms so the change takes effect immediately.
  Future<void> setAlarmSound(String? uri) async {
    _alarmSoundUri = (uri == null || uri.isEmpty) ? null : uri;
    if (_alarmSoundUri == null) {
      await _prefs?.remove(_kAlarmSoundPref);
    } else {
      await _prefs?.setString(_kAlarmSoundPref, _alarmSoundUri!);
    }
    notifyListeners();
    try {
      await AlarmService.applyAlarmSound(_alarmSoundUri);
    } catch (e) {
      debugPrint('Verifi: alarm sound update failed — $e');
    }
    await _syncAlarms();
  }

  /// Updates the user's display name locally and, when signed in, in Supabase.
  Future<void> updateUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    userName = trimmed;
    await _prefs?.setString(_kNamePref, trimmed);
    final uid = _user?.id;
    final repo = _profileRepo;
    if (isAuthenticated && uid != null && repo != null) {
      try {
        await repo.updateName(uid, trimmed);
      } catch (e) {
        debugPrint('Verifi: update profile name failed — $e');
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Medication mutations (wired to Supabase when authenticated)
  // ---------------------------------------------------------------------------

  Future<Medication?> addMedication(Medication m) async {
    final repo = _medsRepo;
    if (isAuthenticated && repo != null) {
      try {
        final created = await repo.create(m);
        medications.insert(0, created);
        notifyListeners();
        await _syncAlarms();
        return created;
      } catch (e) {
        debugPrint('Verifi: create medication failed — $e');
      }
    }
    medications.insert(0, m);
    notifyListeners();
    await _syncAlarms();
    return m;
  }

  Future<void> updateMedication(Medication m) async {
    final repo = _medsRepo;
    if (isAuthenticated && repo != null) {
      try {
        final updated = await repo.update(m);
        final i = medications.indexWhere((x) => x.id == m.id);
        if (i >= 0) medications[i] = updated;
        notifyListeners();
        await _syncAlarms();
        return;
      } catch (e) {
        debugPrint('Verifi: update medication failed — $e');
      }
    }
    final i = medications.indexWhere((x) => x.id == m.id);
    if (i >= 0) medications[i] = m;
    notifyListeners();
    await _syncAlarms();
  }

  /// Changes a medication's lifecycle status (active / paused / finished).
  ///
  /// Pausing or finishing a medication also clears any pending snooze and
  /// today's taken mark, and the alarm re-sync inside [updateMedication] drops
  /// its scheduled notifications (only active medications get alarms).
  Future<void> setMedicationStatus(String id, MedicationStatus status) async {
    final med = medicationById(id);
    if (med == null || med.status == status) return;
    if (status != MedicationStatus.active) {
      _snoozedUntil.remove(id);
      takenIds.remove(id);
    }
    await updateMedication(med.copyWith(status: status));
  }

  Future<void> deleteMedication(String id) async {
    final repo = _medsRepo;
    if (isAuthenticated && repo != null) {
      try {
        await repo.delete(id);
      } catch (e) {
        debugPrint('Verifi: delete medication failed — $e');
      }
    }
    medications.removeWhere((m) => m.id == id);
    takenIds.remove(id);
    _snoozedUntil.remove(id);
    notifyListeners();
    await _syncAlarms();
  }

  // ---------------------------------------------------------------------------
  // Snooze
  // ---------------------------------------------------------------------------

  /// Snoozes a medication's alarm for [minutes] (default 10) and schedules a
  /// matching one-off OS notification. [time] is the dose's display label.
  Future<void> snooze(
    String medicationId, {
    int minutes = 10,
    String? time,
  }) async {
    final med = medicationById(medicationId);
    if (med == null) return;
    _snoozedUntil[medicationId] = DateTime.now().add(
      Duration(minutes: minutes),
    );
    notifyListeners();
    try {
      await AlarmService.snooze(med, time ?? med.firstTime, minutes);
    } catch (e) {
      debugPrint('Verifi: snooze schedule failed — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Today's "taken" tracking + dose history
  // ---------------------------------------------------------------------------

  void toggleTaken(String id) {
    if (!takenIds.add(id)) {
      takenIds.remove(id);
    } else {
      _logDoseLocally(id, 'taken');
      _recordDose(id, 'taken');
    }
    notifyListeners();
  }

  void markTaken(String id) {
    if (takenIds.add(id)) {
      _logDoseLocally(id, 'taken');
      _recordDose(id, 'taken');
      notifyListeners();
    }
  }

  /// Marks a dose as skipped (not taken) and logs it.
  void skipDose(String id) {
    takenIds.remove(id);
    _logDoseLocally(id, 'skipped');
    _recordDose(id, 'skipped');
    notifyListeners();
  }

  /// Logs a visual verification outcome (mismatch / uncertain) without changing taken.
  void logVerification(String id, String action) {
    if (action != 'mismatch' && action != 'uncertain') return;
    _logDoseLocally(id, action);
    _recordDose(id, action);
    notifyListeners();
  }

  void _logDoseLocally(String medicationId, String action) {
    final med = medicationById(medicationId);
    doseHistory.insert(
      0,
      DoseLogEntry(
        medicationId: medicationId,
        medicationName: med?.name ?? medicationId,
        action: action,
        at: DateTime.now(),
      ),
    );
    // Keep memory bounded.
    if (doseHistory.length > 200) {
      doseHistory.removeRange(200, doseHistory.length);
    }
  }

  /// Last logged dose for a medication (any action), or null.
  DoseLogEntry? lastDoseFor(String medicationId) {
    for (final e in doseHistory) {
      if (e.medicationId == medicationId) return e;
    }
    return null;
  }

  /// Last *taken* dose for a medication, or null.
  DoseLogEntry? lastTakenDoseFor(String medicationId) {
    for (final e in doseHistory) {
      if (e.medicationId == medicationId && e.action == 'taken') return e;
    }
    return null;
  }

  /// In-memory dose history, optionally filtered. Newest first.
  List<DoseLogEntry> doseHistoryFor({
    String? medicationId,
    String? action,
    int limit = 20,
  }) {
    var list = doseHistory.where((e) {
      if (medicationId != null && e.medicationId != medicationId) return false;
      if (action != null && e.action != action) return false;
      return true;
    }).toList();
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  /// Loads recent dose events from Supabase into [doseHistory] when signed in.
  Future<void> refreshDoseHistory({int limit = 50}) async {
    final uid = _user?.id;
    if (uid == null || !SupabaseService.isConfigured) return;
    try {
      final rows = await SupabaseService.client
          .from('dose_events')
          .select('id, medication_id, action, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = <DoseLogEntry>[];
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final medId = map['medication_id']?.toString() ?? '';
        final med = medicationById(medId);
        list.add(
          DoseLogEntry(
            id: map['id']?.toString(),
            medicationId: medId,
            medicationName: med?.name ?? medId,
            action: map['action']?.toString() ?? 'taken',
            at: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      doseHistory
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (e) {
      debugPrint('Verifi: refresh dose history failed — $e');
    }
  }

  Future<void> _recordDose(String medicationId, String action) async {
    final uid = _user?.id;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('dose_events').insert({
        'medication_id': medicationId,
        'user_id': uid,
        'action': action,
      });
    } catch (e) {
      debugPrint('Verifi: record dose failed — $e');
    }
  }

  void setTab(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
