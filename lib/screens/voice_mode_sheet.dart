import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/elevenlabs_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens – dark navy voice palette matching mockup
// ─────────────────────────────────────────────────────────────────────────────
class _VC {
  static const bg = Color(0xFF0D1B2E);
  static const bgCard = Color(0xFF182438);
  static const orbBlue = Color(0xFF8EC5FC);
  static const orbPurple = Color(0xFFAB8FF0);
  static const orbPink = Color(0xFFE0C3FC);
  static const orbHighlight = Color(0xFFD6EEFF);
  static const waveActive = Color(0xFF4C7CF4);
  static const waveIdle = Color(0xFF2A3E66);
  static const textPrimary = Colors.white;
  static const textSub = Color(0xFF7B9CC5);
  static const divider = Color(0xFF243350);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Voice session phase
// ─────────────────────────────────────────────────────────────────────────────
enum _VoicePhase { listening, thinking, speaking, idle }

// ─────────────────────────────────────────────────────────────────────────────
//  Entry-point: Opens Voice Mode as a full-page route
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showVoiceMode(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const VoiceModeScreen(),
      fullscreenDialog: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Full-page Voice Mode Screen
// ─────────────────────────────────────────────────────────────────────────────
class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with TickerProviderStateMixin {
  // ── services ────────────────────────────────────────────────────────────
  late final ElevenLabsService _svc;
  StreamSubscription<VoiceEvent>? _eventSub;
  StreamSubscription? _playerCompleteSub;
  final AudioPlayer _player = AudioPlayer();

  // ── session state ────────────────────────────────────────────────────────
  _VoicePhase _phase = _VoicePhase.listening;
  String _partialText = '';
  String _finalText = '';
  String _aiResponse = '';
  String? _errorText;
  final List<int> _audioBuffer = [];
  Timer? _silenceTimer;

  // ── orb animation: gentle float + scale ──────────────────────────────────
  late final AnimationController _orbCtrl;
  late final Animation<double> _orbScale;
  late final Animation<double> _orbFloat;

  // ── waveform bars animation ───────────────────────────────────────────────
  late final AnimationController _waveCtrl;
  static const int _barCount = 13;
  late final List<Animation<double>> _barAnims;

  // ── orb morph animation (idle shape shift) ───────────────────────────────
  late final AnimationController _morphCtrl;
  late final Animation<double> _morphAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVoice();
  }

  void _initAnimations() {
    // Orb breathe / float
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _orbScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut),
    );
    _orbFloat = Tween<double>(begin: -7, end: 7).animate(
      CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut),
    );

    // Orb morph
    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOut);

    // Waveform bars
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    final rand = Random(42);
    _barAnims = List.generate(_barCount, (i) {
      final minH = 0.12 + rand.nextDouble() * 0.1;
      final maxH = 0.45 + rand.nextDouble() * 0.55;
      final begin = i.isEven ? minH : maxH;
      final end = i.isEven ? maxH : minH;
      return Tween<double>(begin: begin, end: end).animate(
        CurvedAnimation(
          parent: _waveCtrl,
          curve: Interval(
            (i / _barCount) * 0.5,
            ((i / _barCount) * 0.5) + 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  void _initVoice() {
    _svc = ElevenLabsService();
    _eventSub = _svc.events.listen(_onEvent);
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _phase = _VoicePhase.idle);
        _waveCtrl.stop();
      }
    });
    _startListening();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _orbCtrl.dispose();
    _morphCtrl.dispose();
    _waveCtrl.dispose();
    _eventSub?.cancel();
    _playerCompleteSub?.cancel();
    _svc.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── event handler ────────────────────────────────────────────────────────
  void _onEvent(VoiceEvent event) {
    if (!mounted) return;
    switch (event) {
      case TranscriptionPartial(:final text):
        _silenceTimer?.cancel();
        setState(() {
          _partialText = text;
          _errorText = null;
        });

      case TranscriptionFinal(:final text):
        _silenceTimer?.cancel();
        if (text.trim().isEmpty) return;
        setState(() {
          _finalText = (_finalText.isEmpty ? '' : '$_finalText ') + text.trim();
          _partialText = '';
          _errorText = null;
        });
        // 1.8s of silence after speech commits before speaking back
        _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _phase == _VoicePhase.listening) {
            _finishListeningAndSpeak();
          }
        });

      case TtsAudioChunk(:final bytes):
        _audioBuffer.addAll(bytes);

      case TtsDone():
        _playBufferedAudio();

      case VoiceError(:final message):
        debugPrint('VoiceMode UI error: $message');
        if (mounted) {
          setState(() {
            _phase = _VoicePhase.idle;
            _errorText = message;
          });
          _waveCtrl.stop();
        }
    }
  }

  Future<void> _startListening() async {
    try {
      await _player.stop();
    } catch (_) {}
    _silenceTimer?.cancel();
    _audioBuffer.clear();

    if (mounted) {
      setState(() {
        _phase = _VoicePhase.listening;
        _finalText = '';
        _partialText = '';
        _aiResponse = '';
        _errorText = null;
      });
      _waveCtrl.repeat(reverse: true);
    }
    await _svc.startListening();
  }

  Future<void> _finishListeningAndSpeak() async {
    if (_phase != _VoicePhase.listening) return;
    _silenceTimer?.cancel();
    setState(() => _phase = _VoicePhase.thinking);
    _waveCtrl.stop();

    await _svc.stopListening();

    final spoken = _finalText.trim().isNotEmpty
        ? _finalText.trim()
        : _partialText.trim();

    if (spoken.isEmpty) {
      if (mounted) {
        setState(() {
          _phase = _VoicePhase.idle;
          _errorText = 'No speech detected. Tap the orb to try speaking again.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _aiResponse = spoken;
      });
    }

    // Speak back what was transcribed
    await _svc.speak(spoken);
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      debugPrint('VoiceMode: audio buffer is empty');
      if (mounted) {
        setState(() => _phase = _VoicePhase.idle);
      }
      return;
    }

    if (mounted) {
      setState(() => _phase = _VoicePhase.speaking);
      _waveCtrl.repeat(reverse: true);
    }
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    try {
      if (kIsWeb) {
        await _player.play(BytesSource(bytes));
      } else {
        try {
          final tempFile = File(
            '${Directory.systemTemp.path}/eleven_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          debugPrint('VoiceMode: playing via DeviceFileSource (${tempFile.path})');
          await _player.play(DeviceFileSource(tempFile.path));
        } catch (fileErr) {
          debugPrint('VoiceMode: File play failed ($fileErr), trying BytesSource');
          await _player.play(BytesSource(bytes));
        }
      }
    } catch (e) {
      debugPrint('VoiceMode: Audio playback error: $e');
      if (mounted) {
        setState(() {
          _phase = _VoicePhase.idle;
          _errorText = 'Playback error: $e';
        });
        _waveCtrl.stop();
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _phase = _VoicePhase.idle);
      _waveCtrl.stop();
    }
  }

  void _onOrbTap() {
    switch (_phase) {
      case _VoicePhase.listening:
        _finishListeningAndSpeak();
      case _VoicePhase.speaking:
        _stopSpeaking();
      case _VoicePhase.thinking:
        break;
      case _VoicePhase.idle:
        _startListening();
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String get _displayTranscript {
    if (_finalText.isNotEmpty && _partialText.isNotEmpty) {
      return '$_finalText $_partialText';
    }
    if (_finalText.isNotEmpty) return _finalText;
    if (_partialText.isNotEmpty) return _partialText;
    return '';
  }

  String get _phaseLabel {
    if (_errorText != null) return 'Ready to listen';
    return switch (_phase) {
      _VoicePhase.listening => 'Listening...',
      _VoicePhase.thinking => 'Processing speech...',
      _VoicePhase.speaking => 'Speaking back...',
      _VoicePhase.idle => 'Tap orb to speak',
    };
  }

  Color get _phaseBadgeColor {
    return switch (_phase) {
      _VoicePhase.listening => const Color(0xFF4C7CF4),
      _VoicePhase.thinking => const Color(0xFFEAA034),
      _VoicePhase.speaking => const Color(0xFF2EC4B6),
      _VoicePhase.idle => const Color(0xFF7B9CC5),
    };
  }

  String get _phaseBadgeText {
    return switch (_phase) {
      _VoicePhase.listening => 'LIVE MIC',
      _VoicePhase.thinking => 'THINKING',
      _VoicePhase.speaking => 'SPEAKING BACK',
      _VoicePhase.idle => 'STANDBY',
    };
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isStreamingActive =
        _phase == _VoicePhase.listening || _phase == _VoicePhase.speaking;

    return Scaffold(
      backgroundColor: _VC.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top header bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Voice Assistant',
                    style: TextStyle(
                      color: _VC.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _phaseBadgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _phaseBadgeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _phaseBadgeColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _phaseBadgeText,
                          style: TextStyle(
                            color: _phaseBadgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── Glass Orb (interactive) ───────────────────────────
                    GestureDetector(
                      onTap: _onOrbTap,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_orbCtrl, _morphCtrl]),
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _orbFloat.value),
                          child: Transform.scale(
                            scale: _orbScale.value,
                            child: _GlassOrb(morphT: _morphAnim.value),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── Phase label ───────────────────────────────────────
                    Text(
                      _phaseLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VC.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subtitle guidance
                    Text(
                      _phase == _VoicePhase.listening
                          ? 'Speak naturally or tap the orb when done'
                          : _phase == _VoicePhase.speaking
                              ? 'ElevenLabs TTS echoing your speech'
                              : _phase == _VoicePhase.thinking
                                  ? 'Synthesizing voice response...'
                                  : 'Tap orb or the button below to start',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VC.textSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Waveform bars ─────────────────────────────────────
                    GestureDetector(
                      onTap: _onOrbTap,
                      child: _WaveformBars(
                        anims: _barAnims,
                        active: isStreamingActive,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Speech Transcription / Echo Box ───────────────────
                    if (_errorText != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B1520),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8B263E)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF6B6B),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  color: Color(0xFFFFD1D1),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_phase == _VoicePhase.speaking && _aiResponse.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _VC.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _VC.orbPurple.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.volume_up_rounded,
                                  color: _VC.orbPurple,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Speaking back what you said:',
                                  style: TextStyle(
                                    color: _VC.orbPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"$_aiResponse"',
                              style: const TextStyle(
                                color: _VC.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_displayTranscript.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _VC.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _VC.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _phase == _VoicePhase.listening
                                      ? Icons.mic_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: _VC.waveActive,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _phase == _VoicePhase.listening
                                      ? 'Live Transcription:'
                                      : 'You said:',
                                  style: const TextStyle(
                                    color: _VC.textSub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"$_displayTranscript"',
                              style: const TextStyle(
                                color: _VC.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Bottom Action Button ──────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _phase == _VoicePhase.listening
                              ? const Color(0xFF2A3E66)
                              : _phase == _VoicePhase.speaking
                                  ? const Color(0xFF6E2837)
                                  : _VC.waveActive,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _onOrbTap,
                        icon: Icon(
                          _phase == _VoicePhase.listening
                              ? Icons.stop_rounded
                              : _phase == _VoicePhase.speaking
                                  ? Icons.volume_off_rounded
                                  : Icons.mic_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _phase == _VoicePhase.listening
                              ? 'Finish Speaking'
                              : _phase == _VoicePhase.speaking
                                  ? 'Stop Audio'
                                  : 'Tap to Speak',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Suggestions card ──────────────────────────────────
                    const _SuggestionsCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Glass Orb
// ─────────────────────────────────────────────────────────────────────────────

class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.morphT});

  final double morphT;

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrbPainter(morphT: morphT),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.morphT});
  final double morphT;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
      ..shader = RadialGradient(
        colors: [
          _VC.orbPurple.withValues(alpha: 0.55),
          _VC.orbBlue.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.25));
    canvas.drawCircle(Offset(cx, cy), r * 1.25, glowPaint);

    // Main sphere body — radial gradient
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.0,
        colors: const [
          _VC.orbHighlight,
          _VC.orbBlue,
          _VC.orbPurple,
          Color(0xFFCDA8F5),
          _VC.orbPink,
        ],
        stops: const [0.0, 0.25, 0.55, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, bodyPaint);

    // Inner specular blob (morphing) — top-left light catch
    final t = morphT;
    final blobPath = Path();
    final bx = cx - r * 0.18 + t * r * 0.08;
    final by = cy - r * 0.22 - t * r * 0.06;
    final br = r * (0.30 + t * 0.06);
    blobPath.addOval(Rect.fromCenter(
      center: Offset(bx, by),
      width: br * 1.45,
      height: br,
    ));
    final specPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.55 - t * 0.1),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(bx, by),
        width: br * 2,
        height: br * 2,
      ));
    canvas.drawPath(blobPath, specPaint);

    // Secondary specular — lower-right subtle
    final specPaint2 = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..shader = RadialGradient(
        colors: [
          _VC.orbPink.withValues(alpha: 0.4 + t * 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx + r * 0.3, cy + r * 0.28),
        width: r,
        height: r,
      ));
    canvas.drawCircle(Offset(cx + r * 0.3, cy + r * 0.28), r * 0.35, specPaint2);

    // Edge rim highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
        startAngle: -pi / 4,
        endAngle: 2 * pi - pi / 4,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r - 0.75, rimPaint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.morphT != morphT;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated waveform bars
// ─────────────────────────────────────────────────────────────────────────────

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.anims, required this.active});

  final List<Animation<double>> anims;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const maxH = 48.0;
    const barW = 3.5;
    const gap = 4.5;

    return AnimatedBuilder(
      animation: anims.first,
      builder: (_, child) {
        return SizedBox(
          height: maxH,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(anims.length, (i) {
              final h = active
                  ? (anims[i].value * maxH).clamp(4.0, maxH)
                  : 4.0;
              return Padding(
                padding: EdgeInsets.only(right: i < anims.length - 1 ? gap : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: barW,
                  height: h,
                  decoration: BoxDecoration(
                    color: active ? _VC.waveActive : _VC.waveIdle,
                    borderRadius: BorderRadius.circular(barW / 2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  "You can also say" card
// ─────────────────────────────────────────────────────────────────────────────

const _suggestions = [
  'I took my morning medication',
  'When is my next dose of Amoxicillin?',
  'Remind me to take Vitamin D at 8 PM',
  'What medications do I have today?',
];

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _VC.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _VC.divider, width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: _VC.orbHighlight,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Try saying:',
                style: TextStyle(
                  color: _VC.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _VC.waveActive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: _VC.textSub,
                        fontSize: 13,
                        height: 1.4,
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small icon button (top bar back / action)
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _VC.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: _VC.divider),
        ),
        child: Icon(icon, color: _VC.textPrimary, size: 18),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
