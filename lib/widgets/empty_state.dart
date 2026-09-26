import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'icon_badge.dart';
import 'primary_button.dart';

/// Empty state with a clear next step.
///
/// Kept quiet — no card chrome by default so emptiness doesn't look like
/// clutter. Set [card] only when embedding inside a denser list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primarySoft,
    this.card = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color iconColor;
  final Color iconBackground;

  /// When true, wraps content in a bordered surface (legacy list embedding).
  final bool card;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(
          icon: icon,
          size: 56,
          color: iconBackground,
          iconColor: iconColor,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall ?? AppTheme.headerMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: (textTheme.bodyMedium ?? AppTheme.bodyMedium).copyWith(
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: PrimaryButton(label: actionLabel!, onPressed: onAction),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      child: content,
    );

    if (card) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: padded,
      );
    }

    return Center(
      child: SingleChildScrollView(child: padded),
    );
  }
}
