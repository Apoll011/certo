import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../widgets/pill_icon.dart';
import '../widgets/primary_button.dart';

/// Full-screen "ringing" alarm, shown when the OS notification is tapped.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.medication, this.dueTime});

  final Medication medication;

  /// The scheduled clock time (e.g. "9:00 AM"), or null to infer it.
  final String? dueTime;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.9,
    upperBound: 1.1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = context.watch<AppState>();
    final med = widget.medication;
    final timeLabel = _clockLabel(l10n);

    return Scaffold(
      backgroundColor: AppColors.alarmBackground,
      body: Stack(
        children: [
          // Dim clock backdrop.
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fullDate(DateTime.now(), locale),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 120,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.dangerSoft,
                        ),
                        child: const Icon(
                          Icons.alarm_rounded,
                          color: AppColors.danger,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.alarmTitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.headerMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.scheduledFor(_clockDisplay(l10n)),
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          PillIcon(colorIndex: med.pillColorIndex, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.name, style: AppTheme.titleMedium),
                                const SizedBox(height: 3),
                                Text(
                                  med.dosageLine,
                                  style: AppTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: l10n.taken,
                      icon: Icons.check_rounded,
                      onPressed: () {
                        state.markTaken(med.id);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: l10n.snooze,
                      icon: Icons.snooze_rounded,
                      filled: false,
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        await state.snooze(med.id);
                        if (!mounted) return;
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.snoozed),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        navigator.pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _clockLabel(AppLocalizations l10n) {
    final t = widget.dueTime ?? med.firstTime;
    if (isMealToken(t)) {
      final minutes = resolveTimeMinutes(t);
      return clock12(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
    }
    return t;
  }

  String _clockDisplay(AppLocalizations l10n) =>
      displayTime(widget.dueTime ?? med.firstTime, l10n);

  Medication get med => widget.medication;
}
