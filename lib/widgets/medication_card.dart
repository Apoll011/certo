import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'pill_icon.dart';

/// A reusable medication list row: pill avatar + name + subtitle + trailing.
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

  /// Custom subtitle widget; defaults to the gray dosage/instruction line.
  final Widget? subtitle;

  final double pillSize;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          PillIcon(colorIndex: medication.pillColorIndex, size: pillSize),
          const SizedBox(width: 14),
          Expanded(
            child: subtitle ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: AppTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      medication.dosageLine,
                      style: AppTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
          ),
          const SizedBox(width: 12),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 26,
              ),
        ],
      ),
    );
  }
}
