import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circle outline -> filled indigo circle with a white check.
class TakenCheckbox extends StatelessWidget {
  const TakenCheckbox({super.key, required this.taken, this.onToggle});

  final bool taken;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: taken ? AppColors.primary : Colors.transparent,
          border: taken
              ? null
              : Border.all(color: const Color(0xFFC7C7D2), width: 2),
        ),
        child: taken
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
