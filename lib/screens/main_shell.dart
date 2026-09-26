import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../widgets/bottom_nav_bar.dart';
import 'caregiver_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'voice_mode_sheet.dart';

/// Hosts the four tabs and the voice entry point.
///
/// Bottom navigation stays on all sizes; wider layouts only constrain content
/// width so the phone UI isn't stretched edge-to-edge.
///
/// Tab 3 is Caregiver by default, or Settings when the caregiver tab is hidden.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    if (!appState.hasEnteredMainShell) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.markEnteredMainShell();
      });
    }

    return Consumer<AppState>(
      builder: (context, state, _) {
        final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
        final tabs = <Widget>[
          const HomeScreen(),
          const MedicationsScreen(),
          const ScheduleScreen(),
          state.showCaregiverTab
              ? const CaregiverScreen()
              : const SettingsScreen(),
        ];

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: wide
                    ? AdaptiveContent(
                        child: IndexedStack(
                          index: state.selectedTabIndex.clamp(0, 3),
                          children: tabs,
                        ),
                      )
                    : IndexedStack(
                        index: state.selectedTabIndex.clamp(0, 3),
                        children: tabs,
                      ),
              ),
              VerifiBottomNavBar(
                selectedIndex: state.selectedTabIndex.clamp(0, 3),
                onTabChanged: state.setTab,
                onMicTap: () => showVoiceMode(context),
                showCaregiverTab: state.showCaregiverTab,
              ),
            ],
          ),
        );
      },
    );
  }
}
