import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Taken / not-taken control with a 48dp hit target and clear visual state.
class TakenCheckbox extends StatelessWidget {
  const TakenCheckbox({
    super.key,
    required this.taken,
    this.onToggle,
    this.semanticLabel,
  });

  final bool taken;
  final VoidCallback? onToggle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      checked: taken,
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            child: Center(
              child: AnimatedContainer(
                duration: AppDurations.fast,
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: taken ? scheme.primary : Colors.transparent,
                  border: taken
                      ? null
                      : Border.all(color: AppColors.textTertiary, width: 2),
                ),
                child: taken
                    ? Icon(
                        Icons.check_rounded,
                        color: scheme.onPrimary,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
