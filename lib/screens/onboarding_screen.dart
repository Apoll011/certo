import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/wordmark.png',
                        width: 260,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 48),
                      Text(
                        l10n.onboardingHeadline,
                        textAlign: TextAlign.center,
                        style: AppTheme.headerLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.onboardingSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                label: l10n.getStarted,
                onPressed:
                    onGetStarted ??
                    () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                    ),
              ),
            ),
            const SizedBox(height: 12),
            // iOS home-indicator bar
            Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
