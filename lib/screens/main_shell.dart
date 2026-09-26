import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../widgets/bottom_nav_bar.dart';
import 'caregiver_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'schedule_screen.dart';
import 'voice_mode_sheet.dart';

/// Hosts the four tabs and the voice entry point.
///
/// Phones use a bottom bar; wider layouts use a navigation rail so content
/// isn't stretched across the full tablet width.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = <Widget>[
    HomeScreen(),
    MedicationsScreen(),
    ScheduleScreen(),
    CaregiverScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final width = MediaQuery.sizeOf(context).width;
        final useRail = width >= AppBreakpoints.medium;

        return Scaffold(
          body: useRail
              ? _WideShell(
                  selectedIndex: state.selectedTabIndex,
                  onTabChanged: state.setTab,
                  onMicTap: () => showVoiceMode(context),
                  child: IndexedStack(
                    index: state.selectedTabIndex,
                    children: _tabs,
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: state.selectedTabIndex,
                        children: _tabs,
                      ),
                    ),
                    VerifiBottomNavBar(
                      selectedIndex: state.selectedTabIndex,
                      onTabChanged: state.setTab,
                      onMicTap: () => showVoiceMode(context),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.onMicTap,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onMicTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onTabChanged,
          labelType: NavigationRailLabelType.all,
          backgroundColor: scheme.surface,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FloatingActionButton(
              onPressed: onMicTap,
              tooltip: l10n.voiceMode,
              elevation: 0,
              highlightElevation: 0,
              child: const Icon(Icons.mic_rounded),
            ),
          ),
          destinations: [
            NavigationRailDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: Text(l10n.home),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.medication_outlined),
              selectedIcon: const Icon(Icons.medication_rounded),
              label: Text(l10n.meds),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: Text(l10n.schedule),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: Text(l10n.caregiver),
            ),
          ],
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: scheme.outlineVariant,
        ),
        Expanded(
          child: AdaptiveContent(child: child),
        ),
      ],
    );
  }
}
