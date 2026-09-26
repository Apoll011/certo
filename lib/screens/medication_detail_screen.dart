import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../utils/status.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/icon_badge.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
import 'manual_medication_form_screen.dart';
import '../web/demo_nav.dart';

/// Full info for a single medication.
class MedicationDetailScreen extends StatelessWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});

  final String medicationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final med = state.medicationById(medicationId);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (med == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  12,
                  AppSpacing.pageX,
                  AppSpacing.sm,
                ),
                child: ScreenHeader.back(
                  title: l10n.medicationDetail,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    l10n.medicationNotFound,
                    style: textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final taken = state.isTaken(med.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                12,
                AppSpacing.pageX,
                AppSpacing.sm,
              ),
              child: ScreenHeader.back(
                title: l10n.medicationDetail,
                onBack: () => Navigator.of(context).pop(),
                trailing: CircleIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.editMedication,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: DemoRoutes.manualMedication),
                      builder: (_) =>
                          ManualMedicationFormScreen(medication: med),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.pagePaddingTight,
                children: [
                  Column(
                    children: [
                      PillIcon(colorIndex: med.pillColorIndex, size: 88),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        med.name,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      if (med.category.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(med.category, style: textTheme.bodyMedium),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      for (final status in MedicationStatus.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: status == MedicationStatus.values.last
                                  ? 0
                                  : AppSpacing.sm,
                            ),
                            child: _statusTile(context, med, status),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          context,
                          icon: Icons.medication_outlined,
                          label: l10n.dosage,
                          value:
                              '${l10n.takeDosage(med.dosage)}\n${med.instruction}',
                        ),
                        Divider(color: scheme.outlineVariant, height: 1),
                        _detailRow(
                          context,
                          icon: Icons.schedule_rounded,
                          label: l10n.scheduleLabel,
                          value:
                              '${displayTimes(med.times, l10n)}\n'
                              '${med.frequencyDays == 1 ? l10n.everyDay : l10n.everyNDays(med.frequencyDays)}',
                        ),
                        Divider(color: scheme.outlineVariant, height: 1),
                        _detailRow(
                          context,
                          icon: Icons.calendar_today_outlined,
                          label: l10n.started,
                          value: fullDate(med.startedAt, locale),
                        ),
                        if (med.notes.isNotEmpty) ...[
                          Divider(color: scheme.outlineVariant, height: 1),
                          _detailRow(
                            context,
                            icon: Icons.sticky_note_2_outlined,
                            label: l10n.notes,
                            value: med.notes,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                AppSpacing.sm,
                AppSpacing.pageX,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: PrimaryButton(
                label: taken ? l10n.taken : l10n.markAsTaken,
                icon: taken ? Icons.check_rounded : null,
                color: taken ? scheme.tertiary : scheme.primary,
                onPressed: taken
                    ? null
                    : () {
                        state.markTaken(med.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(l10n.markedAsTaken)),
                          );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(
    BuildContext context,
    Medication med,
    MedicationStatus status,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<AppState>();
    final selected = med.status == status;
    final color = statusColor(status);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      label: statusLabel(l10n, status),
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: () async {
          if (selected) return;
          final messenger = ScaffoldMessenger.of(context);
          await state.setMedicationStatus(med.id, status);
          if (!context.mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.statusUpdated)));
        },
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : scheme.surface,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Icon(
                statusIcon(status),
                color: selected ? Colors.white : color,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                statusLabel(l10n, status),
                style: TextStyle(
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
