import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
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
        home: const OnboardingScreen(),
      ),
    );
  }
}
