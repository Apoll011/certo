import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai.dart';
import '../config/app_config.dart';
import '../services/elevenlabs_service.dart';
import '../state/app_state.dart';
import '../widgets/chat_ui_attachment.dart';
import '../widgets/voice_orb.dart';
import 'visual_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens — pure white voice conversation surface
// ─────────────────────────────────────────────────────────────────────────────
class _VC {
  static const bg = Color(0xFFFFFFFF);
  static const bgCard = Color(0xFFF4F6FA);
  static const userBubble = Color(0xFFE8EEF8);
  static const aiBubble = Color(0xFFF4F6FA);
  static const textPrimary = Color(0xFF13005A);
  static const textSub = Color(0xFF5A6B88);
  static const accent = Color(0xFF3366FF);
  static const divider = Color(0xFFE2E8F0);
  static const errorBg = Color(0xFFFDEBEC);
  static const errorBorder = Color(0xFFF5C2C5);
  static const errorText = Color(0xFFB42318);
}

enum VoiceModeIntent { general, addMedication }

enum _VoicePhase { listening, thinking, speaking, idle }

class _ChatBubble {
  const _ChatBubble({
    required this.isUser,
    required this.text,
    this.attachments = const [],
  });
  final bool isUser;
  final String text;
  final List<ChatUiAttachment> attachments;

  _ChatBubble copyWith({
    String? text,
    List<ChatUiAttachment>? attachments,
  }) {
    return _ChatBubble(
      isUser: isUser,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Opens Voice Mode as a full-page route with a soft fade (no hard cut).
Future<void> showVoiceMode(
  BuildContext context, {
  VoiceModeIntent intent = VoiceModeIntent.general,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return VoiceModeScreen(intent: intent);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
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
    with SingleTickerProviderStateMixin {
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
  bool _shouldClose = false;
  bool _openedVisual = false;
  bool _collectingAskAnswer = false;

  /// User spoke over TTS — skip remaining speaks and resume listen.
  bool _userInterrupted = false;
  /// Ignore further TTS chunks after barge-in / cancel.
  bool _ignoreTts = false;
  /// STT was started only to detect barge-in over TTS.
  bool _bargeInViaStt = false;
  DateTime? _bargeSttArmUntil;
  /// Utterance captured while the interrupted AI turn was still winding down.
  String? _pendingAfterInterrupt;

  /// Monotonic id so stale TtsDone / complete events can't finish a newer speak.
  int _ttsSession = 0;
  int _playingSession = 0;
  bool _playInFlight = false;
  Timer? _bargeInArmTimer;
  Timer? _playbackWatchdog;

  /// Smoothed mic amplitude 0–1 for the audio-reactive orb.
  double _amplitude = 0;

  /// Drives orb center → top layout morph.
  late final AnimationController _layoutCtrl;
  late final Animation<double> _layoutAnim;

  @override
  void initState() {
    super.initState();
    _layoutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _layoutAnim = CurvedAnimation(
      parent: _layoutCtrl,
      curve: Curves.easeInOutCubic,
    );
    _initVoice();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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
    _bargeInArmTimer?.cancel();
    _playbackWatchdog?.cancel();
    _layoutCtrl.dispose();
    _chatScroll.dispose();
    _eventSub?.cancel();
    _playerCompleteSub?.cancel();
    unawaited(_svc.stopBargeInMonitor());
    _svc.dispose();
    _player.dispose();
    if (_speakDone != null && !_speakDone!.isCompleted) {
      _speakDone!.complete();
    }
    super.dispose();
  }

  /// Whether the orb should sit near the top with chat below.
  bool get _chatLayout {
    final hasAi = _bubbles.any((b) => !b.isUser);
    return hasAi ||
        _phase == _VoicePhase.speaking ||
        (_phase == _VoicePhase.idle && _bubbles.isNotEmpty);
  }

  VoiceOrbPhase get _orbPhase {
    if (_chatLayout &&
        (_phase == _VoicePhase.idle || _phase == _VoicePhase.listening)) {
      return VoiceOrbPhase.chat;
    }
    return switch (_phase) {
      _VoicePhase.listening => (_amplitude > 0.06 || _partialText.isNotEmpty)
          ? VoiceOrbPhase.speaking
          : VoiceOrbPhase.active,
      _VoicePhase.thinking => VoiceOrbPhase.processing,
      _VoicePhase.speaking => VoiceOrbPhase.responding,
      _VoicePhase.idle =>
        _bubbles.isEmpty ? VoiceOrbPhase.active : VoiceOrbPhase.chat,
    };
  }

  void _syncLayoutAnim() {
    if (_chatLayout) {
      if (_layoutCtrl.status != AnimationStatus.completed &&
          _layoutCtrl.status != AnimationStatus.forward) {
        unawaited(_layoutCtrl.forward());
      }
    } else {
      if (_layoutCtrl.status != AnimationStatus.dismissed &&
          _layoutCtrl.status != AnimationStatus.reverse) {
        unawaited(_layoutCtrl.reverse());
      }
    }
  }

  // ── STT events ───────────────────────────────────────────────────────────
  void _onEvent(VoiceEvent event) {
    if (!mounted) return;
    if (event is VoiceAmplitude) {
      if (_phase != _VoicePhase.listening) return;
      // Smooth amplitude so the orb doesn't jump frame-to-frame.
      final next = _amplitude * 0.55 + event.level * 0.45;
      if ((next - _amplitude).abs() > 0.01) {
        setState(() => _amplitude = next);
      }
      return;
    }
    // While ask_user is collecting a spoken reply, ignore for the main loop.
    if (_collectingAskAnswer && event is! BargeInDetected) return;
    switch (event) {
      case TranscriptionPartial(:final text):
        if (_phase == _VoicePhase.speaking && _bargeInViaStt) {
          _maybeBargeInFromTranscript(text);
          return;
        }
        if (_phase != _VoicePhase.listening) return;
        _endOfTurnTimer?.cancel();
        setState(() {
          _partialText = text;
          _errorText = null;
        });

      case TranscriptionFinal(:final text):
        if (_phase == _VoicePhase.speaking && _bargeInViaStt) {
          _maybeBargeInFromTranscript(text);
          return;
        }
        if (_phase != _VoicePhase.listening) return;
        if (text.trim().isEmpty) return;
        setState(() {
          _finalText =
              (_finalText.isEmpty ? '' : '$_finalText ') + text.trim();
          _partialText = '';
          _errorText = null;
        });
        _endOfTurnTimer?.cancel();
        _endOfTurnTimer = Timer(_endOfTurnGrace, () {
          if (mounted && _phase == _VoicePhase.listening) {
            _finishListeningAndCallAi();
          }
        });

      case TtsAudioChunk(:final bytes):
        if (_ignoreTts) return;
        _audioBuffer.addAll(bytes);

      case TtsDone():
        if (_ignoreTts) {
          _completeSpeakDone();
          return;
        }
        unawaited(_playBufferedAudio());

      case BargeInDetected():
        unawaited(_handleBargeIn());

      case VoiceError(:final message):
        debugPrint('VoiceMode UI error: $message');
        if (mounted) {
          setState(() {
            _phase = _VoicePhase.idle;
            _errorText = message;
          });
        }
        _completeSpeakDone();

      case VoiceAmplitude():
        break;
    }
  }

  void _maybeBargeInFromTranscript(String text) {
    if (_userInterrupted) return;
    if (_bargeSttArmUntil != null &&
        DateTime.now().isBefore(_bargeSttArmUntil!)) {
      return;
    }
    if (text.trim().length < 2) return;
    debugPrint('VoiceMode: barge-in via STT transcript "$text"');
    unawaited(_handleBargeIn());
  }

  Future<void> _armBargeInDetection() async {
    if (_userInterrupted || _ignoreTts) return;
    // Stricter thresholds — false barge-in was cutting TTS with no audible output.
    await _svc.startBargeInMonitor(
      armDelay: const Duration(milliseconds: 500),
      calibrateFor: const Duration(milliseconds: 600),
      consecutiveChunks: 3,
      minAbsoluteRms: 0.035,
      overBaselineFactor: 2.8,
      overBaselineAdd: 0.025,
    );
    if (_svc.isBargeInActive) return;

    debugPrint('VoiceMode: barge-in falling back to STT');
    _bargeSttArmUntil = DateTime.now().add(const Duration(milliseconds: 800));
    _bargeInViaStt = true;
    try {
      await _svc.startListening();
    } catch (e) {
      debugPrint('VoiceMode: barge-in STT fallback failed: $e');
      _bargeInViaStt = false;
    }
  }

  Future<void> _handleBargeIn() async {
    if (!mounted) return;
    if (_phase != _VoicePhase.speaking && !_collectingAskAnswer) return;
    if (_userInterrupted && _phase == _VoicePhase.listening) return;

    debugPrint('VoiceMode: barge-in — stopping TTS, listening again');
    _userInterrupted = true;
    _ignoreTts = true;
    _ttsSession++; // invalidate in-flight play / Done handlers
    _bargeInArmTimer?.cancel();
    _playbackWatchdog?.cancel();
    final wasSttBarge = _bargeInViaStt;
    _bargeInViaStt = false;
    _svc.cancelSpeak();
    await _svc.stopBargeInMonitor();
    _audioBuffer.clear();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.setVolume(1.0);
    } catch (_) {}
    _completeSpeakDone();

    if (!mounted || _shouldClose || _openedVisual) return;

    if (_collectingAskAnswer) {
      if (mounted) setState(() => _phase = _VoicePhase.listening);
      if (!_svc.isListening) await _svc.startListening();
      return;
    }

    if (wasSttBarge && _svc.isListening) {
      _endOfTurnTimer?.cancel();
      if (mounted) {
        setState(() {
          _phase = _VoicePhase.listening;
          _finalText = '';
          _partialText = '';
          _errorText = null;
        });
      }
      return;
    }

    await _startListening();
  }

  void _completeSpeakDone() {
    _playInFlight = false;
    _playbackWatchdog?.cancel();
    if (_speakDone != null && !_speakDone!.isCompleted) {
      _speakDone!.complete();
    }
  }

  void _onPlaybackComplete() {
    // Ignore completion from a previous play session.
    if (_playingSession != _ttsSession) return;
    _completeSpeakDone();
    if (mounted && _phase == _VoicePhase.speaking && !_turnInFlight) {
      setState(() => _phase = _VoicePhase.idle);
      _syncLayoutAnim();
    }
  }

  Future<void> _startListening() async {
    try {
      await _player.stop();
    } catch (_) {}
    await _svc.stopBargeInMonitor();
    _endOfTurnTimer?.cancel();
    _audioBuffer.clear();
    _ignoreTts = false;

    if (!mounted) return;
    setState(() {
      _phase = _VoicePhase.listening;
      _finalText = '';
      _partialText = '';
      _errorText = null;
      _amplitude = 0;
    });
    _syncLayoutAnim();
    await _svc.startListening();
  }

  Future<void> _finishListeningAndCallAi() async {
    if (_phase != _VoicePhase.listening) return;
    if (_turnInFlight && !_userInterrupted) return;
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
          _amplitude = 0;
        });
        _syncLayoutAnim();
      }
      return;
    }

    if (_turnInFlight && _userInterrupted) {
      _pendingAfterInterrupt = spoken;
      if (mounted) {
        setState(() {
          _bubbles.add(_ChatBubble(isUser: true, text: spoken));
          _phase = _VoicePhase.thinking;
          _errorText = null;
          _amplitude = 0;
        });
        _syncLayoutAnim();
        _scrollChatToEnd();
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
        _amplitude = 0;
      });
      _syncLayoutAnim();
      _scrollChatToEnd();
    } else {
      setState(() {
        _phase = _VoicePhase.thinking;
        _errorText = null;
        _amplitude = 0;
      });
      _syncLayoutAnim();
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
    _openedVisual = false;
    _shouldClose = false;
    _userInterrupted = false;
    _pendingAfterInterrupt = null;

    try {
      final assistant = appState.createAiAssistant(
        systemPrompt: AiAssistantService.defaultSystemPrompt(
          userName: appState.userName,
          now: DateTime.now(),
          voiceMode: true,
        ),
        onSpeak: (text) async {
          if (_userInterrupted || _openedVisual || _shouldClose) return;
          final lower = text.toLowerCase();
          if (lower.contains('open') &&
              (lower.contains('camera') ||
                  lower.contains('visual') ||
                  lower.contains('scan'))) {
            return;
          }
          if (lower.contains("i'm opening") ||
              lower.contains('i am opening') ||
              lower.contains('let me open') ||
              lower.contains('opening the camera')) {
            return;
          }
          didSpeak = true;
          await _speakAloud(text);
        },
        onAskUser: (question) async {
          if (_userInterrupted) return '';
          setState(() {
            _bubbles.add(_ChatBubble(isUser: false, text: question));
          });
          _syncLayoutAnim();
          _scrollChatToEnd();
          final answer = await _askUserListenCycle(question);
          if (answer.isNotEmpty) {
            setState(() {
              _bubbles.add(_ChatBubble(isUser: true, text: answer));
            });
            _scrollChatToEnd();
          }
          return answer;
        },
        onStartVisualMode: (request) async {
          if (!mounted) return;
          _openedVisual = true;
          _shouldClose = true;
          _svc.cancelSpeak();
          try {
            await _player.stop();
          } catch (_) {}
          if (_speakDone != null && !_speakDone!.isCompleted) {
            _speakDone!.complete();
          }
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => VisualVerificationScreen(request: request),
              fullscreenDialog: true,
            ),
          );
        },
        onCloseVoiceMode: () async {
          _shouldClose = true;
          if (mounted && !_openedVisual) {
            Navigator.of(context).pop();
          }
        },
        onShowUi: _appendUiAttachment,
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

      _history
        ..clear()
        ..addAll(
          result.updatedHistory.where((m) => m.role != 'system'),
        );

      final reply = result.response.trim();
      if (!didSpeak && reply.isNotEmpty && !reply.startsWith('AI error:')) {
        setState(() {
          _bubbles.add(_ChatBubble(isUser: false, text: reply));
        });
        _syncLayoutAnim();
        _scrollChatToEnd();
      }
    } catch (e) {
      debugPrint('VoiceMode: AI Assistant error: $e');
      if (mounted) {
        setState(() {
          _errorText = 'AI error: $e';
          _phase = _VoicePhase.idle;
        });
        _syncLayoutAnim();
      }
      _turnInFlight = false;
      return;
    }

    _turnInFlight = false;

    if (!mounted || _shouldClose || _openedVisual) return;

    final pending = _pendingAfterInterrupt;
    _pendingAfterInterrupt = null;
    if (pending != null && pending.trim().isNotEmpty) {
      _userInterrupted = false;
      await _runAiTurn(pending, showUserBubble: false);
      return;
    }

    if (_userInterrupted) {
      _userInterrupted = false;
      if (_phase != _VoicePhase.listening) {
        await _startListening();
      }
      return;
    }

    await _startListening();
  }

  Future<String> _askUserListenCycle(String question) async {
    final done = Completer<String>();
    var buffer = '';
    Timer? grace;
    _collectingAskAnswer = true;

    void finish(String value) {
      if (done.isCompleted) return;
      grace?.cancel();
      _collectingAskAnswer = false;
      done.complete(value.trim());
    }

    late final StreamSubscription<VoiceEvent> sub;
    sub = _svc.events.listen((event) {
      if (event is TranscriptionPartial) {
        grace?.cancel();
      } else if (event is TranscriptionFinal) {
        buffer = buffer.isEmpty
            ? event.text.trim()
            : '$buffer ${event.text.trim()}';
        grace?.cancel();
        grace = Timer(const Duration(milliseconds: 700), () {
          sub.cancel();
          _svc.stopListening();
          finish(buffer);
        });
      } else if (event is VoiceError) {
        sub.cancel();
        finish(buffer);
      }
    });

    try {
      await _speakAloud(question);
      await _svc.startListening();
      if (mounted) setState(() => _phase = _VoicePhase.listening);

      return await done.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          sub.cancel();
          _svc.stopListening();
          _collectingAskAnswer = false;
          return buffer.trim();
        },
      );
    } catch (_) {
      sub.cancel();
      _collectingAskAnswer = false;
      rethrow;
    }
  }

  Future<void> _speakAloud(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !mounted || _userInterrupted) return;

    setState(() {
      if (_bubbles.isNotEmpty && !_bubbles.last.isUser) {
        final last = _bubbles.last;
        final existing = last.text.trim();
        final merged = existing.isEmpty
            ? trimmed
            : (existing == trimmed ? existing : '$existing\n$trimmed');
        _bubbles[_bubbles.length - 1] = last.copyWith(text: merged);
      } else {
        _bubbles.add(_ChatBubble(isUser: false, text: trimmed));
      }
      _phase = _VoicePhase.speaking;
      _errorText = null;
    });
    _syncLayoutAnim();
    _scrollChatToEnd();

    final session = ++_ttsSession;
    _ignoreTts = false;
    _audioBuffer.clear();
    _bargeInArmTimer?.cancel();
    _playbackWatchdog?.cancel();
    _speakDone = Completer<void>();

    try {
      try {
        await _player.stop();
      } catch (_) {}

      await _svc.speak(trimmed);
      if (_userInterrupted || session != _ttsSession) return;

      // If Done raced / was missed, still play whatever we buffered.
      if (!_playInFlight &&
          _audioBuffer.isNotEmpty &&
          _speakDone != null &&
          !_speakDone!.isCompleted) {
        debugPrint('VoiceMode: speak() returned with buffered audio — playing');
        unawaited(_playBufferedAudio(session: session));
      }

      // Empty TTS — leave "Speaking" immediately instead of hanging.
      if (_speakDone != null &&
          !_speakDone!.isCompleted &&
          !_playInFlight &&
          _audioBuffer.isEmpty) {
        debugPrint('VoiceMode: TTS finished with no audio bytes');
        _completeSpeakDone();
        return;
      }

      await _speakDone!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint('VoiceMode: speakDone timed out (session $session)');
        },
      );
    } catch (e) {
      debugPrint('VoiceMode: speak failed: $e');
    } finally {
      if (session == _ttsSession) {
        _bargeInArmTimer?.cancel();
        _playbackWatchdog?.cancel();
        await _svc.stopBargeInMonitor();
        if (_bargeInViaStt && !_userInterrupted) {
          _bargeInViaStt = false;
          await _svc.stopListening();
        }
        try {
          await _player.setVolume(1.0);
        } catch (_) {}
        _completeSpeakDone();
        _speakDone = null;
      }
    }
  }

  Future<void> _playBufferedAudio({int? session}) async {
    final activeSession = session ?? _ttsSession;
    if (_ignoreTts || _userInterrupted || activeSession != _ttsSession) {
      _audioBuffer.clear();
      _completeSpeakDone();
      return;
    }
    if (_playInFlight) return;
    if (_audioBuffer.isEmpty) {
      debugPrint('VoiceMode: TtsDone with empty buffer — skipping playback');
      _completeSpeakDone();
      return;
    }

    // Anything under ~256B is almost certainly not playable MP3.
    if (_audioBuffer.length < 256) {
      debugPrint(
        'VoiceMode: TTS buffer too small (${_audioBuffer.length}b) — skipping',
      );
      _audioBuffer.clear();
      _completeSpeakDone();
      return;
    }

    _playInFlight = true;
    _playingSession = activeSession;
    if (mounted) {
      setState(() => _phase = _VoicePhase.speaking);
      _syncLayoutAnim();
    }
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    // ~128kbps MP3 → bytes/16 ≈ ms. Watchdog if onPlayerComplete never fires.
    final estimatedMs = (bytes.length / 16).round().clamp(800, 60000);
    _playbackWatchdog?.cancel();
    _playbackWatchdog = Timer(
      Duration(milliseconds: estimatedMs + 2500),
      () {
        if (_playingSession != activeSession) return;
        if (_speakDone != null && !_speakDone!.isCompleted) {
          debugPrint(
            'VoiceMode: playback watchdog fired after ${estimatedMs}ms audio',
          );
          _completeSpeakDone();
        }
      },
    );

    try {
      // Full volume first — ducking + opening a 2nd mic often mutes the speaker.
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);

      if (kIsWeb) {
        await _player.play(BytesSource(bytes));
      } else {
        try {
          final tempFile = File(
            '${Directory.systemTemp.path}/eleven_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          await _player.play(DeviceFileSource(tempFile.path));
        } catch (e) {
          debugPrint('VoiceMode: file playback failed ($e), trying bytes');
          await _player.play(BytesSource(bytes));
        }
      }

      if (_userInterrupted || _ignoreTts || activeSession != _ttsSession) {
        try {
          await _player.stop();
        } catch (_) {}
        _completeSpeakDone();
        return;
      }

      // Delay barge-in mic so TTS can actually be heard. Opening the mic
      // immediately steals audio focus on many Android devices.
      _bargeInArmTimer?.cancel();
      _bargeInArmTimer = Timer(const Duration(milliseconds: 1100), () {
        if (_userInterrupted ||
            _ignoreTts ||
            activeSession != _ttsSession) {
          return;
        }
        unawaited(_armBargeInDetection());
      });
    } catch (e) {
      debugPrint('VoiceMode: Audio playback error: $e');
      _completeSpeakDone();
      if (mounted) {
        setState(() {
          _errorText = 'Playback error: $e';
          _phase = _VoicePhase.idle;
        });
        _syncLayoutAnim();
      }
    }
    // Keep _playInFlight true until playback completes / is cancelled so a
    // duplicate TtsDone cannot start a second overlapping play.
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

  void _appendUiAttachment(ChatUiAttachment attachment) {
    if (!mounted) return;
    setState(() {
      if (_bubbles.isNotEmpty && !_bubbles.last.isUser) {
        final last = _bubbles.last;
        final caption = attachment.caption?.trim();
        final mergedText = (last.text.trim().isEmpty &&
                caption != null &&
                caption.isNotEmpty)
            ? caption
            : last.text;
        _bubbles[_bubbles.length - 1] = last.copyWith(
          text: mergedText,
          attachments: [...last.attachments, attachment],
        );
      } else {
        _bubbles.add(
          _ChatBubble(
            isUser: false,
            text: attachment.caption?.trim() ?? '',
            attachments: [attachment],
          ),
        );
      }
    });
    _syncLayoutAnim();
    _scrollChatToEnd();
  }

  void _onOrbTap() {
    switch (_phase) {
      case _VoicePhase.listening:
        _finishListeningAndCallAi();
      case _VoicePhase.speaking:
        unawaited(_handleBargeIn());
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

  String get _phaseLabel => switch (_orbPhase) {
        VoiceOrbPhase.active => 'Listening…',
        VoiceOrbPhase.speaking => 'Listening…',
        VoiceOrbPhase.processing => 'Thinking…',
        VoiceOrbPhase.responding => 'Speaking…',
        VoiceOrbPhase.chat => 'Tap orb to speak',
      };

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _VC.bg,
      body: AnimatedBuilder(
        animation: _layoutAnim,
        builder: (context, _) {
          final t = _layoutAnim.value;
          final orbSize = lerpDouble(200, 72, t)!;
          final screenH = MediaQuery.sizeOf(context).height;
          final centerY = screenH * 0.42;
          final topY = topPad + 56 + orbSize / 2;
          final orbCenterY = lerpDouble(centerY, topY, t)!;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: topPad + 8,
                left: 16,
                right: 16,
                child: Opacity(
                  opacity: lerpDouble(0.55, 1.0, t)!,
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        _phaseLabel,
                        style: const TextStyle(
                          color: _VC.textSub,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: orbCenterY - orbSize / 2,
                left: 0,
                right: 0,
                child: Center(
                  child: VoiceOrb(
                    phase: _orbPhase,
                    amplitude: _amplitude,
                    size: orbSize,
                    onTap: _onOrbTap,
                  ),
                ),
              ),

              if (t < 0.45 &&
                  _phase == _VoicePhase.listening &&
                  _displayTranscript.isNotEmpty)
                Positioned(
                  top: orbCenterY + orbSize / 2 + 28,
                  left: 32,
                  right: 32,
                  child: Opacity(
                    opacity: (1 - t / 0.45).clamp(0.0, 1.0),
                    child: Text(
                      '"$_displayTranscript"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VC.textSub,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),

              if (t < 0.35 &&
                  _bubbles.isEmpty &&
                  _displayTranscript.isEmpty &&
                  _errorText == null)
                Positioned(
                  top: orbCenterY + orbSize / 2 + 28,
                  left: 40,
                  right: 40,
                  child: Opacity(
                    opacity: (1 - t / 0.35).clamp(0.0, 1.0),
                    child: Text(
                      _phase == _VoicePhase.thinking
                          ? 'Working on that…'
                          : 'Speak naturally — I\'m listening',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VC.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

              if (t > 0.08)
                Positioned(
                  top: topPad + 56 + lerpDouble(0, 72, t)! + 8,
                  left: 0,
                  right: 0,
                  bottom: bottomPad,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(
                      ((t - 0.08) / 0.92).clamp(0.0, 1.0),
                    ),
                    child: Transform.translate(
                      offset: Offset(0, lerpDouble(36, 0, t)!),
                      child: Column(
                        children: [
                          if (_errorText != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _VC.errorBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _VC.errorBorder),
                                ),
                                child: Text(
                                  _errorText!,
                                  style: const TextStyle(
                                    color: _VC.errorText,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          if (_phase == _VoicePhase.listening &&
                              _displayTranscript.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _displayTranscript,
                                  style: const TextStyle(
                                    color: _VC.textSub,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: _bubbles.isEmpty
                                ? const SizedBox.shrink()
                                : ListView.builder(
                                    controller: _chatScroll,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      4,
                                      20,
                                      24,
                                    ),
                                    itemCount: _bubbles.length,
                                    itemBuilder: (context, i) =>
                                        _ChatRow(bubble: _bubbles[i]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (t < 0.2 && _errorText != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: bottomPad + 40,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _VC.errorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _VC.errorBorder),
                    ),
                    child: Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VC.errorText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
    final label = bubble.isUser ? 'You' : 'Certo';
    final hasText = bubble.text.trim().isNotEmpty;
    final hasCards = bubble.attachments.isNotEmpty;

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
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
                color: bubble.isUser ? _VC.accent : const Color(0xFF7C6BC4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasText) ...[
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
            if (hasCards) ...[
              SizedBox(height: hasText ? 10 : 6),
              for (var i = 0; i < bubble.attachments.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                ChatUiAttachmentView(attachment: bubble.attachments[i]),
              ],
            ],
          ],
        ),
      ),
    );
  }
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
        decoration: const BoxDecoration(
          color: _VC.bgCard,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _VC.textPrimary, size: 20),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}
