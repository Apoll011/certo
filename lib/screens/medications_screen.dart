import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../utils/schedule.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import '../widgets/screen_header.dart';
import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';
import '../web/demo_nav.dart';

/// Meds tab — browse and filter all medications.
class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  MedicationStatus? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final list = state.medicationsWithStatus(_filter);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ScreenHeader(
            title: l10n.myMedications,
            large: true,
            trailing: CircleIconButton(
              icon: Icons.add_rounded,
              tooltip: l10n.addMedication,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: DemoRoutes.addMedication),
                  builder: (_) => const AddMedicationScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(l10n.filterAll, null),
                _filterChip(l10n.filterActive, MedicationStatus.active),
                _filterChip(l10n.filterPaused, MedicationStatus.paused),
                _filterChip(l10n.filterFinished, MedicationStatus.finished),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (list.isEmpty)
            _filter == null
                ? EmptyState(
                    icon: Icons.medication_outlined,
                    title: l10n.noMedicationsTitle,
                    subtitle: l10n.noMedicationsBody,
                    actionLabel: l10n.addMedication,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: DemoRoutes.addMedication),
                        builder: (_) => const AddMedicationScreen(),
                      ),
                    ),
                  )
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.emptyFilterTitle,
                    subtitle: l10n.emptyFilterBody,
                    iconColor: scheme.secondary,
                    iconBackground: scheme.secondaryContainer,
                  )
          else
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MedicationCard(
                  medication: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: DemoRoutes.medicationDetail),
                      builder: (_) =>
                          MedicationDetailScreen(medicationId: m.id),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.dosageLine, style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        displayTimes(m.times, l10n),
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, MedicationStatus? value) {
    final selected = _filter == value;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        labelStyle: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline,
        ),
        showCheckmark: false,
      ),
    );
  }
}
