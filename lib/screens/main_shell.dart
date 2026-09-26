import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
/// Bottom navigation stays on all sizes; wider layouts only constrain content
/// width so the phone UI isn't stretched edge-to-edge.
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
        final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: wide
                    ? AdaptiveContent(
                        child: IndexedStack(
                          index: state.selectedTabIndex,
                          children: _tabs,
                        ),
                      )
                    : IndexedStack(
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
