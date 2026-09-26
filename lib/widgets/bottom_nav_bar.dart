import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom tab bar: Home · Meds · [mic FAB] · Schedule · Caregiver.
///
/// The mic FAB is an oversized elevated indigo circle in the center.
class CertoBottomNavBar extends StatelessWidget {
  const CertoBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.onMicTap,
  });

  /// Tab index: 0 = Home, 1 = Meds, 2 = Schedule, 3 = Caregiver.
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -26,
                child: _MicFab(onTap: onMicTap),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TabItem(
                      icon: Icons.home_rounded,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: selectedIndex == 0,
                      onTap: () => onTabChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      icon: Icons.medication_outlined,
                      activeIcon: Icons.medication_rounded,
                      label: 'Meds',
                      selected: selectedIndex == 1,
                      onTap: () => onTabChanged(1),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: _TabItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_month_rounded,
                      label: 'Schedule',
                      selected: selectedIndex == 2,
                      onTap: () => onTabChanged(2),
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Caregiver',
                      selected: selectedIndex == 3,
                      onTap: () => onTabChanged(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicFab extends StatelessWidget {
  const _MicFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF6C7BFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
