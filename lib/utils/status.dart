import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../theme/app_colors.dart';

/// Accent color used to represent a medication status in the UI.
Color statusColor(MedicationStatus status) {
  switch (status) {
    case MedicationStatus.active:
      return AppColors.success;
    case MedicationStatus.paused:
      return AppColors.info;
    case MedicationStatus.finished:
      return AppColors.textSecondary;
  }
}

/// Soft background tint for a medication status badge/chip.
Color statusSoftColor(MedicationStatus status) {
  switch (status) {
    case MedicationStatus.active:
      return AppColors.successSoft;
    case MedicationStatus.paused:
      return AppColors.infoSoft;
    case MedicationStatus.finished:
      return const Color(0xFFF0F0F4);
  }
}

/// Icon for a medication status.
IconData statusIcon(MedicationStatus status) {
  switch (status) {
    case MedicationStatus.active:
      return Icons.play_circle_rounded;
    case MedicationStatus.paused:
      return Icons.pause_circle_rounded;
    case MedicationStatus.finished:
      return Icons.check_circle_rounded;
  }
}

/// Localized display label for a medication status.
String statusLabel(AppLocalizations l10n, MedicationStatus status) {
  switch (status) {
    case MedicationStatus.active:
      return l10n.statusActive;
    case MedicationStatus.paused:
      return l10n.statusPaused;
    case MedicationStatus.finished:
      return l10n.statusFinished;
  }
}
