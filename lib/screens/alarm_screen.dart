import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/medication.dart';
import '../services/alarm_sound_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import '../widgets/pill_icon.dart';

/// Full-screen "ringing" alarm, shown when the OS fires a dose notification
/// (including a full-screen intent on Android, even over the lock screen or
/// when the app was not running).
///
/// Styled like a stock clock alarm: a large live clock, a prominent "Take
/// dose" dismiss action and configurable snooze, while the chosen alarm
/// ringtone loops on the Android alarm audio stream (so it rings even in
/// silent/vibrate mode).
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
  static const List<int> _snoozeOptions = [5, 10, 15];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.92,
    upperBound: 1.08,
  );

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  String? _alarmUri;

  /// Guards against double-taps on Take/Snooze.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Keep the alarm over the status/navigation bars and the screen awake.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _alarmUri = context.read<AppState>().alarmSoundUri;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.value = 1.0;
    }
    _startRinging();
  }

  Future<void> _startRinging() async {
    try {
      // Play on the alarm stream; null uri = device default alarm sound.
      await AlarmSoundService.play(_alarmUri);
    } catch (e) {
      debugPrint('Verifi: alarm sound failed — $e');
    }
  }

  Future<void> _stopRinging() async {
    await AlarmSoundService.stop();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    _stopRinging();
    AlarmSoundService.dismissAlarmNotification();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final med = widget.medication;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.alarmBackground,
        body: Stack(
          children: [
            const Positioned.fill(child: _AlarmGlow()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    _liveClock(l10n),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _alarmHeader(l10n),
                              const SizedBox(height: 28),
                              _medicationCard(l10n, med),
                              const SizedBox(height: 14),
                              Text(
                                l10n.scheduledFor(_clockDisplay(l10n)),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _takeDoseButton(l10n, state, med),
                    const SizedBox(height: 12),
                    _snoozeRow(l10n, state),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _liveClock(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;
    final is24 = MediaQuery.of(context).alwaysUse24HourFormat;
    final time = DateFormat(is24 ? 'HH:mm' : 'h:mm').format(_now);
    final ampm = is24 ? '' : DateFormat('a', locale).format(_now);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 76,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            if (ampm.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                ampm,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          fullDate(_now, locale),
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _alarmHeader(AppLocalizations l10n) {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.alarm_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.alarmRinging,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.alarmTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _medicationCard(AppLocalizations l10n, Medication med) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          PillIcon(
            colorIndex: med.pillColorIndex,
            size: 48,
            color1: Colors.white,
            color2: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  med.dosageLine,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _takeDoseButton(
    AppLocalizations l10n,
    AppState state,
    Medication med,
  ) {
    return SizedBox(
      height: 62,
      child: FilledButton.icon(
        onPressed: _handled
            ? null
            : () {
                _handled = true;
                _stopRinging();
                state.markTaken(med.id);
                Navigator.of(context).pop();
              },
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.alarmBackground,
          disabledBackgroundColor: Colors.white,
          disabledForegroundColor: AppColors.alarmBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: const Icon(Icons.check_rounded, size: 26),
        label: Text(
          l10n.takeDose,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _snoozeRow(AppLocalizations l10n, AppState state) {
    return Row(
      children: [
        for (var i = 0; i < _snoozeOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _snoozeButton(l10n, state, _snoozeOptions[i])),
        ],
      ],
    );
  }

  Widget _snoozeButton(AppLocalizations l10n, AppState state, int minutes) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _handled ? null : () => _snooze(l10n, state, minutes),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          l10n.snoozeMinutes(minutes),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _snooze(
    AppLocalizations l10n,
    AppState state,
    int minutes,
  ) async {
    _handled = true;
    _stopRinging();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await state.snooze(widget.medication.id, minutes: minutes, time: widget.dueTime);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.snoozedFor(minutes)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    navigator.pop();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _clockDisplay(AppLocalizations l10n) =>
      displayTime(widget.dueTime ?? med.firstTime, l10n);

  Medication get med => widget.medication;
}

/// Subtle radial glow behind the alarm content for depth on the dark canvas.
class _AlarmGlow extends StatelessWidget {
  const _AlarmGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              AppColors.secondary.withValues(alpha: 0.4),
              AppColors.alarmBackground,
              AppColors.alarmBackground,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}
