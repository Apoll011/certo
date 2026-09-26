import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A rounded-square icon badge with a pastel background and a line icon.
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? AppColors.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        icon,
        color: iconColor ?? AppColors.primary,
        size: size * 0.48,
      ),
    );
  }
}
