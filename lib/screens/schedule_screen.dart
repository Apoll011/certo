import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/medication_card.dart';
import '../widgets/taken_checkbox.dart';
import 'medication_detail_screen.dart';

/// Schedule tab — day-by-day view grouped by time of day.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i)));

    final active = state.medications
        .where((m) => m.status == MedicationStatus.active)
        .toList();

    final morning =
        active.where((m) => hourFromTime(m.times.first) < 12).toList();
    final afternoon = active
        .where((m) {
          final h = hourFromTime(m.times.first);
          return h >= 12 && h < 17;
        })
        .toList();
    final evening =
        active.where((m) => hourFromTime(m.times.first) >= 17).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text('Schedule', style: AppTheme.headerLarge),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (var i = 0; i < days.length; i++)
                  _dayPill(days[i], selected: i == _selectedDay, index: i),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _section(context, 'MORNING', morning),
                _section(context, 'AFTERNOON', afternoon),
                _section(context, 'EVENING', evening),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayPill(DateTime day, {required bool selected, required int index}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = index),
      child: Container(
        width: 52,
        height: 60,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE2E2EA)),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortWeekday(day),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label, List<Medication> meds) {
    if (meds.isEmpty) return const SizedBox.shrink();
    final state = context.read<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final m in meds)
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
    );
  }
}
