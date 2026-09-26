import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai.dart';
import '../config/app_config.dart';
import '../models/medication.dart';
import '../services/elevenlabs_service.dart';
import '../state/app_state.dart';
import '../utils/schedule.dart';
import 'voice_mode_sheet.dart';

export '../ai/tools/vision_tools.dart'
    show VisualModeIntent, VisualModeRequest, VisualVerificationStatus;

/// Opens Visual Mode. Prefer [VisualModeRequest] for AI / voice handoff.
Future<void> showVisualVerificationScreen(
  BuildContext context, {
  Medication? targetMedication,
  String? expectedMedicationName,
  VisualModeIntent intent = VisualModeIntent.verify,
  bool autoCapture = false,
  int autoCaptureDelayMs = 1000,
  String? prompt,
  VisualModeRequest? request,
}) {
  final req = request ??
      VisualModeRequest(
        intent: intent,
        expectedMedicationName: expectedMedicationName,
        autoCapture: autoCapture,
        autoCaptureDelayMs: autoCaptureDelayMs,
        prompt: prompt,
      );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => VisualVerificationScreen(
        targetMedication: targetMedication,
        request: req,
      ),
      fullscreenDialog: true,
    ),
  );
}

class VisualVerificationScreen extends StatefulWidget {
  const VisualVerificationScreen({
    super.key,
    this.targetMedication,
    this.request = const VisualModeRequest(),
  });

  final Medication? targetMedication;
  final VisualModeRequest request;

  VisualModeIntent get intent => request.intent;

  @override
  State<VisualVerificationScreen> createState() =>
      _VisualVerificationScreenState();
}

class _VisualVerificationScreenState extends State<VisualVerificationScreen>
    with TickerProviderStateMixin {
  CameraController? _camera;
  bool _cameraReady = false;
  String? _cameraError;
  bool _flashOn = false;
  bool _isProcessing = false;
  bool _scanning = false;
  /// True only while waiting for the initial auto-capture timer.
  bool _awaitingAutoCapture = false;
  bool _medicationCreated = false;
  List<String> _pendingTimes = [];
  bool _listeningForAnswer = false;
  String _askPartial = '';

  late VisualVerificationStatus _status;
  String _identifiedName = '';
  String _category = '';
  String _matchMessage = '';
  String _expectedName = '';
  String _nextDoseTime = '';
  String _nextDoseInstruction = '';
  String _dosage = '';
  bool _canAdd = false;
  bool _canConfirm = false;

  final List<ChatMessage> _history = [];
  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  String? _pendingQuestion;
  Completer<String>? _askCompleter;

  final ElevenLabsService _voice = ElevenLabsService();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<VoiceEvent>? _voiceSub;
  final List<int> _ttsBuffer = [];
  Completer<void>? _ttsDone;

  late final AnimationController _scanCtrl;
  Timer? _autoCaptureTimer;

  @override
  void initState() {
    super.initState();
    _status = VisualVerificationStatus.identifying;
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _voiceSub = _voice.events.listen(_onVoiceEvent);
    _player.onPlayerComplete.listen((_) {
      if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
    });
    _initFromSchedule();
    _initCamera();
  }

  void _onVoiceEvent(VoiceEvent event) {
    switch (event) {
      case TtsAudioChunk(:final bytes):
        _ttsBuffer.addAll(bytes);
      case TtsDone():
        _playTtsBuffer();
      case TranscriptionPartial(:final text):
        if (_listeningForAnswer && mounted) {
          setState(() => _askPartial = text);
        }
      case TranscriptionFinal(:final text):
        if (_listeningForAnswer && mounted && text.trim().isNotEmpty) {
          setState(() {
            _askPartial = text.trim();
          });
        }
      case VoiceError(:final message):
        debugPrint('VisualMode TTS/STT error: $message');
        if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
      default:
        break;
    }
  }

  Future<void> _playTtsBuffer() async {
    if (_ttsBuffer.isEmpty) {
      if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
      return;
    }
    final bytes = Uint8List.fromList(_ttsBuffer);
    _ttsBuffer.clear();
    try {
      final tempFile = File(
        '${Directory.systemTemp.path}/visual_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(bytes, flush: true);
      await _player.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint('VisualMode: playback failed: $e');
      if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
    }
  }

  void _initFromSchedule() {
    final appState = Provider.of<AppState>(context, listen: false);
    final expected = widget.request.expectedMedicationName?.trim();
    if (expected != null && expected.isNotEmpty) {
      _expectedName = expected;
      _identifiedName = expected;
      return;
    }
    final target = widget.targetMedication;
    if (target == null) {
      final active = appState.medicationsWithStatus(MedicationStatus.active);
      if (active.isNotEmpty) {
        final m = active.first;
        _expectedName = m.name;
        _identifiedName = m.name;
        _category = m.category;
        _nextDoseTime = m.firstTime;
        _nextDoseInstruction = m.dosageLine;
        _dosage = m.dosage;
      }
    } else {
      _expectedName = target.name;
      _identifiedName = target.name;
      _category = target.category;
      _nextDoseTime = target.firstTime;
      _nextDoseInstruction = target.dosageLine;
      _dosage = target.dosage;
    }
    if (widget.intent == VisualModeIntent.verify) {
      final dues = dueDoses(appState.medications, DateTime.now());
      if (dues.isNotEmpty) {
        final due = dues.first;
        _expectedName = due.medication.name;
        _nextDoseTime = due.time;
        _nextDoseInstruction = due.medication.dosageLine;
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera found on this device.');
        }
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      setState(() => _cameraReady = true);

      if (widget.request.autoCapture) {
        final delay = Duration(
          milliseconds: widget.request.autoCaptureDelayMs.clamp(300, 5000),
        );
        setState(() => _awaitingAutoCapture = true);
        _autoCaptureTimer = Timer(delay, () {
          if (!mounted) return;
          setState(() => _awaitingAutoCapture = false);
          if (!_isProcessing) _captureAndAnalyze();
        });
      }
    } catch (e) {
      debugPrint('VisualMode: camera init failed: $e');
      if (mounted) setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _scanCtrl.dispose();
    _voiceSub?.cancel();
    _camera?.dispose();
    _voice.dispose();
    _player.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    if (_askCompleter != null && !_askCompleter!.isCompleted) {
      _askCompleter!.complete('');
    }
    if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      final next = !_flashOn;
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } catch (e) {
      debugPrint('VisualMode: flash failed: $e');
    }
  }

  String _promptForIntent() {
    final extra = widget.request.prompt;
    return switch (widget.intent) {
      VisualModeIntent.addMedication =>
        AiAssistantService.visualAddMedicationPrompt(extra: extra),
      VisualModeIntent.identify =>
        AiAssistantService.visualIdentifyPrompt(extra: extra),
      VisualModeIntent.verify => AiAssistantService.visualVerificationPrompt(
          expectedMedicationName:
              _expectedName.isNotEmpty ? _expectedName : null,
          extra: extra,
        ),
    };
  }

  Future<void> _speak(String text) async {
    try {
      _ttsBuffer.clear();
      _ttsDone = Completer<void>();
      await _voice.speak(text);
      await _ttsDone!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('VisualMode: TTS failed: $e');
    } finally {
      if (_ttsDone != null && !_ttsDone!.isCompleted) _ttsDone!.complete();
      _ttsDone = null;
    }
  }

  void _stopScanVisual() {
    _scanCtrl.stop();
    _scanCtrl.reset();
    _scanning = false;
  }

  /// Ask via spoken answer (STT). Typed submit can still complete as fallback.
  Future<String> _askUser(String question) async {
    if (!mounted) return '';
    _stopScanVisual();
    if (mounted) {
      setState(() {
        _pendingQuestion = question;
        _listeningForAnswer = true;
        _askPartial = '';
        _scanning = false;
        _replyCtrl.clear();
      });
    }

    await _speak(question);

    _askCompleter = Completer<String>();

    // Speech and typed fallback race on the same Completer.
    unawaited(
      _collectSpokenAnswer().then((spoken) {
        final t = spoken.trim();
        if (t.isNotEmpty &&
            _askCompleter != null &&
            !_askCompleter!.isCompleted) {
          _askCompleter!.complete(t);
        }
      }),
    );

    final resolved = await _askCompleter!.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => '',
    );
    await _voice.stopListening();
    _askCompleter = null;

    _mergeTimesFromAnswer(resolved);

    if (mounted) {
      setState(() {
        _pendingQuestion = null;
        _listeningForAnswer = false;
        _askPartial = '';
      });
    }
    return resolved.trim();
  }

  Future<String> _collectSpokenAnswer() async {
    final done = Completer<String>();
    var buffer = '';
    Timer? grace;

    late final StreamSubscription<VoiceEvent> sub;
    sub = _voice.events.listen((event) {
      if (event is TranscriptionPartial) {
        grace?.cancel();
        if (mounted) setState(() => _askPartial = event.text);
      } else if (event is TranscriptionFinal) {
        buffer = buffer.isEmpty
            ? event.text.trim()
            : '$buffer ${event.text.trim()}';
        if (mounted) setState(() => _askPartial = buffer);
        grace?.cancel();
        grace = Timer(const Duration(milliseconds: 700), () {
          sub.cancel();
          _voice.stopListening();
          if (!done.isCompleted) done.complete(buffer.trim());
        });
      } else if (event is VoiceError) {
        sub.cancel();
        if (!done.isCompleted) done.complete(buffer.trim());
      }
    });

    try {
      await _voice.startListening();
    } catch (e) {
      debugPrint('VisualMode: STT start failed: $e');
      sub.cancel();
      return '';
    }

    return done.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        sub.cancel();
        _voice.stopListening();
        return buffer.trim();
      },
    );
  }

  void _mergeTimesFromAnswer(String answer) {
    final parsed = _parseTimesFromSpeech(answer);
    if (parsed.isNotEmpty) {
      _pendingTimes = parsed;
    }
  }

  /// Pull simple time phrases out of spoken text.
  List<String> _parseTimesFromSpeech(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return [];
    final out = <String>[];
    final re = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\b',
      caseSensitive: false,
    );
    for (final m in re.allMatches(text)) {
      final hour = int.tryParse(m.group(1) ?? '') ?? 0;
      final minute = m.group(2) ?? '00';
      final meridiem = (m.group(3) ?? '').toLowerCase().replaceAll('.', '');
      if (hour < 1 || hour > 12 && meridiem.isEmpty && hour > 23) continue;
      if (meridiem.startsWith('a')) {
        out.add('$hour:${minute.padLeft(2, '0')} AM');
      } else if (meridiem.startsWith('p')) {
        out.add('$hour:${minute.padLeft(2, '0')} PM');
      } else if (hour >= 0 && hour <= 23) {
        final h24 = hour;
        final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
        final suffix = h24 >= 12 ? 'PM' : 'AM';
        out.add('$h12:${minute.padLeft(2, '0')} $suffix');
      }
    }
    // Meal anchors
    final lower = text.toLowerCase();
    for (final meal in ['breakfast', 'lunch', 'dinner', 'bedtime']) {
      if (lower.contains(meal) && !out.contains(meal)) out.add(meal);
    }
    return out;
  }

  void _applyCard(VisualVerificationCardData data) {
    setState(() {
      _status = data.status == VisualVerificationStatus.identifying
          ? VisualVerificationStatus.uncertain
          : data.status;
      if (data.identifiedMedicationName != null) {
        _identifiedName = data.identifiedMedicationName!;
      }
      if (data.category != null) _category = data.category!;
      if (data.message != null) _matchMessage = data.message!;
      if (data.expectedMedicationName != null) {
        _expectedName = data.expectedMedicationName!;
      }
      if (data.nextDoseTime != null) {
        _nextDoseTime = data.nextDoseTime!;
        // Schedule hint from card can seed times for create.
        if (_pendingTimes.isEmpty && data.nextDoseTime!.trim().isNotEmpty) {
          final t = data.nextDoseTime!.trim();
          if (!t.contains('—') && t != '-') _pendingTimes = [t];
        }
      }
      if (data.nextDoseInstruction != null) {
        _nextDoseInstruction = data.nextDoseInstruction!;
      }
      if (data.dosage != null) _dosage = data.dosage!;
      _canAdd = data.canAdd;
      _canConfirm = data.canConfirm;
    });
  }

  void _onAssistantEvent(AiAssistantEvent event) {
    if (event is AiToolCallCompletedEvent &&
        event.toolName == 'create_medication' &&
        event.result.success) {
      _medicationCreated = true;
      if (mounted) setState(() => _canAdd = false);
    }
  }

  AiAssistantService _buildAssistant(AppState appState) {
    return appState.createAiAssistant(
      systemPrompt: AiAssistantService.defaultSystemPrompt(
        userName: appState.userName,
        now: DateTime.now(),
        visualMode: true,
        visualIntent: widget.intent,
        voiceMode: true,
      ),
      onSpeak: _speak,
      onAskUser: _askUser,
      onShowVisualResult: _applyCard,
      onCapturePhoto: () async {
        if (!_isProcessing) await _captureAndAnalyze();
      },
      onStartVisualMode: (_) async {
        if (!_isProcessing) await _captureAndAnalyze();
      },
    );
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing) return;
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      setState(() => _cameraError = 'Camera is not ready yet.');
      return;
    }
    if (!AppConfig.hasAiApiKey) {
      setState(() {
        _cameraError =
            'DeepSeek API key missing. Add AI_API_KEY to .env and restart.';
      });
      return;
    }

    _autoCaptureTimer?.cancel();
    setState(() {
      _isProcessing = true;
      _scanning = true;
      _awaitingAutoCapture = false;
      _status = VisualVerificationStatus.identifying;
      _cameraError = null;
      _pendingQuestion = null;
    });
    _scanCtrl.repeat();

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final file = await cam.takePicture();
      final bytes = await File(file.path).readAsBytes();
      // Scan glow only while capturing — stop once we have the frame.
      if (mounted) {
        _stopScanVisual();
        setState(() => _scanning = false);
      }

      if (!mounted) return;
      final b64 = base64Encode(bytes);

      VisualVerificationCardData? card;
      final assistant = _buildAssistant(appState);
      assistant.tools.register(
        ShowVisualVerificationResultTool(
          onShowResult: (data) {
            card = data;
            _applyCard(data);
          },
        ),
      );

      final result = await assistant.verifyMedicationImage(
        imageBase64: b64,
        userPrompt: _promptForIntent(),
        history: List<ChatMessage>.of(_history),
        onEvent: _onAssistantEvent,
      );

      _history
        ..clear()
        ..addAll(result.updatedHistory.where((m) => m.role != 'system'));

      if (!mounted) return;
      if (card == null && result.response.trim().isNotEmpty) {
        setState(() {
          _status = VisualVerificationStatus.uncertain;
          _matchMessage = result.response.trim();
        });
      }
    } catch (e) {
      debugPrint('VisualMode: analyze failed: $e');
      if (mounted) {
        setState(() {
          _status = VisualVerificationStatus.uncertain;
          _matchMessage = 'Analysis failed: $e';
        });
      }
    } finally {
      _stopScanVisual();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanning = false;
        });
      }
    }
  }

  /// Follow-up conversation turn (text) after a photo analysis.
  Future<void> _sendFollowUp(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Completing an in-flight ask_user must work even while processing.
    if (_askCompleter != null && !_askCompleter!.isCompleted) {
      _askCompleter!.complete(trimmed);
      _replyCtrl.clear();
      return;
    }

    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final assistant = _buildAssistant(appState);
      final result = await assistant.sendMessage(
        trimmed,
        history: List<ChatMessage>.of(_history),
        onEvent: _onAssistantEvent,
      );
      _history
        ..clear()
        ..addAll(result.updatedHistory.where((m) => m.role != 'system'));
    } catch (e) {
      debugPrint('VisualMode follow-up error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _ensureMedicationPersisted() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final name = _identifiedName.trim();
    if (name.isEmpty) return false;

    if (_medicationCreated ||
        findMedication(appState, name: name) != null) {
      return true;
    }

    var times = List<String>.of(_pendingTimes);
    if (times.isEmpty) {
      final ans = await _askUser(
        'What times should I schedule $name? For example, 8 AM and 8 PM.',
      );
      times = _parseTimesFromSpeech(ans);
      if (times.isEmpty && ans.trim().isNotEmpty) {
        // Use the raw answer as a single schedule hint.
        times = [ans.trim()];
      }
      if (times.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Need at least one time to add this medication.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    }

    final dosage = _dosage.trim().isNotEmpty ? _dosage.trim() : '1 dose';
    final instruction = _nextDoseInstruction.trim().isNotEmpty
        ? _nextDoseInstruction.trim()
        : 'As directed';
    final category =
        _category.trim().isNotEmpty ? _category.trim() : 'General';
    final id =
        'med_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';

    await appState.addMedication(
      Medication(
        id: id,
        name: name,
        dosage: dosage,
        instruction: instruction,
        category: category,
        notes: '',
        times: times,
        pillColorIndex: math.Random().nextInt(8),
        status: MedicationStatus.active,
        startedAt: DateTime.now(),
      ),
    );
    _medicationCreated = true;
    if (mounted) setState(() => _canAdd = false);
    return true;
  }

  Future<void> _onConfirm() async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Add-med flow: Done must actually persist the medication.
    if (widget.intent == VisualModeIntent.addMedication) {
      final ok = await _ensureMedicationPersisted();
      if (!mounted || !ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _identifiedName.isNotEmpty
                ? '✓ Added "$_identifiedName"'
                : '✓ Medication added',
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final med = findMedication(
      appState,
      name: _identifiedName.isNotEmpty ? _identifiedName : _expectedName,
    );
    if (med != null) appState.markTaken(med.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          med != null ? '✓ Marked "${med.name}" as taken.' : '✓ Confirmed.',
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _onAddMedication() async {
    final ok = await _ensureMedicationPersisted();
    if (!mounted) return;
    if (!ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _identifiedName.isNotEmpty
              ? '✓ Added "$_identifiedName"'
              : '✓ Medication added',
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  void _openVoiceMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VoiceModeScreen(
          intent: widget.intent == VisualModeIntent.addMedication
              ? VoiceModeIntent.addMedication
              : VoiceModeIntent.general,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _resetToScan() {
    if (_askCompleter != null && !_askCompleter!.isCompleted) {
      _askCompleter!.complete('');
    }
    unawaited(_voice.stopListening());
    _stopScanVisual();
    setState(() {
      _status = VisualVerificationStatus.identifying;
      _isProcessing = false;
      _scanning = false;
      _matchMessage = '';
      _pendingQuestion = null;
      _listeningForAnswer = false;
      _askPartial = '';
      _canAdd = false;
      _awaitingAutoCapture = false;
    });
  }

  String get _hintText => switch (widget.intent) {
        VisualModeIntent.addMedication => 'Scan the package to add it',
        VisualModeIntent.identify => 'Point at any medication package',
        VisualModeIntent.verify => 'Point at the medication package',
      };

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _camera != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _camera!.value.previewSize?.height ??
                    MediaQuery.of(context).size.width,
                height: _camera!.value.previewSize?.width ??
                    MediaQuery.of(context).size.height,
                child: CameraPreview(_camera!),
              ),
            )
          else
            Container(
              color: const Color(0xFF0D1B2E),
              alignment: Alignment.center,
              child: _cameraError != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF3366FF)),
            ),

          // Google Lens-style scan glow
          if (_scanning)
            AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, _) => CustomPaint(
                painter: _LensScanPainter(progress: _scanCtrl.value),
                child: const SizedBox.expand(),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _RoundBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _RoundBtn(
                    icon: Icons.mic_rounded,
                    onTap: _openVoiceMode,
                    tooltip: 'Voice mode',
                  ),
                  const SizedBox(width: 10),
                  _RoundBtn(
                    icon: _flashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          if (_status == VisualVerificationStatus.identifying &&
              !_isProcessing &&
              _awaitingAutoCapture)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 24,
              right: 24,
              child: const Text(
                'Hold steady — capturing…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                ),
              ),
            )
          else if (_status == VisualVerificationStatus.identifying &&
              !_isProcessing &&
              !_awaitingAutoCapture)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 24,
              right: 24,
              child: Text(
                _hintText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _ResultSheet(
              status: _status,
              isProcessing: _isProcessing,
              intent: widget.intent,
              identifiedName:
                  _identifiedName.isNotEmpty ? _identifiedName : 'Medication',
              category: _category.isNotEmpty ? _category : 'Prescription',
              dosage: _dosage,
              matchMessage: _matchMessage.isNotEmpty
                  ? _matchMessage
                  : 'Analyzing package…',
              expectedName:
                  _expectedName.isNotEmpty ? _expectedName : 'Scheduled dose',
              nextDoseTime: _nextDoseTime.isNotEmpty ? _nextDoseTime : '—',
              nextDoseInstruction: _nextDoseInstruction,
              canAdd: _canAdd,
              canConfirm: _canConfirm,
              pendingQuestion: _pendingQuestion,
              listeningForAnswer: _listeningForAnswer,
              askPartial: _askPartial,
              replyController: _replyCtrl,
              replyFocus: _replyFocus,
              bottomPad: bottomPad,
              onCapture: _captureAndAnalyze,
              onConfirm: () => unawaited(_onConfirm()),
              onAdd: () => unawaited(_onAddMedication()),
              onScanAnother: _resetToScan,
              onTryAgain: _resetToScan,
              onOpenVoice: _openVoiceMode,
              onSubmitReply: () {
                final t = _replyCtrl.text;
                _replyCtrl.clear();
                _sendFollowUp(t);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lens scan painter ───────────────────────────────────────────────────────

class _LensScanPainter extends CustomPainter {
  _LensScanPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // Soft edge glows
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3366FF).withValues(alpha: 0.35 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0)),
          Colors.transparent,
          const Color(0xFF8B6BF6).withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edgePaint);

    // Sweeping band
    final bandH = size.height * 0.18;
    final bandRect = Rect.fromLTWH(0, y - bandH / 2, size.width, bandH);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF5B8CFF).withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.55),
          const Color(0xFF5B8CFF).withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    // Bright scan line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // Side pulse bars
    final sideAlpha = (math.sin(progress * math.pi * 2) * 0.5 + 0.5) * 0.45;
    final sidePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3366FF).withValues(alpha: sideAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, 28, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 28, size.height), sidePaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 28, 0, 28, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xFF8B6BF6).withValues(alpha: sideAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(size.width - 28, 0, 28, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _LensScanPainter old) =>
      old.progress != progress;
}

// ─── Bottom sheet ────────────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.status,
    required this.isProcessing,
    required this.intent,
    required this.identifiedName,
    required this.category,
    required this.dosage,
    required this.matchMessage,
    required this.expectedName,
    required this.nextDoseTime,
    required this.nextDoseInstruction,
    required this.canAdd,
    required this.canConfirm,
    required this.pendingQuestion,
    required this.listeningForAnswer,
    required this.askPartial,
    required this.replyController,
    required this.replyFocus,
    required this.bottomPad,
    required this.onCapture,
    required this.onConfirm,
    required this.onAdd,
    required this.onScanAnother,
    required this.onTryAgain,
    required this.onOpenVoice,
    required this.onSubmitReply,
  });

  final VisualVerificationStatus status;
  final bool isProcessing;
  final VisualModeIntent intent;
  final String identifiedName;
  final String category;
  final String dosage;
  final String matchMessage;
  final String expectedName;
  final String nextDoseTime;
  final String nextDoseInstruction;
  final bool canAdd;
  final bool canConfirm;
  final String? pendingQuestion;
  final bool listeningForAnswer;
  final String askPartial;
  final TextEditingController replyController;
  final FocusNode replyFocus;
  final double bottomPad;
  final VoidCallback onCapture;
  final VoidCallback onConfirm;
  final VoidCallback onAdd;
  final VoidCallback onScanAnother;
  final VoidCallback onTryAgain;
  final VoidCallback onOpenVoice;
  final VoidCallback onSubmitReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.58,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(22, 12, 22, 14 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (pendingQuestion != null) ...[
              _AskBanner(
                question: pendingQuestion!,
                listening: listeningForAnswer,
                partial: askPartial,
                controller: replyController,
                focusNode: replyFocus,
                onSubmit: onSubmitReply,
              ),
            ] else
              switch (status) {
              VisualVerificationStatus.identifying => _identifying(),
              VisualVerificationStatus.confirmedMatch ||
              VisualVerificationStatus.identified =>
                _successCard(
                  badge: intent == VisualModeIntent.addMedication
                      ? 'Ready to add'
                      : status == VisualVerificationStatus.identified
                          ? 'Identified'
                          : 'Match',
                  primaryLabel: canConfirm
                      ? (intent == VisualModeIntent.addMedication
                          ? 'Add medication'
                          : 'Confirm taken')
                      : (intent == VisualModeIntent.addMedication
                          ? 'Add medication'
                          : 'OK'),
                  showNextDose: status == VisualVerificationStatus.confirmedMatch ||
                      (status == VisualVerificationStatus.identified &&
                          nextDoseTime != '—'),
                ),
              VisualVerificationStatus.notInList => _notInList(),
              VisualVerificationStatus.confirmedMismatch => _mismatch(),
              VisualVerificationStatus.uncertain => _uncertain(),
            },
            // Follow-up chat only when not mid-ask (ask is voice-first).
            if (pendingQuestion == null &&
                status != VisualVerificationStatus.identifying) ...[
              const SizedBox(height: 10),
              _FollowUpField(
                controller: replyController,
                focusNode: replyFocus,
                onSubmit: onSubmitReply,
                enabled: !isProcessing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _identifying() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF3366FF),
                ),
              )
            else
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF3366FF), size: 22),
            const SizedBox(width: 10),
            Text(
              isProcessing ? 'Scanning…' : 'Ready',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isProcessing
              ? 'Reading the package with AI'
              : 'Tap to capture, or wait for auto-capture',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: isProcessing ? null : onCapture,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3366FF), width: 4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3366FF).withValues(alpha: 0.3),
                  blurRadius: 18,
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isProcessing
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF3366FF),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenVoice,
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: const Text('Ask with voice'),
        ),
      ],
    );
  }

  Widget _successCard({
    required String badge,
    required String primaryLabel,
    required bool showNextDose,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                identifiedName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                ),
              ),
            ),
            _Badge(label: badge, color: const Color(0xFF15803D)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (dosage.isNotEmpty) dosage,
            if (category.isNotEmpty) category,
          ].join(' · '),
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        _InfoBanner(
          color: const Color(0xFFEAF8F1),
          border: const Color(0xFFBBF7D0),
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF15803D),
          text: matchMessage,
          textColor: const Color(0xFF166534),
        ),
        if (showNextDose) ...[
          const SizedBox(height: 12),
          _NextDoseCard(time: nextDoseTime, instruction: nextDoseInstruction),
        ],
        const SizedBox(height: 16),
        _PrimaryBtn(label: primaryLabel, onTap: onConfirm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: onScanAnother, child: const Text('Scan another')),
            TextButton.icon(
              onPressed: onOpenVoice,
              icon: const Icon(Icons.mic_rounded, size: 16),
              label: const Text('Voice'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notInList() {
    return Column(
      children: [
        const Icon(Icons.medication_outlined, size: 40, color: Color(0xFF3366FF)),
        const SizedBox(height: 10),
        Text(
          identifiedName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          matchMessage.isNotEmpty
              ? matchMessage
              : 'This isn\'t in your medication list yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        if (dosage.isNotEmpty || category.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            [dosage, category].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (canAdd) _PrimaryBtn(label: 'Add to my medications', onTap: onAdd),
        TextButton(onPressed: onTryAgain, child: const Text('Scan again')),
      ],
    );
  }

  Widget _mismatch() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF04438),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        const Text(
          'Not your medication',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          matchMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        _InfoBanner(
          color: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
          icon: Icons.medication_rounded,
          iconColor: const Color(0xFFB91C1C),
          text: 'You need: $expectedName'
              '${nextDoseInstruction.isNotEmpty ? ' · $nextDoseInstruction' : ''}',
          textColor: const Color(0xFF7F1D1D),
        ),
        const SizedBox(height: 16),
        _PrimaryBtn(label: 'Try again', onTap: onTryAgain),
        TextButton.icon(
          onPressed: onOpenVoice,
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: const Text('Continue in voice'),
        ),
      ],
    );
  }

  Widget _uncertain() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF8B6BF6),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(Icons.help_outline_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        const Text(
          'I\'m not sure',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          matchMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        _PrimaryBtn(label: 'Try again', onTap: onTryAgain),
        TextButton.icon(
          onPressed: onOpenVoice,
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: const Text('Describe with voice'),
        ),
      ],
    );
  }
}

class _AskBanner extends StatelessWidget {
  const _AskBanner({
    required this.question,
    required this.listening,
    required this.partial,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final String question;
  final bool listening;
  final String partial;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certo asks',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4338CA),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: listening
                      ? const Color(0xFF3366FF)
                      : const Color(0xFF94A3B8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  partial.trim().isNotEmpty
                      ? partial
                      : (listening
                          ? 'Listening… speak your answer'
                          : 'Waiting…'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: partial.trim().isNotEmpty
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                    fontStyle: partial.trim().isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'Or type…',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onSubmit,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3366FF),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowUpField extends StatelessWidget {
  const _FollowUpField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Ask a follow-up…',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: enabled ? onSubmit : null,
          style: IconButton.styleFrom(backgroundColor: const Color(0xFF3366FF)),
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
  });

  final Color color;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({required this.time, required this.instruction});
  final String time;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT DOSE',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded,
                  color: Color(0xFF3366FF), size: 18),
              const SizedBox(width: 8),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                instruction,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3366FF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}
