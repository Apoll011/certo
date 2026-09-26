import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medication_reminder/l10n/app_localizations.dart';
import 'package:medication_reminder/main.dart';
import 'package:medication_reminder/screens/auth_screen.dart';
import 'package:medication_reminder/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding renders headline and CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CertoApp());

    expect(find.textContaining('Your medication'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Portuguese localization renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    );

    expect(find.textContaining('Seu medicamento'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });

  testWidgets('Auth screen renders sign-in form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AuthScreen(),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
