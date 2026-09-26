import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A two-tone capsule used as the medication "avatar" throughout the app.
class PillIcon extends StatelessWidget {
  const PillIcon({
    super.key,
    this.colorIndex = 0,
    this.size = 48,
    this.color1,
    this.color2,
  });

  final int colorIndex;
  final double size;

  /// Optional override of the two-tone colors (e.g. a white pill on the orb).
  final Color? color1;
  final Color? color2;

  @override
  Widget build(BuildContext context) {
    final colors = (color1 != null && color2 != null)
        ? [color1!, color2!]
        : AppColors.pillPalette[colorIndex % AppColors.pillPalette.length];

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Container(
            width: size * 0.72,
            height: size * 0.36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors[0], colors[0], colors[1], colors[1]],
                stops: const [0.0, 0.5, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[1].withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
