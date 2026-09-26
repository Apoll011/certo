import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/elevenlabs_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_orb.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Random responses the AI speaks after transcription.
// ─────────────────────────────────────────────────────────────────────────────
const _randomPhrases = [
  "Got it! I'll keep that in mind for your next dose.",
  "Interesting — your medication routine sounds well-organised!",
  "No worries, I'm here whenever you need a reminder.",
  "That's great to hear! Staying consistent with meds really matters.",
  "Sounds good! Let me know if there's anything I can help you with.",
  "I heard you loud and clear. You're doing great!",
  "Consider it noted. Taking care of your health is the best investment.",
  "Absolutely! I'm always here to help you stay on track.",
  "Perfect timing! Remember, your next dose is coming up soon.",
  "Thanks for checking in — you're on top of things!",
];

String _randomPhrase() =>
    _randomPhrases[Random().nextInt(_randomPhrases.length)];

// ─────────────────────────────────────────────────────────────────────────────
//  Voice session state
// ─────────────────────────────────────────────────────────────────────────────
enum _VoicePhase {
  listening, // mic open, transcribing
  thinking, // got final transcript, building TTS
  speaking, // playing audio
  idle, // done
}

// ─────────────────────────────────────────────────────────────────────────────
//  Entry-point helper
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the voice mode as a full-screen modal bottom sheet.
Future<void> showVoiceMode(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceModeSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _VoiceModeSheet
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceModeSheet extends StatefulWidget {
  const _VoiceModeSheet();

  @override
  State<_VoiceModeSheet> createState() => _VoiceModeSheetState();
}

class _VoiceModeSheetState extends State<_VoiceModeSheet>
    with SingleTickerProviderStateMixin {
  late final ElevenLabsService _svc;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  StreamSubscription<VoiceEvent>? _eventSub;

  final AudioPlayer _player = AudioPlayer();

  _VoicePhase _phase = _VoicePhase.listening;
  String _partialText = '';
  String _finalText = '';
  String _aiResponse = '';
  String? _errorText;

  // Buffer streaming TTS bytes
  final List<int> _audioBuffer = [];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _svc = ElevenLabsService();
    _eventSub = _svc.events.listen(_onEvent);
    _svc.startListening();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _eventSub?.cancel();
    _svc.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── event handler ──────────────────────────────────────────────────────────

  void _onEvent(VoiceEvent event) {
    if (!mounted) return;
    switch (event) {
      case TranscriptionPartial(:final text):
        setState(() => _partialText = text);

      case TranscriptionFinal(:final text):
        if (text.trim().isEmpty) return;
        setState(() {
          _finalText = (_finalText.isEmpty ? '' : '$_finalText ') + text;
          _partialText = '';
        });
        // After receiving final transcript, stop listening and generate TTS.
        _finishListening();

      case TtsAudioChunk(:final bytes):
        _audioBuffer.addAll(bytes);

      case TtsDone():
        _playBufferedAudio();

      case VoiceError(:final message):
        setState(() {
          _errorText = message;
          _phase = _VoicePhase.idle;
        });
        _pulseCtrl.stop();
    }
  }

  Future<void> _finishListening() async {
    if (_phase != _VoicePhase.listening) return;
    setState(() => _phase = _VoicePhase.thinking);
    await _svc.stopListening();

    // Pick a random phrase and speak it.
    final phrase = _randomPhrase();
    setState(() => _aiResponse = phrase);
    await _svc.speak(phrase);
  }

  Future<void> _playBufferedAudio() async {
    setState(() => _phase = _VoicePhase.speaking);
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();
    await _player.play(BytesSource(bytes));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _phase = _VoicePhase.idle);
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.alarmBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── drag handle ──
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Spacer(),

            // ── orb ─────────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _phase == _VoicePhase.listening ? _pulse.value : 1.0,
                child: child,
              ),
              child: GradientOrb(
                size: 180,
                blur: 60,
                spread: 20,
                child: Center(
                  child: Icon(
                    _orbIcon(),
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 64,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── phase label ─────────────────────────────────────────────────
            Text(
              _phaseLabel(),
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // ── transcription / response area ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // Live / final transcription
                  if (_finalText.isNotEmpty || _partialText.isNotEmpty)
                    _BubbleCard(
                      icon: Icons.mic_rounded,
                      color: AppColors.primarySoft,
                      textColor: AppColors.textPrimary,
                      text: _finalText.isNotEmpty
                          ? _finalText
                          : _partialText,
                      isPartial: _finalText.isEmpty && _partialText.isNotEmpty,
                    ),

                  if (_finalText.isNotEmpty && _aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BubbleCard(
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.successSoft,
                      textColor: AppColors.textPrimary,
                      text: _aiResponse,
                      isPartial: _phase == _VoicePhase.thinking,
                    ),
                  ],

                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    _BubbleCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.dangerSoft,
                      textColor: AppColors.danger,
                      text: _errorText!,
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // ── bottom action ────────────────────────────────────────────────
            _BottomAction(phase: _phase, onStop: _finishListening),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _orbIcon() {
    return switch (_phase) {
      _VoicePhase.listening => Icons.mic_rounded,
      _VoicePhase.thinking => Icons.hourglass_top_rounded,
      _VoicePhase.speaking => Icons.volume_up_rounded,
      _VoicePhase.idle => Icons.check_circle_outline_rounded,
    };
  }

  String _phaseLabel() {
    return switch (_phase) {
      _VoicePhase.listening => 'LISTENING',
      _VoicePhase.thinking => 'THINKING',
      _VoicePhase.speaking => 'SPEAKING',
      _VoicePhase.idle => 'DONE',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.icon,
    required this.color,
    required this.textColor,
    required this.text,
    this.isPartial = false,
  });

  final IconData icon;
  final Color color;
  final Color textColor;
  final String text;
  final bool isPartial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPartial ? '$text…' : text,
              style: TextStyle(
                color: textColor.withValues(alpha: isPartial ? 0.6 : 1.0),
                fontSize: 16,
                fontStyle:
                    isPartial ? FontStyle.italic : FontStyle.normal,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.phase, required this.onStop});

  final _VoicePhase phase;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    if (phase == _VoicePhase.listening) {
      return GestureDetector(
        onTap: onStop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Stop Listening',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (phase == _VoicePhase.idle) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Thinking / speaking — show a spinner.
    return const SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        color: AppColors.secondary,
        strokeWidth: 3,
      ),
    );
  }
}
