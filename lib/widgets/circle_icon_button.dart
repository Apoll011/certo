import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Circular icon control for back, settings, add, etc.
///
/// Hit area is at least [AppSpacing.touchTarget]; the visible circle can be
/// smaller via [size].
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.surface;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                icon,
                color: iconColor ?? scheme.onSurface,
                size: size * 0.48,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
