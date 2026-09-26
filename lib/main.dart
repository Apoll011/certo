import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const CertoApp());
}

class CertoApp extends StatelessWidget {
  const CertoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Certo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Root(),
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

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onAppStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _state.bootstrap();
    });
  }

  @override
  void dispose() {
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
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
