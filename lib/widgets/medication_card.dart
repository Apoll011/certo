import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'pill_icon.dart';

/// Medication list row: pill avatar + name + subtitle + trailing.
///
/// [subtitle] always appears *under* the medication name — it never replaces
/// the title.
class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.pillSize = 48,
  });

  final Medication medication;
  final VoidCallback? onTap;

  /// Right-side widget (checkbox, chevron, etc.). Defaults to a chevron.
  final Widget? trailing;

  /// Extra lines under the name; defaults to the dosage/instruction line.
  final Widget? subtitle;

  final double pillSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: medication.name,
      child: Row(
        children: [
          PillIcon(colorIndex: medication.pillColorIndex, size: pillSize),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: textTheme.titleMedium ?? AppTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                subtitle ??
                    Text(
                      medication.dosageLine,
                      style: textTheme.bodyMedium ?? AppTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 26,
              ),
        ],
      ),
    );
  }
}
