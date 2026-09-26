import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'caregiver_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'schedule_screen.dart';
import 'voice_mode_sheet.dart';

/// Scaffold hosting the four tabs and the center mic FAB.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: state.selectedTabIndex,
                  children: const [
                    HomeScreen(),
                    MedicationsScreen(),
                    ScheduleScreen(),
                    CaregiverScreen(),
                  ],
                ),
              ),
              VerifiBottomNavBar(
                selectedIndex: state.selectedTabIndex,
                onTabChanged: (i) => state.setTab(i),
                onMicTap: () => showVoiceMode(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
