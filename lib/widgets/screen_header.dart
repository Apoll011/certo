import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'circle_icon_button.dart';

/// Consistent page header used across push-routes and tab roots.
///
/// Does not apply page insets — parents own horizontal padding.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.large = false,
    this.subtitle,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool large;
  final String? subtitle;

  /// Standard back button for pushed routes.
  factory ScreenHeader.back({
    Key? key,
    required String title,
    required VoidCallback onBack,
    Widget? trailing,
    String? backTooltip,
  }) {
    return ScreenHeader(
      key: key,
      title: title,
      leading: CircleIconButton(
        icon: Icons.arrow_back_rounded,
        onTap: onBack,
        tooltip: backTooltip,
      ),
      trailing: trailing ?? const SizedBox(width: AppSpacing.touchTarget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (large) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.headlineLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      );
    }

    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ] else if (leading != null)
          const SizedBox(width: AppSpacing.touchTarget),
      ],
    );
  }
}
