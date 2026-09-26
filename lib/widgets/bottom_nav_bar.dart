import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bottom tab bar: Home · Meds · [floating mic] · Schedule · Caregiver|Settings.
///
/// The mic sits above the bar and overlaps it, larger on tablets.
class VerifiBottomNavBar extends StatelessWidget {
  const VerifiBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.onMicTap,
    this.showCaregiverTab = true,
  });

  /// Tab index: 0 = Home, 1 = Meds, 2 = Schedule, 3 = Caregiver or Settings.
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onMicTap;

  /// When false, the 4th tab is Settings instead of Caregiver.
  final bool showCaregiverTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    // Phone: 76 / overflows ~22. Tablet: 92 / overflows ~32.
    final micSize = wide ? 92.0 : 76.0;
    final micOverlap = wide ? 32.0 : 22.0;
    final barHeight = wide ? 72.0 : 64.0;
    final micSlot = micSize + 16;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // Extra height so the floating mic isn't clipped by the parent Column.
        height: barHeight + micOverlap + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Bar surface — sits under the mic.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                  boxShadow: AppColors.navShadow,
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: l10n.home,
                            selected: selectedIndex == 0,
                            onTap: () => onTabChanged(0),
                            compact: !wide,
                          ),
                        ),
                        Expanded(
                          child: _TabItem(
                            icon: Icons.medication_outlined,
                            activeIcon: Icons.medication_rounded,
                            label: l10n.meds,
                            selected: selectedIndex == 1,
                            onTap: () => onTabChanged(1),
                            compact: !wide,
                          ),
                        ),
                        SizedBox(width: micSlot),
                        Expanded(
                          child: _TabItem(
                            icon: Icons.calendar_today_outlined,
                            activeIcon: Icons.calendar_month_rounded,
                            label: l10n.schedule,
                            selected: selectedIndex == 2,
                            onTap: () => onTabChanged(2),
                            compact: !wide,
                          ),
                        ),
                        Expanded(
                          child: _TabItem(
                            icon: showCaregiverTab
                                ? Icons.people_outline_rounded
                                : Icons.settings_outlined,
                            activeIcon: showCaregiverTab
                                ? Icons.people_rounded
                                : Icons.settings_rounded,
                            label: showCaregiverTab
                                ? l10n.caregiver
                                : l10n.settings,
                            selected: selectedIndex == 3,
                            onTap: () => onTabChanged(3),
                            compact: !wide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Floating mic — centered, protruding above the bar.
            Positioned(
              bottom: bottomInset + barHeight - (micSize - micOverlap),
              child: _MicButton(
                onTap: onMicTap,
                tooltip: l10n.voiceMode,
                size: micSize,
              ),
            ),
          ],
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
    this.compact = true,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final iconSize = compact ? 24.0 : 26.0;
    final labelSize = compact ? 11.0 : 12.0;

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
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: AppRadii.mdAll,
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color: color,
                size: iconSize,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: labelSize,
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
  const _MicButton({
    required this.onTap,
    required this.tooltip,
    required this.size,
  });

  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = size * 0.40;
    final ring = size * 0.055;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            // Soft circular glow only — no Material elevation (avoids the
            // rectangular shadow/clip artifact behind the mic).
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.32),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shadowColor: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: scheme.onPrimary.withValues(alpha: 0.18),
                highlightColor: scheme.onPrimary.withValues(alpha: 0.08),
                child: Ink(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: ring),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(scheme.primary, Colors.white, 0.12)!,
                        scheme.primary,
                        Color.lerp(scheme.primary, Colors.black, 0.12)!,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: scheme.onPrimary,
                    size: iconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
