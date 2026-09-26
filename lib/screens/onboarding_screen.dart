import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../widgets/primary_button.dart';
import 'main_shell.dart';

/// First-launch welcome / value-prop screen.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onGetStarted});

  /// Where "Get started" leads; defaults to the main shell (demo mode).
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: AdaptiveContent(
          maxWidth: 480,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/wordmark.png',
                          width: 220,
                          fit: BoxFit.contain,
                          semanticLabel: 'Verifi',
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Text(
                          l10n.onboardingHeadline,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.onboardingSubtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  0,
                  AppSpacing.xxl,
                  16 + bottom,
                ),
                child: PrimaryButton(
                  label: l10n.getStarted,
                  onPressed: onGetStarted ??
                      () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const MainShell(),
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
