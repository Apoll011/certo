import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'icon_badge.dart';
import 'primary_button.dart';

/// A friendly empty state used when a list has nothing to show.
///
/// By default it renders as a card (for use inside scrolling lists). Set
/// [card] to false for a full-page centered variant that fills the space it
/// is given.
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
    this.card = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color iconColor;
  final Color iconBackground;

  /// When false, centers the content to fill the available space (no card).
  final bool card;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(
          icon: icon,
          size: 64,
          color: iconBackground,
          iconColor: iconColor,
        ),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: AppTheme.headerMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          PrimaryButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );

    if (!card) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: content,
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: 8),
          content,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
