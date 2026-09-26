import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/app_card.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/medication_card.dart';
import '../widgets/taken_checkbox.dart';
import 'alarm_screen.dart';
import 'medication_detail_screen.dart';

/// Home tab — today's checklist.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();
    final next = active.isNotEmpty ? active.first : null;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.greeting(state.userName),
                      style: AppTheme.headerLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullDate(DateTime.now(), locale),
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.settings_outlined,
                onTap: () => showComingSoon(context, l10n.settings),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            onTap: next != null
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlarmScreen(medication: next),
                      ),
                    )
                : null,
            color: AppColors.primary,
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.timeForMedication,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${l10n.medicationCount(active.length)} · '
                        '${next?.times.first ?? '9:00 AM'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.today, style: AppTheme.sectionLabel),
          const SizedBox(height: 12),
          for (final m in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MedicationCard(
                medication: m,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedicationDetailScreen(medicationId: m.id),
                  ),
                ),
                trailing: TakenCheckbox(
                  taken: state.isTaken(m.id),
                  onToggle: () => state.toggleTaken(m.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
