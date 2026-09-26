import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'medication_detail_screen.dart';

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

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.myMedications, style: AppTheme.headerLarge),
              ),
              CircleIconButton(
                icon: Icons.add_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddMedicationScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          if (list.isEmpty)
            _filter == null
                ? EmptyState(
                    icon: Icons.medication_outlined,
                    title: l10n.noMedicationsTitle,
                    subtitle: l10n.noMedicationsBody,
                    actionLabel: l10n.addMedication,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddMedicationScreen(),
                      ),
                    ),
                  )
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.emptyFilterTitle,
                    subtitle: l10n.emptyFilterBody,
                    iconColor: AppColors.info,
                    iconBackground: AppColors.infoSoft,
                  )
          else
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MedicationCard(
                  medication: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MedicationDetailScreen(medicationId: m.id),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.dosageLine, style: AppTheme.bodyMedium),
                      const SizedBox(height: 5),
                      Text(
                        m.timesLine,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E2EA),
          ),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
