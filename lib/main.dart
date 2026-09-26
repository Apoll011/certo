import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'models/medication.dart';
import 'screens/alarm_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/alarm_service.dart';
import 'services/alarm_sound_service.dart';
import 'services/supabase_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AlarmService.init();
  runApp(const VerifiApp());
}

class VerifiApp extends StatelessWidget {
  const VerifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'Verifi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: state.localeOverride,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: AlarmService.navigatorKey,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Top-level router driven by the auth status.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late AppState _state;
  bool _showAuth = false;
  bool _alarmScreenShowing = false;
  Timer? _foregroundAlarmTimer;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onAppStateChanged);
    AlarmService.onOpenAlarm = _openAlarm;
    AlarmSoundService.setAlarmFiredHandler(_openAlarm);
    _startForegroundAlarmCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  void _startForegroundAlarmCheck() {
    _foregroundAlarmTimer?.cancel();
    _foregroundAlarmTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _alarmScreenShowing) return;
      _checkForegroundAlarms();
    });
  }

  void _checkForegroundAlarms() {
    if (_state.authStatus != AuthStatus.signedIn && SupabaseService.isConfigured) {
      return;
    }
    final now = DateTime.now();
    for (final med in _state.medications) {
      if (med.status != MedicationStatus.active) continue;
      if (_state.isTaken(med.id)) continue;
      final snoozedUntil = _state.snoozedUntilFor(med.id);
      if (snoozedUntil != null && snoozedUntil.isAfter(now)) continue;

      for (final t in med.times) {
        final parsed = timeToDateTime(t, now);
        if (parsed != null &&
            parsed.hour == now.hour &&
            parsed.minute == now.minute &&
            now.second <= 12) {
          _openAlarm(med.id, t);
          return;
        }
      }
    }
  }

  /// Bootstraps data, captures cold-start launch details, and routes to the
  /// alarm screen if the OS launched the app to deliver a full-screen alarm.
  Future<void> _afterFirstFrame() async {
    try {
      await _state.bootstrap();
    } catch (e) {
      debugPrint('Verifi: bootstrap failed — $e');
    }
    if (!mounted) return;

    // Check if launched by native alarm intent
    final pendingNative = await AlarmSoundService.getPendingAlarm();
    if (pendingNative != null && mounted) {
      _openAlarm(pendingNative.medicationId, pendingNative.time);
      return;
    }

    await AlarmService.captureLaunchDetails();
    if (!mounted) return;

    if (AlarmService.hasInitialPayload) {
      // An alarm fired on cold start: show it immediately rather than popping
      // permission dialogs over it.
      _maybeOpenInitialAlarm();
    } else {
      // Normal launch: ask for the runtime permissions alarms need.
      await AlarmService.requestPermissions();
    }
  }

  void _maybeOpenInitialAlarm() {
    final payload = AlarmService.consumeInitialPayload();
    if (payload == null) return;
    _openAlarm(payload.medicationId, payload.time);
  }

  void _openAlarm(String medicationId, String? time) {
    if (_alarmScreenShowing) return;

    var med = _state.medicationById(medicationId);
    // If medications haven't finished loading or id was not matched, build
    // a fallback so the alarm screen ALWAYS pops up without fail.
    med ??= Medication(
      id: medicationId,
      name: 'Medication',
      dosage: '1 dose',
      instruction: '',
      category: '',
      notes: '',
      times: [time ?? '9:00 AM'],
      pillColorIndex: 0,
      startedAt: DateTime.now(),
      status: MedicationStatus.active,
    );

    _alarmScreenShowing = true;
    AlarmService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(medication: med!, dueTime: time),
      ),
    ).then((_) {
      _alarmScreenShowing = false;
    });
  }

  @override
  void dispose() {
    _foregroundAlarmTimer?.cancel();
    _state.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    // After signing out, land back on onboarding rather than the auth form.
    if (_state.authStatus == AuthStatus.signedOut && _showAuth) {
      setState(() => _showAuth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    switch (state.authStatus) {
      case AuthStatus.loading:
        return const _SplashScreen();
      case AuthStatus.signedIn:
        return const MainShell();
      case AuthStatus.signedOut:
        if (!SupabaseService.isConfigured) {
          // Offline demo: onboarding flows straight into the shell.
          return OnboardingScreen(
            onGetStarted: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainShell()),
            ),
          );
        }
        if (!_showAuth) {
          return OnboardingScreen(
            onGetStarted: () => setState(() => _showAuth = true),
          );
        }
        return AuthScreen(onBack: () => setState(() => _showAuth = false));
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon.png',
              width: 88,
              height: 88,
              semanticLabel: 'Verifi',
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
