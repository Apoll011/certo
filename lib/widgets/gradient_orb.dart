import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The recurring AI/voice brand element: a soft, glowing gradient orb.
class GradientOrb extends StatelessWidget {
  const GradientOrb({
    super.key,
    this.size = 160,
    this.child,
    this.blur = 42,
    this.spread = 10,
  });

  final double size;
  final Widget? child;
  final double blur;
  final double spread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.orbGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withValues(alpha: 0.5),
            blurRadius: blur,
            spreadRadius: spread,
          ),
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.32),
            blurRadius: blur * 0.6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
