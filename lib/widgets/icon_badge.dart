import 'package:flutter/material.dart';

/// Soft icon badge used for list leading icons and empty states.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.iconColor,
    this.size = 44,
  });

  final IconData icon;
  final Color? color;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        icon,
        color: iconColor ?? scheme.primary,
        size: size * 0.48,
      ),
    );
  }
}
