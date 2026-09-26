import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../web/demo_guide.dart';
import '../web/demo_nav.dart';
import 'iphone_frame.dart';

/// Desktop Chrome shell: iPhone mockup + contextual instructions when space.
class WebDemoShell extends StatelessWidget {
  const WebDemoShell({
    super.key,
    required this.child,
    this.showAuth = false,
  });

  final Widget child;
  final bool showAuth;

  static bool shouldWrap(BuildContext context) {
    if (!kIsWeb) return false;
    return MediaQuery.sizeOf(context).width >= 720;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldWrap(context)) return child;

    final width = MediaQuery.sizeOf(context).width;
    final showGuide = width >= 980;

    return ColoredBox(
      color: const Color(0xFF0B1220),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _DemoBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showGuide) ...[
                    Expanded(
                      flex: 5,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _GuidePanel(showAuth: showAuth),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    flex: showGuide ? 6 : 1,
                    child: Center(child: IPhoneFrame(child: child)),
                  ),
                  if (showGuide) const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBackdrop extends StatelessWidget {
  const _DemoBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1220),
            Color(0xFF102A4A),
            Color(0xFF0D3B4A),
            Color(0xFF0B1220),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GlowOrb(
            alignment: Alignment(-0.85, -0.7),
            color: Color(0xFF1C82AD),
            size: 420,
          ),
          _GlowOrb(
            alignment: Alignment(0.9, 0.75),
            color: Color(0xFF03C988),
            size: 360,
          ),
          _GlowOrb(
            alignment: Alignment(0.2, -0.9),
            color: Color(0xFF00337C),
            size: 280,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.showAuth});

  final bool showAuth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DemoNavTracker.instance,
      builder: (context, _) {
        final state = context.watch<AppState>();
        final guide = guideFor(
          overlayRoute: DemoNavTracker.instance.overlayRoute,
          tabIndex: state.selectedTabIndex,
          showCaregiverTab: state.showCaregiverTab,
          signedIn: state.authStatus == AuthStatus.signedIn ||
              state.hasEnteredMainShell,
          showAuth: showAuth && state.authStatus == AuthStatus.signedOut,
          loading: state.authStatus == AuthStatus.loading,
        );
        return _GuideCard(guide: guide);
      },
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final DemoGuideContent guide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey('${guide.eyebrow}-${guide.title}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/wordmark2.png',
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      'Verifi',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Chrome demo',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                guide.eyebrow.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                guide.title,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                guide.body,
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              ...guide.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tip,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
