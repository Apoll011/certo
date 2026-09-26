import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
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
  static const textHint = Color(0xFF4A6A9A);
  static const divider = Color(0xFF243350);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Random AI phrases to speak after transcribing
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
//  Voice session phase
// ─────────────────────────────────────────────────────────────────────────────
enum _VoicePhase { listening, thinking, speaking, idle }

// ─────────────────────────────────────────────────────────────────────────────
//  Entry-point
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showVoiceMode(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => const _VoiceModeSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sheet root
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceModeSheet extends StatefulWidget {
  const _VoiceModeSheet();

  @override
  State<_VoiceModeSheet> createState() => _VoiceModeSheetState();
}

class _VoiceModeSheetState extends State<_VoiceModeSheet>
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
  static const int _barCount = 11;
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

    _orbScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut),
    );
    _orbFloat = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut),
    );

    // Orb morph
    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOut);

    // Waveform bars — each bar has its own looping phase offset
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
      }
    });
    _svc.startListening();
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
        // Give 1.8 seconds of silence after speech before automatically replying
        _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _phase == _VoicePhase.listening) {
            _finishListening();
          }
        });

      case TtsAudioChunk(:final bytes):
        _audioBuffer.addAll(bytes);

      case TtsDone():
        _playBufferedAudio();

      case VoiceError(:final message):
        debugPrint('VoiceMode UI error: $message');
        setState(() {
          _errorText = message;
        });
    }
  }

  Future<void> _finishListening() async {
    if (_phase != _VoicePhase.listening) return;
    _silenceTimer?.cancel();
    setState(() => _phase = _VoicePhase.thinking);
    _waveCtrl.stop();
    await _svc.stopListening();

    final phrase = _randomPhrase();
    setState(() => _aiResponse = phrase);
    await _svc.speak(phrase);
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      debugPrint('VoiceMode: audio buffer is empty');
      setState(() => _phase = _VoicePhase.idle);
      return;
    }

    setState(() => _phase = _VoicePhase.speaking);
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    try {
      final tempFile = File(
        '${Directory.systemTemp.path}/eleven_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(bytes, flush: true);
      debugPrint('VoiceMode: playing via DeviceFileSource (${tempFile.path})');
      await _player.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint('VoiceMode: DeviceFileSource failed ($e), falling back to BytesSource');
      try {
        await _player.play(BytesSource(bytes));
      } catch (err) {
        debugPrint('VoiceMode: BytesSource error: $err');
        if (mounted) setState(() => _phase = _VoicePhase.idle);
      }
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String get _displayTranscript {
    if (_finalText.isNotEmpty && _partialText.isNotEmpty) {
      return '"$_finalText $_partialText"';
    }
    if (_finalText.isNotEmpty) return '"$_finalText"';
    if (_partialText.isNotEmpty) return '"$_partialText"';
    return '';
  }

  String get _phaseLabel {
    if (_errorText != null) return 'Something went wrong';
    return switch (_phase) {
      _VoicePhase.listening => 'Listening...',
      _VoicePhase.thinking => 'Thinking...',
      _VoicePhase.speaking => 'Speaking...',
      _VoicePhase.idle => 'Done',
    };
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _VC.bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _IconBtn(icon: Icons.settings_outlined, onTap: () {}),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // ── orb (tap to commit speech / reply) ─────────────────────────
            GestureDetector(
              onTap: () {
                if (_phase == _VoicePhase.listening) {
                  _finishListening();
                }
              },
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

            const SizedBox(height: 36),

            // ── phase label ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _phaseLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorText != null ? const Color(0xFFFF6B6B) : _VC.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── transcript / AI speech / error display ───────────────────────
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1520),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B263E)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Color(0xFFFFD1D1),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_phase == _VoicePhase.speaking && _aiResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '"$_aiResponse"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _VC.orbHighlight,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              )
            else if (_displayTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _displayTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _VC.textSub,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // ── waveform ───────────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                if (_phase == _VoicePhase.listening) {
                  _finishListening();
                }
              },
              child: _WaveformBars(
                anims: _barAnims,
                active: _phase == _VoicePhase.listening,
              ),
            ),

            const Spacer(flex: 3),

            // ── suggestions card ───────────────────────────────────────────
            const _SuggestionsCard(),

            const SizedBox(height: 24),
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32)
      ..shader = RadialGradient(
        colors: [
          _VC.orbPurple.withValues(alpha: 0.55),
          _VC.orbBlue.withValues(alpha: 0.15),
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
  'Scan this medication',
  'Read the instructions',
  'Mark it as taken',
  'When do I take Amoxicillin?',
];

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
                  Icons.help_outline_rounded,
                  color: _VC.textSub,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'You can also say:',
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
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _VC.textHint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s,
                      style: const TextStyle(
                        color: _VC.textSub,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
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
//  Small icon button (top-bar close / settings)
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _VC.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: _VC.divider),
        ),
        child: Icon(icon, color: _VC.textSub, size: 18),
      ),
    );
  }
}
