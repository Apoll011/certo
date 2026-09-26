import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bottom tab bar: Home · Meds · [mic] · Schedule · Caregiver.
///
/// Quiet surface with a solid primary mic control — voice-first without the
/// heavy floating chrome of a demo FAB.
class VerifiBottomNavBar extends StatelessWidget {
  const VerifiBottomNavBar({
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
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
          boxShadow: AppColors.navShadow,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                Expanded(
                  child: _TabItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: l10n.home,
                    selected: selectedIndex == 0,
                    onTap: () => onTabChanged(0),
                  ),
                ),
                Expanded(
                  child: _TabItem(
                    icon: Icons.medication_outlined,
                    activeIcon: Icons.medication_rounded,
                    label: l10n.meds,
                    selected: selectedIndex == 1,
                    onTap: () => onTabChanged(1),
                  ),
                ),
                Expanded(
                  child: _MicButton(onTap: onMicTap, tooltip: l10n.voiceMode),
                ),
                Expanded(
                  child: _TabItem(
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                    label: l10n.schedule,
                    selected: selectedIndex == 2,
                    onTap: () => onTabChanged(2),
                  ),
                ),
                Expanded(
                  child: _TabItem(
                    icon: Icons.people_outline_rounded,
                    activeIcon: Icons.people_rounded,
                    label: l10n.caregiver,
                    selected: selectedIndex == 3,
                    onTap: () => onTabChanged(3),
                  ),
                ),
              ],
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: AppRadii.mdAll,
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: scheme.onPrimary,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
