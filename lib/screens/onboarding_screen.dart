import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../web/demo_nav.dart';
import '../widgets/primary_button.dart';
import 'main_shell.dart';

/// Latest Android APK / release notes on GitHub.
const String kVerifiLatestReleaseUrl =
    'https://github.com/Apoll011/verifi/releases/latest';

/// First-launch welcome / value-prop screen.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onGetStarted});

  /// Where "Get started" leads; defaults to the main shell (demo mode).
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
                            color: scheme.onSurfaceVariant,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      label: l10n.getStarted,
                      onPressed: onGetStarted ??
                          () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: DemoRoutes.home,
                                  ),
                                  builder: (_) => const MainShell(),
                                ),
                              ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        onPressed: () => openVerifiLatestRelease(),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(l10n.downloadAndroidApp),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.primary,
                        ),
                      ),
                      Text(
                        l10n.downloadAndroidAppHint,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the GitHub Releases “latest” page in the browser / external app.
Future<void> openVerifiLatestRelease() async {
  final uri = Uri.parse(kVerifiLatestReleaseUrl);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && kDebugMode) {
    debugPrint('Could not launch $kVerifiLatestReleaseUrl');
  }
}
