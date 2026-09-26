import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai.dart';
import '../config/app_config.dart';
import '../services/elevenlabs_service.dart';
import '../state/app_state.dart';
import 'visual_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _VC {
  static const bg = Color(0xFF0D1B2E);
  static const bgCard = Color(0xFF182438);
  static const orbBlue = Color(0xFF8EC5FC);
  static const orbPurple = Color(0xFFAB8FF0);
  static const orbPink = Color(0xFFE0C3FC);
  static const orbHighlight = Color(0xFFD6EEFF);
  static const userBubble = Color(0xFF243350);
  static const aiBubble = Color(0xFF1E3A5F);
  static const textPrimary = Colors.white;
  static const textSub = Color(0xFF7B9CC5);
  static const divider = Color(0xFF243350);
}

enum VoiceModeIntent { general, addMedication }

enum _VoicePhase { listening, thinking, speaking, idle }

class _ChatBubble {
  const _ChatBubble({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

/// Opens Voice Mode as a full-page route.
Future<void> showVoiceMode(
  BuildContext context, {
  VoiceModeIntent intent = VoiceModeIntent.general,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => VoiceModeScreen(intent: intent),
      fullscreenDialog: true,
    ),
  );
}

class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({
    super.key,
    this.intent = VoiceModeIntent.general,
  });

  final VoiceModeIntent intent;

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with TickerProviderStateMixin {
  /// After VAD commits a segment, wait this long for the user to continue
  /// speaking (breath / pause mid-thought) before calling the AI.
  static const _endOfTurnGrace = Duration(milliseconds: 700);

  late final ElevenLabsService _svc;
  StreamSubscription<VoiceEvent>? _eventSub;
  StreamSubscription? _playerCompleteSub;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _chatScroll = ScrollController();

  _VoicePhase _phase = _VoicePhase.idle;
  String _partialText = '';
  String _finalText = '';
  String? _errorText;
  final List<int> _audioBuffer = [];
  Timer? _endOfTurnTimer;
  Completer<void>? _speakDone;

  /// Conversation history sent to the AI (no system messages).
  final List<ChatMessage> _history = [];

  /// UI chat bubbles (user + assistant).
  final List<_ChatBubble> _bubbles = [];

  bool _bootstrapped = false;
  bool _turnInFlight = false;

  late final AnimationController _orbCtrl;
  late final Animation<double> _orbScale;
  late final Animation<double> _orbFloat;
  late final AnimationController _morphCtrl;
  late final Animation<double> _morphAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVoice();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _initAnimations() {
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

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOut);
  }

  void _initVoice() {
    _svc = ElevenLabsService();
    _eventSub = _svc.events.listen(_onEvent);
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      _onPlaybackComplete();
    });
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    if (!AppConfig.hasAiApiKey) {
      setState(() {
        _errorText =
            'DeepSeek API key missing. Add AI_API_KEY to .env and run with --dart-define-from-file=.env';
        _phase = _VoicePhase.idle;
      });
      return;
    }

    if (widget.intent == VoiceModeIntent.addMedication) {
      await _runAiTurn(
        AiAssistantService.addMedicationKickoffPrompt(),
        showUserBubble: false,
      );
    } else {
      await _startListening();
    }
  }

  @override
  void dispose() {
    _endOfTurnTimer?.cancel();
    _orbCtrl.dispose();
    _morphCtrl.dispose();
    _chatScroll.dispose();
    _eventSub?.cancel();
    _playerCompleteSub?.cancel();
    _svc.dispose();
    _player.dispose();
    if (_speakDone != null && !_speakDone!.isCompleted) {
      _speakDone!.complete();
    }
    super.dispose();
  }

  // ── STT events ───────────────────────────────────────────────────────────
  // End-of-turn is driven by ElevenLabs VAD (committed_transcript), not a
  // fixed wall-clock silence timer. Partials only mean "still speaking".
  void _onEvent(VoiceEvent event) {
    if (!mounted) return;
    switch (event) {
      case TranscriptionPartial(:final text):
        if (_phase != _VoicePhase.listening) return;
        // User is mid-utterance — cancel any pending end-of-turn.
        _endOfTurnTimer?.cancel();
        setState(() {
          _partialText = text;
          _errorText = null;
        });

      case TranscriptionFinal(:final text):
        // VAD detected the user stopped speaking for this segment.
        if (_phase != _VoicePhase.listening) return;
        if (text.trim().isEmpty) return;
        setState(() {
          _finalText =
              (_finalText.isEmpty ? '' : '$_finalText ') + text.trim();
          _partialText = '';
          _errorText = null;
        });
        // Brief grace so a short breath mid-sentence can continue.
        _endOfTurnTimer?.cancel();
        _endOfTurnTimer = Timer(_endOfTurnGrace, () {
          if (mounted && _phase == _VoicePhase.listening) {
            _finishListeningAndCallAi();
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
        }
        if (_speakDone != null && !_speakDone!.isCompleted) {
          _speakDone!.complete();
        }
    }
  }

  void _onPlaybackComplete() {
    if (_speakDone != null && !_speakDone!.isCompleted) {
      _speakDone!.complete();
    }
    if (mounted && _phase == _VoicePhase.speaking && !_turnInFlight) {
      setState(() => _phase = _VoicePhase.idle);
    }
  }

  Future<void> _startListening() async {
    try {
      await _player.stop();
    } catch (_) {}
    _endOfTurnTimer?.cancel();
    _audioBuffer.clear();

    if (!mounted) return;
    setState(() {
      _phase = _VoicePhase.listening;
      _finalText = '';
      _partialText = '';
      _errorText = null;
    });
    await _svc.startListening();
  }

  Future<void> _finishListeningAndCallAi() async {
    if (_phase != _VoicePhase.listening || _turnInFlight) return;
    _endOfTurnTimer?.cancel();

    final spoken = _finalText.trim().isNotEmpty
        ? _finalText.trim()
        : _partialText.trim();

    await _svc.stopListening();

    if (spoken.isEmpty) {
      if (mounted) {
        setState(() {
          _phase = _VoicePhase.idle;
          _errorText = 'No speech detected. Tap the orb to try again.';
        });
      }
      return;
    }

    await _runAiTurn(spoken, showUserBubble: true);
  }

  Future<void> _runAiTurn(
    String userText, {
    required bool showUserBubble,
  }) async {
    if (_turnInFlight || !mounted) return;
    _turnInFlight = true;

    if (showUserBubble) {
      setState(() {
        _bubbles.add(_ChatBubble(isUser: true, text: userText));
        _phase = _VoicePhase.thinking;
        _errorText = null;
      });
      _scrollChatToEnd();
    } else {
      setState(() {
        _phase = _VoicePhase.thinking;
        _errorText = null;
      });
    }

    if (!AppConfig.hasAiApiKey) {
      setState(() {
        _errorText = 'DeepSeek API key missing (AI_API_KEY).';
        _phase = _VoicePhase.idle;
      });
      _turnInFlight = false;
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    var didSpeak = false;

    try {
      final assistant = appState.createAiAssistant(
        systemPrompt: AiAssistantService.defaultSystemPrompt(
          userName: appState.userName,
          now: DateTime.now(),
          voiceMode: true,
        ),
        onSpeak: (text) async {
          didSpeak = true;
          await _speakAloud(text);
        },
        onStartVisualMode: (request) async {
          if (!mounted) return;
          await showVisualVerificationScreen(
            context,
            expectedMedicationName: request.expectedMedicationName,
          );
        },
      );

      final result = await assistant.sendMessage(
        userText,
        history: List<ChatMessage>.of(_history),
        onEvent: (event) {
          if (event is AiToolCallStartedEvent) {
            debugPrint('VoiceMode: tool "${event.toolName}"');
          } else if (event is AiErrorEvent) {
            debugPrint('VoiceMode: AI error ${event.error}');
          }
        },
      );

      // Persist history without system messages for the next turn.
      _history
        ..clear()
        ..addAll(
          result.updatedHistory.where((m) => m.role != 'system'),
        );

      // If the model replied in text without calling speak, still show it —
      // but do NOT auto-TTS (speak tool is the voice channel).
      final reply = result.response.trim();
      if (!didSpeak && reply.isNotEmpty && !reply.startsWith('AI error:')) {
        setState(() {
          _bubbles.add(_ChatBubble(isUser: false, text: reply));
        });
        _scrollChatToEnd();
      }
    } catch (e) {
      debugPrint('VoiceMode: AI Assistant error: $e');
      if (mounted) {
        setState(() {
          _errorText = 'AI error: $e';
          _phase = _VoicePhase.idle;
        });
      }
      _turnInFlight = false;
      return;
    }

    _turnInFlight = false;

    // After the AI finishes (and any speak audio ends), listen again so the
    // user can answer clarifying questions.
    if (mounted) {
      await _startListening();
    }
  }

  Future<void> _speakAloud(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !mounted) return;

    setState(() {
      _bubbles.add(_ChatBubble(isUser: false, text: trimmed));
      _phase = _VoicePhase.speaking;
      _errorText = null;
    });
    _scrollChatToEnd();

    _audioBuffer.clear();
    _speakDone = Completer<void>();
    try {
      await _svc.speak(trimmed);
      // Wait for playback (or error / timeout).
      await _speakDone!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('VoiceMode: speak failed: $e');
    } finally {
      if (_speakDone != null && !_speakDone!.isCompleted) {
        _speakDone!.complete();
      }
      _speakDone = null;
    }
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      if (_speakDone != null && !_speakDone!.isCompleted) {
        _speakDone!.complete();
      }
      return;
    }

    if (mounted) {
      setState(() => _phase = _VoicePhase.speaking);
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
          await _player.play(DeviceFileSource(tempFile.path));
        } catch (_) {
          await _player.play(BytesSource(bytes));
        }
      }
    } catch (e) {
      debugPrint('VoiceMode: Audio playback error: $e');
      if (_speakDone != null && !_speakDone!.isCompleted) {
        _speakDone!.complete();
      }
      if (mounted) {
        setState(() {
          _errorText = 'Playback error: $e';
          _phase = _VoicePhase.idle;
        });
      }
    }
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onOrbTap() {
    switch (_phase) {
      case _VoicePhase.listening:
        _finishListeningAndCallAi();
      case _VoicePhase.speaking:
        _player.stop();
        if (_speakDone != null && !_speakDone!.isCompleted) {
          _speakDone!.complete();
        }
      case _VoicePhase.thinking:
        break;
      case _VoicePhase.idle:
        _startListening();
    }
  }

  String get _displayTranscript {
    if (_finalText.isNotEmpty && _partialText.isNotEmpty) {
      return '$_finalText $_partialText';
    }
    if (_finalText.isNotEmpty) return _finalText;
    if (_partialText.isNotEmpty) return _partialText;
    return '';
  }

  String get _phaseLabel => switch (_phase) {
        _VoicePhase.listening => 'Listening…',
        _VoicePhase.thinking => 'Thinking…',
        _VoicePhase.speaking => 'Speaking…',
        _VoicePhase.idle => 'Tap to speak',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _VC.bg,
      body: SafeArea(
        child: Column(
          children: [
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
                  Expanded(
                    child: Text(
                      widget.intent == VoiceModeIntent.addMedication
                          ? 'Add medication'
                          : 'Voice Assistant',
                      style: const TextStyle(
                        color: _VC.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    _phaseLabel,
                    style: const TextStyle(
                      color: _VC.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Orb ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: GestureDetector(
                onTap: _onOrbTap,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_orbCtrl, _morphCtrl]),
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _orbFloat.value),
                    child: Transform.scale(
                      scale: _orbScale.value,
                      child: _GlassOrb(
                        morphT: _morphAnim.value,
                        active: _phase == _VoicePhase.listening ||
                            _phase == _VoicePhase.speaking,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1520),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8B263E)),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFFFD1D1),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),

            // ── Live transcript while listening ───────────────────────────
            if (_phase == _VoicePhase.listening &&
                _displayTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _displayTranscript,
                    style: TextStyle(
                      color: _VC.textSub.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            // ── Text chat ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _chatScroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _bubbles.length,
                itemBuilder: (context, i) {
                  final b = _bubbles[i];
                  return _ChatRow(bubble: b);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.bubble});
  final _ChatBubble bubble;

  @override
  Widget build(BuildContext context) {
    final align =
        bubble.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = bubble.isUser ? _VC.userBubble : _VC.aiBubble;
    final label = bubble.isUser ? 'You' : 'AI';

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _VC.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: bubble.isUser ? _VC.orbBlue : _VC.orbPurple,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bubble.text,
              style: const TextStyle(
                color: _VC.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.morphT, required this.active});

  final double morphT;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrbPainter(morphT: morphT, active: active),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.morphT, required this.active});
  final double morphT;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
      ..shader = RadialGradient(
        colors: [
          (active ? _VC.orbPurple : _VC.orbBlue).withValues(alpha: 0.5),
          _VC.orbBlue.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.2));
    canvas.drawCircle(Offset(cx, cy), r * 1.2, glowPaint);

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

    final t = morphT;
    final bx = cx - r * 0.18 + t * r * 0.08;
    final by = cy - r * 0.22 - t * r * 0.06;
    final br = r * (0.30 + t * 0.06);
    final blobPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(bx, by),
        width: br * 1.45,
        height: br,
      ));
    final specPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(bx, by),
        width: br * 2,
        height: br * 2,
      ));
    canvas.drawPath(blobPath, specPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.3),
        ],
        startAngle: -pi / 4,
        endAngle: 2 * pi - pi / 4,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r - 0.75, rimPaint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.morphT != morphT || old.active != active;
}

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
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}
