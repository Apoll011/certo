import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/medication_repository.dart';
import '../data/mock_data.dart';
import '../data/profile_repository.dart';
import '../models/medication.dart';
import '../services/supabase_service.dart';

enum AuthStatus { loading, signedOut, signedIn }

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

  String userName = demoUserName;
  int selectedTabIndex = 0;

  AuthStatus authStatus;
  User? _user;

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  StreamSubscription<AuthState>? _authSub;
  MedicationRepository? _medsRepo;
  ProfileRepository? _profileRepo;
  bool _bootstrapped = false;

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

  // ---------------------------------------------------------------------------
  // Bootstrap / session lifecycle
  // ---------------------------------------------------------------------------

  /// Called once after the first frame. Restores the session and starts
  /// listening for auth changes.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    if (!SupabaseService.isConfigured) {
      authStatus = AuthStatus.signedOut;
      notifyListeners();
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
    } catch (e) {
      debugPrint('Certo: failed to load data — $e');
    }
  }

  void _seedMock() {
    medications
      ..clear()
      ..addAll(mockMedications);
    userName = demoUserName;
    takenIds.clear();
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
      debugPrint('Certo: sign out failed — $e');
    }
    // Auth listener also handles this; do it defensively in case it hasn't.
    _onSignedOut();
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
        return created;
      } catch (e) {
        debugPrint('Certo: create medication failed — $e');
      }
    }
    medications.insert(0, m);
    notifyListeners();
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
        return;
      } catch (e) {
        debugPrint('Certo: update medication failed — $e');
      }
    }
    final i = medications.indexWhere((x) => x.id == m.id);
    if (i >= 0) medications[i] = m;
    notifyListeners();
  }

  Future<void> deleteMedication(String id) async {
    final repo = _medsRepo;
    if (isAuthenticated && repo != null) {
      try {
        await repo.delete(id);
      } catch (e) {
        debugPrint('Certo: delete medication failed — $e');
      }
    }
    medications.removeWhere((m) => m.id == id);
    takenIds.remove(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Today's "taken" tracking
  // ---------------------------------------------------------------------------

  void toggleTaken(String id) {
    if (!takenIds.add(id)) {
      takenIds.remove(id);
    } else {
      _recordDose(id, 'taken');
    }
    notifyListeners();
  }

  void markTaken(String id) {
    if (takenIds.add(id)) {
      _recordDose(id, 'taken');
      notifyListeners();
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
      debugPrint('Certo: record dose failed — $e');
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
