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
import '../widgets/chat_ui_attachment.dart';
import 'visual_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens — light Certo voice palette (matches voice-mode-integrated)
// ─────────────────────────────────────────────────────────────────────────────
class _VC {
  static const bg = Color(0xFFF4F6FA);
  static const bgCard = Color(0xFFFFFFFF);
  static const orbBlue = Color(0xFF8EC5FC);
  static const orbPurple = Color(0xFFB8A0F0);
  static const userBubble = Color(0xFFE8EEF8);
  static const aiBubble = Color(0xFFFFFFFF);
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
    unawaited(_svc.stopBargeInMonitor());
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
    // While ask_user is collecting a spoken reply, ignore for the main loop.
    if (_collectingAskAnswer && event is! BargeInDetected) return;
    switch (event) {
      case TranscriptionPartial(:final text):
        if (_phase == _VoicePhase.speaking && _bargeInViaStt) {
          _maybeBargeInFromTranscript(text);
          return;
        }
        if (_phase != _VoicePhase.listening) return;
        // User is mid-utterance — cancel any pending end-of-turn.
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
        if (_ignoreTts) return;
        _audioBuffer.addAll(bytes);

      case TtsDone():
        if (_ignoreTts) {
          if (_speakDone != null && !_speakDone!.isCompleted) {
            _speakDone!.complete();
          }
          return;
        }
        _playBufferedAudio();

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
        if (_speakDone != null && !_speakDone!.isCompleted) {
          _speakDone!.complete();
        }
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

  /// Arm mic energy monitor (preferred) and STT fallback for barge-in.
  Future<void> _armBargeInDetection() async {
    if (_userInterrupted || _ignoreTts) return;
    await _svc.startBargeInMonitor();
    if (_svc.isBargeInActive) return;

    // RMS monitor failed (device mic contention, etc.) — use STT instead.
    debugPrint('VoiceMode: barge-in falling back to STT');
    _bargeSttArmUntil = DateTime.now().add(const Duration(milliseconds: 600));
    _bargeInViaStt = true;
    try {
      await _svc.startListening();
    } catch (e) {
      debugPrint('VoiceMode: barge-in STT fallback failed: $e');
      _bargeInViaStt = false;
    }
  }

  /// User spoke while the AI was talking — stop TTS and listen again.
  Future<void> _handleBargeIn() async {
    if (!mounted) return;
    if (_phase != _VoicePhase.speaking && !_collectingAskAnswer) return;
    if (_userInterrupted && _phase == _VoicePhase.listening) return;

    debugPrint('VoiceMode: barge-in — stopping TTS, listening again');
    _userInterrupted = true;
    _ignoreTts = true;
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
    if (_speakDone != null && !_speakDone!.isCompleted) {
      _speakDone!.complete();
    }

    if (!mounted || _shouldClose || _openedVisual) return;

    if (_collectingAskAnswer) {
      if (mounted) setState(() => _phase = _VoicePhase.listening);
      if (!_svc.isListening) await _svc.startListening();
      return;
    }

    // STT barge already has the mic open — reuse it as the real listen session.
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
    });
    await _svc.startListening();
  }

  Future<void> _finishListeningAndCallAi() async {
    if (_phase != _VoicePhase.listening) return;
    // Normal path: ignore while a turn is running. After barge-in, accept the
    // new utterance and queue it until the interrupted turn finishes.
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
        });
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
        });
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
          // Skip process-filler about opening the camera — visual handoff speaks for itself.
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
          // Show + speak the question, then listen for the next utterance.
          setState(() {
            _bubbles.add(_ChatBubble(isUser: false, text: question));
          });
          _scrollChatToEnd();
          // Claim STT before TTS so barge-in mid-question feeds the collector.
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
          // Replace voice with visual so close/pop can't remove the camera.
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => VisualVerificationScreen(request: request),
              fullscreenDialog: true,
            ),
          );
        },
        onCloseVoiceMode: () async {
          _shouldClose = true;
          // Only pop if we are still on the voice screen (not replaced by visual).
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

    // Don't resume listening if we closed or handed off to the camera.
    if (!mounted || _shouldClose || _openedVisual) return;

    // Barge-in queued a new utterance while this turn was still finishing.
    final pending = _pendingAfterInterrupt;
    _pendingAfterInterrupt = null;
    if (pending != null && pending.trim().isNotEmpty) {
      _userInterrupted = false;
      // Bubble already added when queued.
      await _runAiTurn(pending, showUserBubble: false);
      return;
    }

    if (_userInterrupted) {
      _userInterrupted = false;
      // Already listening from barge-in (or restart if needed).
      if (_phase != _VoicePhase.listening) {
        await _startListening();
      }
      return;
    }

    // After the AI finishes (and any speak audio ends), listen again so the
    // user can answer clarifying questions.
    await _startListening();
  }

  /// Speak [question], then listen until VAD end-of-turn. Barge-in during the
  /// question stops TTS and counts the next utterance as the answer.
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
      // Barge-in may already have opened the mic; otherwise start now.
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
      // Merge into the latest AI bubble so show_medication cards stay on the
      // same message as the spoken reply.
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
    _scrollChatToEnd();

    _ignoreTts = false;
    _audioBuffer.clear();
    _speakDone = Completer<void>();
    // Barge-in monitor starts when playback begins (_playBufferedAudio),
    // not during download — that's when the user can actually interrupt.
    try {
      await _svc.speak(trimmed);
      if (_userInterrupted) return;
      // Wait for playback (or error / timeout).
      await _speakDone!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('VoiceMode: speak failed: $e');
    } finally {
      await _svc.stopBargeInMonitor();
      if (_bargeInViaStt && !_userInterrupted) {
        _bargeInViaStt = false;
        await _svc.stopListening();
      }
      try {
        await _player.setVolume(1.0);
      } catch (_) {}
      if (_speakDone != null && !_speakDone!.isCompleted) {
        _speakDone!.complete();
      }
      _speakDone = null;
    }
  }

  Future<void> _playBufferedAudio() async {
    if (_ignoreTts || _userInterrupted) {
      _audioBuffer.clear();
      if (_speakDone != null && !_speakDone!.isCompleted) {
        _speakDone!.complete();
      }
      return;
    }
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
      // Slightly duck TTS so near-field speech is easier to detect.
      await _player.setVolume(0.82);
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
      // Start barge-in AFTER playback begins (mic must survive audio focus).
      if (!_userInterrupted && !_ignoreTts) {
        unawaited(_armBargeInDetection());
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

  /// Attach a rich card to the latest AI bubble, or open a new one.
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
    _scrollChatToEnd();
  }

  void _onOrbTap() {
    switch (_phase) {
      case _VoicePhase.listening:
        _finishListeningAndCallAi();
      case _VoicePhase.speaking:
        // Treat orb tap like barge-in: stop TTS and listen.
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

  String get _phaseLabel => switch (_phase) {
        _VoicePhase.listening => 'Listening…',
        _VoicePhase.thinking => 'Thinking…',
        _VoicePhase.speaking => 'Speaking…',
        _VoicePhase.idle => 'Tap to speak',
      };

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _bubbles.isEmpty &&
        _errorText == null &&
        _phase == _VoicePhase.listening;

    return Scaffold(
      backgroundColor: _VC.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _VC.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _phaseLabel,
                      style: const TextStyle(
                        color: _VC.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
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

            Text(
              _phase == _VoicePhase.idle
                  ? 'What can I help you with?'
                  : _phaseLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _VC.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (_phase == _VoicePhase.listening &&
                _displayTranscript.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '"$_displayTranscript"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _VC.textSub,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

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

            Expanded(
              child: showSuggestions
                  ? const _SuggestionsCard()
                  : ListView.builder(
                      controller: _chatScroll,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _bubbles.length,
                      itemBuilder: (context, i) =>
                          _ChatRow(bubble: _bubbles[i]),
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
          boxShadow: bubble.isUser
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A13005A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: bubble.isUser ? _VC.accent : _VC.orbPurple,
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

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard();

  static const _items = [
    'What do I take now?',
    'Scan this medication',
    'Read the instructions',
    'Mark it as taken',
    'When do I take Amoxicillin?',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final s in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _VC.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _VC.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A13005A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: _VC.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _VC.textSub,
                  size: 22,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.morphT, required this.active});

  final double morphT;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36)
      ..shader = RadialGradient(
        colors: [
          (active ? _VC.orbPurple : _VC.orbBlue).withValues(alpha: 0.45),
          _VC.orbBlue.withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.3));
    canvas.drawCircle(Offset(cx, cy), r * 1.3, glowPaint);

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.05,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFD6EEFF),
          Color(0xFFA8C8FC),
          Color(0xFFC4A8F5),
          Color(0xFFE8C8F8),
        ],
        stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
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
          Colors.white.withValues(alpha: 0.7),
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
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.55),
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A13005A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: _VC.textPrimary, size: 20),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}
