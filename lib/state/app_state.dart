import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/caregiver_repository.dart';
import '../data/medication_repository.dart';
import '../data/mock_data.dart';
import '../data/profile_repository.dart';
import '../models/caregiver.dart';
import '../models/dose_log_entry.dart';
import '../models/medication.dart';
import '../config/app_config.dart';
import '../ai/ai.dart';
import '../services/alarm_service.dart';
import '../services/supabase_service.dart';
import '../utils/adherence.dart';


enum AuthStatus { loading, signedOut, signedIn }

const String _kLocalePref = 'locale_override';
const String _kNamePref = 'user_name';
const String _kAlarmSoundPref = 'alarm_sound_uri';
const String _kTakenIdsPref = 'taken_ids_today';
const String _kTakenDatePref = 'taken_ids_date';
const String _kShowCaregiverTabPref = 'show_caregiver_tab';

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

  /// Whether this account is a caregiver (family or professional).
  bool isCaregiver = false;
  String role = 'individual';

  /// When false, the Caregiver tab is hidden and Settings replaces it in the nav.
  bool showCaregiverTab = true;

  /// Active people I care for (when [isCaregiver]).
  final List<CaregiverLink> careRecipients = [];

  /// Links where I am the patient (invites + caregivers watching me).
  final List<CaregiverLink> grantedCareLinks = [];

  /// Cached snapshots keyed by link id.
  final Map<String, CareRecipientSnapshot> careSnapshots = {};

  AuthStatus authStatus;
  User? _user;

  User? get user => _user;
  String? get userEmail => _user?.email;
  bool get isAuthenticated => _user != null;

  /// True after the user reaches [MainShell] (including offline demo).
  /// Used by the Chrome side-guide to leave the onboarding copy behind.
  bool hasEnteredMainShell = false;

  /// Auth form visible (vs onboarding) while signed out. Chrome guide uses this.
  bool showAuthForm = false;

  void markEnteredMainShell() {
    if (hasEnteredMainShell) return;
    hasEnteredMainShell = true;
    notifyListeners();
  }

  void setShowAuthForm(bool value) {
    if (showAuthForm == value) return;
    showAuthForm = value;
    notifyListeners();
  }

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
  CaregiverRepository? _caregiverRepo;
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

  bool isTaken(String id) =>
      takenIds.contains(id) && medicationById(id) != null;

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

    // Restore today's "taken" marks before UI paints.
    _restoreTakenIdsFromPrefs();
    showCaregiverTab = _prefs?.getBool(_kShowCaregiverTabPref) ?? true;

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
    _caregiverRepo = CaregiverRepository(client);

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
    // Keep takenIds until dose history rebuilds them for today.
    await _refreshData();
    authStatus = AuthStatus.signedIn;
    notifyListeners();
    await _syncAlarms();
  }

  void _onSignedOut() {
    _user = null;
    authStatus = AuthStatus.signedOut;
    hasEnteredMainShell = false;
    showAuthForm = false;
    _seedMock();
    _restoreTakenIdsFromPrefs();
    notifyListeners();
  }

  Future<void> _refreshData() async {
    final uid = _user?.id;
    if (uid == null) return;
    try {
      final profile = await _profileRepo?.fetchProfile(uid);
      if (profile != null) {
        final name = profile['name'] as String?;
        if (name != null && name.isNotEmpty) userName = name;
        isCaregiver = profile['is_caregiver'] as bool? ?? false;
        role = profile['role']?.toString() ??
            (isCaregiver ? 'family_caregiver' : 'individual');
      }
      final meds = await _medsRepo?.fetchAll();
      medications
        ..clear()
        ..addAll(meds ?? const []);
      _pruneTakenIds();
      await refreshDoseHistory();
      await refreshCaregiverData();
    } catch (e) {
      debugPrint('Verifi: failed to load data — $e');
    }
  }

  void _seedMock() {
    medications
      ..clear()
      ..addAll(mockMedications);
    userName = _prefs?.getString(_kNamePref) ?? demoUserName;
    // Don't clear takenIds here — restored from prefs after seed / on bootstrap.
    doseHistory.clear();
    careRecipients.clear();
    grantedCareLinks.clear();
    careSnapshots.clear();
    isCaregiver = _prefs?.getBool('is_caregiver_local') ?? false;
    role = isCaregiver ? 'family_caregiver' : 'individual';
  }

  /// Local calendar day key (yyyy-MM-dd) for "taken today" persistence.
  static String _todayKey([DateTime? now]) => adherenceDayKey(now ?? DateTime.now());

  /// Restore [takenIds] from SharedPreferences when the saved day is today.
  void _restoreTakenIdsFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;
    final savedDay = prefs.getString(_kTakenDatePref);
    final today = _todayKey();
    if (savedDay != today) {
      // New day — clear yesterday's marks.
      takenIds.clear();
      unawaited(prefs.remove(_kTakenIdsPref));
      unawaited(prefs.setString(_kTakenDatePref, today));
      return;
    }
    final ids = prefs.getStringList(_kTakenIdsPref) ?? const <String>[];
    takenIds
      ..clear()
      ..addAll(ids);
    // Don't prune here — medications may still be mocks during bootstrap.
  }

  Future<void> _persistTakenIds() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kTakenDatePref, _todayKey());
      await prefs.setStringList(_kTakenIdsPref, takenIds.toList());
    } catch (e) {
      debugPrint('Verifi: persist taken ids failed — $e');
    }
  }

  /// Rebuild today's taken set from [doseHistory] (newest action per med wins).
  void _rebuildTakenIdsFromHistory() {
    final now = DateTime.now();
    final taken = takenMedIdsForDay(doseHistory, now);
    takenIds
      ..clear()
      ..addAll(taken.where((id) => medicationById(id) != null));
  }

  /// Drop taken marks that don't belong to a known medication.
  void _pruneTakenIds() {
    takenIds.removeWhere((id) => medicationById(id) == null);
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
  Future<String?> signUp(
    String email,
    String password,
    String name, {
    bool asCaregiver = false,
  }) async {
    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'is_caregiver': asCaregiver,
          'role': asCaregiver ? 'family_caregiver' : 'individual',
        },
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
      unawaited(_persistTakenIds());
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
    unawaited(_persistTakenIds());
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
      // Record skip so a later history rebuild does not revive "taken".
      _logDoseLocally(id, 'skipped');
      unawaited(_recordDose(id, 'skipped'));
    } else {
      _logDoseLocally(id, 'taken');
      unawaited(_recordDose(id, 'taken'));
    }
    unawaited(_persistTakenIds());
    notifyListeners();
  }

  void markTaken(String id) {
    if (takenIds.add(id)) {
      _logDoseLocally(id, 'taken');
      unawaited(_recordDose(id, 'taken'));
      unawaited(_persistTakenIds());
      notifyListeners();
    }
  }

  /// Marks a dose as skipped (not taken) and logs it.
  void skipDose(String id) {
    takenIds.remove(id);
    _logDoseLocally(id, 'skipped');
    unawaited(_recordDose(id, 'skipped'));
    unawaited(_persistTakenIds());
    notifyListeners();
  }

  /// Logs a visual verification outcome (mismatch / uncertain) without changing taken.
  void logVerification(String id, String action) {
    if (action != 'mismatch' && action != 'uncertain') return;
    _logDoseLocally(id, action);
    unawaited(_recordDose(id, action));
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
  Future<void> refreshDoseHistory({int limit = 100}) async {
    final uid = _user?.id;
    if (uid == null || !SupabaseService.isConfigured) return;
    try {
      // Keep optimistic local rows (not yet on server) so a refresh can't wipe
      // today's taken marks while the insert is in flight / offline.
      final pendingLocal = doseHistory
          .where((e) => e.id == null)
          .toList(growable: false);

      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 40))
          .toIso8601String();
      final rows = await SupabaseService.client
          .from('dose_events')
          .select('id, medication_id, action, created_at')
          .eq('user_id', uid)
          .gte('created_at', since)
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

      // Re-attach pending locals that aren't already represented server-side.
      for (final local in pendingLocal) {
        final already = list.any(
          (s) =>
              s.medicationId == local.medicationId &&
              s.action == local.action &&
              (s.at.difference(local.at).inSeconds).abs() < 120,
        );
        if (!already) list.insert(0, local);
      }

      doseHistory
        ..clear()
        ..addAll(list);

      if (list.isNotEmpty) {
        _rebuildTakenIdsFromHistory();
      } else {
        _restoreTakenIdsFromPrefs();
      }
      _pruneTakenIds();
      await _persistTakenIds();
      notifyListeners();
    } catch (e) {
      debugPrint('Verifi: refresh dose history failed — $e');
      _restoreTakenIdsFromPrefs();
      _pruneTakenIds();
    }
  }

  Future<void> _recordDose(String medicationId, String action) async {
    final uid = _user?.id;
    if (uid == null) return;
    try {
      final row = await SupabaseService.client
          .from('dose_events')
          .insert({
            'medication_id': medicationId,
            'user_id': uid,
            'action': action,
          })
          .select('id, created_at')
          .maybeSingle();
      // Stamp the matching optimistic local row so the next refresh won't
      // duplicate it.
      if (row != null) {
        final id = row['id']?.toString();
        final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
        for (var i = 0; i < doseHistory.length; i++) {
          final e = doseHistory[i];
          if (e.id != null) continue;
          if (e.medicationId != medicationId || e.action != action) continue;
          doseHistory[i] = DoseLogEntry(
            id: id,
            medicationId: e.medicationId,
            medicationName: e.medicationName,
            action: e.action,
            at: created ?? e.at,
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('Verifi: record dose failed — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Caregiver mode
  // ---------------------------------------------------------------------------

  Future<void> setCaregiverMode(bool enabled, {String? roleOverride}) async {
    isCaregiver = enabled;
    role = roleOverride ?? (enabled ? 'family_caregiver' : 'individual');
    await _prefs?.setBool('is_caregiver_local', enabled);
    final uid = _user?.id;
    final repo = _profileRepo;
    if (isAuthenticated && uid != null && repo != null) {
      try {
        await repo.updateCaregiverFlag(
          userId: uid,
          isCaregiver: enabled,
          role: role,
        );
      } catch (e) {
        debugPrint('Verifi: update caregiver flag failed — $e');
      }
    }
    if (enabled) {
      await refreshCaregiverData();
    } else {
      careRecipients.clear();
      careSnapshots.clear();
    }
    notifyListeners();
  }

  /// Show or hide the Caregiver tab in the bottom nav (Settings replaces it).
  Future<void> setShowCaregiverTab(bool show) async {
    showCaregiverTab = show;
    await _prefs?.setBool(_kShowCaregiverTabPref, show);
    // If we hide caregiver while sitting on that tab, stay on the 4th slot
    // (now Settings). If we re-show caregiver while on Settings tab slot, fine.
    if (selectedTabIndex > 3) selectedTabIndex = 3;
    notifyListeners();
  }

  Future<void> refreshCaregiverData() async {
    final repo = _caregiverRepo;
    if (!isAuthenticated || repo == null) return;
    try {
      final granted = await repo.fetchMyGrantedLinks();
      grantedCareLinks
        ..clear()
        ..addAll(granted);

      // Always load recipients you already linked (even before flipping the flag).
      final recipients = await repo.fetchMyCareRecipients();
      careRecipients
        ..clear()
        ..addAll(recipients);
      if (recipients.isNotEmpty && !isCaregiver) {
        isCaregiver = true;
        role = 'family_caregiver';
        await _prefs?.setBool('is_caregiver_local', true);
      }
      for (final link in List<CaregiverLink>.of(careRecipients)) {
        try {
          final snap = await repo.loadRecipientSnapshot(link);
          careSnapshots[link.id] = snap;
        } catch (e) {
          debugPrint('Verifi: recipient snapshot failed — $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Verifi: refresh caregiver data failed — $e');
    }
  }

  Future<CaregiverLink?> createCaregiverInvite() async {
    final repo = _caregiverRepo;
    if (!isAuthenticated || repo == null) return null;
    try {
      final link = await repo.createInvite();
      await refreshCaregiverData();
      return link;
    } catch (e) {
      debugPrint('Verifi: create invite failed — $e');
      rethrow;
    }
  }

  Future<void> revokeCaregiverAccess(String linkId) async {
    final repo = _caregiverRepo;
    if (repo == null) return;
    await repo.revokeLink(linkId);
    await refreshCaregiverData();
  }

  Future<CaregiverLink> redeemCaregiverInvite({
    required String code,
    String label = '',
  }) async {
    final repo = _caregiverRepo;
    if (!isAuthenticated || repo == null) {
      throw StateError('Sign in to add someone');
    }
    if (!isCaregiver) {
      await setCaregiverMode(true);
    }
    final link = await repo.redeemInvite(code: code, label: label);
    await refreshCaregiverData();
    return link;
  }

  Future<CareRecipientSnapshot?> loadCareRecipient(String linkId) async {
    final repo = _caregiverRepo;
    if (repo == null) return careSnapshots[linkId];
    CaregiverLink? link;
    for (final l in careRecipients) {
      if (l.id == linkId) {
        link = l;
        break;
      }
    }
    if (link == null) return null;
    final snap = await repo.loadRecipientSnapshot(link);
    careSnapshots[linkId] = snap;
    notifyListeners();
    return snap;
  }

  Future<void> markTakenForPatient({
    required String patientId,
    required String medicationId,
    required String linkId,
  }) async {
    final repo = _caregiverRepo;
    if (repo == null) return;
    await repo.recordDoseForPatient(
      patientId: patientId,
      medicationId: medicationId,
      action: 'taken',
    );
    await loadCareRecipient(linkId);
  }

  Future<void> updateCareRecipientLabel(String linkId, String label) async {
    final repo = _caregiverRepo;
    await repo?.updateRecipientLabel(linkId, label);
    await refreshCaregiverData();
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
