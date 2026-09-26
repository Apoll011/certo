import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Surface container for grouped content.
///
/// Default: flat white with a hairline outline (calm, native). Set [elevated]
/// only for floating chrome that needs to lift above the page.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.radius = AppRadii.lg,
    this.elevated = false,
    this.bordered = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final bool elevated;
  final bool bordered;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final scheme = Theme.of(context).colorScheme;

    Widget content = Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: borderRadius,
        border: bordered && color == null
            ? Border.all(color: scheme.outlineVariant)
            : null,
        boxShadow: elevated ? AppColors.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: content,
      );
    }

    return content;
  }
}
