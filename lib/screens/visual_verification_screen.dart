import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// Entry helper to launch Visual Verification Mode.
Future<void> showVisualVerificationScreen(
  BuildContext context, {
  Medication? targetMedication,
  String? expectedMedicationName,
  VisualVerificationStatus initialStatus = VisualVerificationStatus.identifying,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => VisualVerificationScreen(
        targetMedication: targetMedication,
        expectedMedicationName: expectedMedicationName,
        initialStatus: initialStatus,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// Camera-first visual medication verification with DeepSeek vision + tools.
class VisualVerificationScreen extends StatefulWidget {
  const VisualVerificationScreen({
    super.key,
    this.targetMedication,
    this.expectedMedicationName,
    this.initialStatus = VisualVerificationStatus.identifying,
  });

  final Medication? targetMedication;
  final String? expectedMedicationName;
  final VisualVerificationStatus initialStatus;

  @override
  State<VisualVerificationScreen> createState() =>
      _VisualVerificationScreenState();
}

class _VisualVerificationScreenState extends State<VisualVerificationScreen> {
  CameraController? _camera;
  bool _cameraReady = false;
  String? _cameraError;
  bool _flashOn = false;
  bool _isProcessing = false;

  late VisualVerificationStatus _status;

  String _identifiedName = '';
  String _category = '';
  String _matchMessage = '';
  String _expectedName = '';
  String _nextDoseTime = '';
  String _nextDoseInstruction = '';

  final ElevenLabsService _voice = ElevenLabsService();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<VoiceEvent>? _voiceSub;
  final List<int> _ttsBuffer = [];
  Completer<void>? _ttsDone;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _voiceSub = _voice.events.listen(_onVoiceEvent);
    _player.onPlayerComplete.listen((_) {
      if (_ttsDone != null && !_ttsDone!.isCompleted) {
        _ttsDone!.complete();
      }
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
      case VoiceError(:final message):
        debugPrint('VisualMode TTS error: $message');
        if (_ttsDone != null && !_ttsDone!.isCompleted) {
          _ttsDone!.complete();
        }
      default:
        break;
    }
  }

  Future<void> _playTtsBuffer() async {
    if (_ttsBuffer.isEmpty) {
      if (_ttsDone != null && !_ttsDone!.isCompleted) {
        _ttsDone!.complete();
      }
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
      if (_ttsDone != null && !_ttsDone!.isCompleted) {
        _ttsDone!.complete();
      }
    }
  }

  void _initFromSchedule() {
    final appState = Provider.of<AppState>(context, listen: false);
    final active = appState.medicationsWithStatus(MedicationStatus.active);

    final target = widget.targetMedication ??
        (active.isNotEmpty ? active.first : null);

    final expectedOverride = widget.expectedMedicationName?.trim();
    if (expectedOverride != null && expectedOverride.isNotEmpty) {
      _expectedName = expectedOverride;
      _identifiedName = expectedOverride;
    } else if (target != null) {
      _identifiedName = target.name;
      _expectedName = target.name;
      _category =
          target.category.isNotEmpty ? target.category : 'Oral prescription';
      _nextDoseTime = target.firstTime;
      _nextDoseInstruction = target.dosageLine;
    }

    // Prefer a dose that is due right now when no override was given.
    if (expectedOverride == null || expectedOverride.isEmpty) {
      final dues = dueDoses(appState.medications, DateTime.now());
      if (dues.isNotEmpty) {
        final due = dues.first;
        _expectedName = due.medication.name;
        _nextDoseTime = due.time;
        _nextDoseInstruction = due.medication.dosageLine;
        _category = due.medication.category.isNotEmpty
            ? due.medication.category
            : _category;
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

      // Prefer back camera for package scanning.
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
    } catch (e) {
      debugPrint('VisualMode: camera init failed: $e');
      if (mounted) {
        setState(() => _cameraError = 'Camera unavailable: $e');
      }
    }
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    _camera?.dispose();
    _voice.dispose();
    _player.dispose();
    if (_ttsDone != null && !_ttsDone!.isCompleted) {
      _ttsDone!.complete();
    }
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
      debugPrint('VisualMode: flash toggle failed: $e');
    }
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
            'DeepSeek API key missing. Add AI_API_KEY to .env and restart with --dart-define-from-file=.env';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = VisualVerificationStatus.identifying;
      _cameraError = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final file = await cam.takePicture();
      final bytes = await File(file.path).readAsBytes();
      // Keep payload reasonable for the API.
      final b64 = base64Encode(bytes);

      if (!mounted) return;

      VisualVerificationCardData? card;

      final assistant = appState.createAiAssistant(
        systemPrompt: AiAssistantService.defaultSystemPrompt(
          userName: appState.userName,
          now: DateTime.now(),
          voiceMode: true,
        ),
        onSpeak: (text) async {
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
            if (_ttsDone != null && !_ttsDone!.isCompleted) {
              _ttsDone!.complete();
            }
            _ttsDone = null;
          }
        },
        onShowVisualResult: (data) {
          card = data;
          if (!mounted) return;
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
            }
            if (data.nextDoseInstruction != null) {
              _nextDoseInstruction = data.nextDoseInstruction!;
            }
          });
        },
      );

      final prompt = AiAssistantService.visualVerificationPrompt(
        expectedMedicationName: _expectedName.isNotEmpty ? _expectedName : null,
      );

      final result = await assistant.verifyMedicationImage(
        imageBase64: b64,
        userPrompt: prompt,
      );

      if (!mounted) return;

      if (card == null) {
        // Model forgot the tool — fall back to uncertain + any text reply.
        setState(() {
          _status = VisualVerificationStatus.uncertain;
          _matchMessage = result.response.trim().isNotEmpty
              ? result.response.trim()
              : 'I couldn\'t verify this confidently. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('VisualMode: analyze failed: $e');
      if (mounted) {
        setState(() {
          _status = VisualVerificationStatus.uncertain;
          _matchMessage = 'Analysis failed: $e';
          _cameraError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onConfirmDose() {
    final appState = Provider.of<AppState>(context, listen: false);
    final med = findMedication(
      appState,
      name: _identifiedName.isNotEmpty ? _identifiedName : _expectedName,
    );
    if (med != null) {
      appState.markTaken(med.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          med != null
              ? '✓ Marked "${med.name}" as taken.'
              : '✓ Confirmed.',
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  void _resetToScan() {
    setState(() {
      _status = VisualVerificationStatus.identifying;
      _isProcessing = false;
      _matchMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Live camera preview ─────────────────────────────────────────
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
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF3366FF)),
            ),

          // Dim overlay while processing
          if (_isProcessing)
            Container(color: Colors.black.withValues(alpha: 0.35)),

          // ── Top controls ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundHeaderBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _RoundHeaderBtn(
                    icon: _flashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          // Hint when idle
          if (_status == VisualVerificationStatus.identifying && !_isProcessing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 24,
              right: 24,
              child: const Text(
                'Point at the medication package',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),

          // ── Bottom sheet ────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _VerificationBottomSheet(
              status: _status,
              isProcessing: _isProcessing,
              identifiedName: _identifiedName.isNotEmpty
                  ? _identifiedName
                  : 'Medication',
              category: _category.isNotEmpty ? _category : 'Prescription',
              matchMessage: _matchMessage.isNotEmpty
                  ? _matchMessage
                  : 'This is your medication. It\'s scheduled for now.',
              expectedName:
                  _expectedName.isNotEmpty ? _expectedName : 'Scheduled dose',
              nextDoseTime:
                  _nextDoseTime.isNotEmpty ? _nextDoseTime : '—',
              nextDoseInstruction: _nextDoseInstruction.isNotEmpty
                  ? _nextDoseInstruction
                  : '',
              onCapture: _captureAndAnalyze,
              onConfirm: _onConfirmDose,
              onScanAnother: _resetToScan,
              onTryAgain: _resetToScan,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom sheet (3-state Certo safety model)
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationBottomSheet extends StatelessWidget {
  const _VerificationBottomSheet({
    required this.status,
    required this.isProcessing,
    required this.identifiedName,
    required this.category,
    required this.matchMessage,
    required this.expectedName,
    required this.nextDoseTime,
    required this.nextDoseInstruction,
    required this.onCapture,
    required this.onConfirm,
    required this.onScanAnother,
    required this.onTryAgain,
  });

  final VisualVerificationStatus status;
  final bool isProcessing;
  final String identifiedName;
  final String category;
  final String matchMessage;
  final String expectedName;
  final String nextDoseTime;
  final String nextDoseInstruction;
  final VoidCallback onCapture;
  final VoidCallback onConfirm;
  final VoidCallback onScanAnother;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          switch (status) {
            VisualVerificationStatus.identifying => _buildIdentifyingState(),
            VisualVerificationStatus.confirmedMatch =>
              _buildConfirmedMatchState(),
            VisualVerificationStatus.confirmedMismatch =>
              _buildConfirmedMismatchState(),
            VisualVerificationStatus.uncertain => _buildUncertainState(),
          },
        ],
      ),
    );
  }

  Widget _buildIdentifyingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF3366FF),
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF3366FF),
                    size: 20,
                  ),
            const SizedBox(width: 8),
            Text(
              isProcessing
                  ? 'Analyzing with AI…'
                  : 'Ready to scan',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isProcessing
              ? 'Checking the package against your schedule.'
              : 'Tap the button to capture and verify.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: isProcessing ? null : onCapture,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3366FF), width: 3.5),
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
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildConfirmedMatchState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                identifiedName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA3E7C3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF0E9347),
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Identified',
                    style: TextStyle(
                      color: Color(0xFF0E9347),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          category,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF15803D),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  matchMessage,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
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
                  const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF3366FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nextDoseTime,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    nextDoseInstruction,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
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
            onPressed: onConfirm,
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: onScanAnother,
            child: const Text(
              'Scan another',
              style: TextStyle(
                color: Color(0xFF3366FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedMismatchState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF04438),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.white, size: 26),
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
        const SizedBox(height: 6),
        Text(
          matchMessage.isNotEmpty
              ? matchMessage
              : 'This isn\'t the medication scheduled for now. Please scan another package.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Container(
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
                'YOU NEED',
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
                  Expanded(
                    child: Text(
                      expectedName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    nextDoseInstruction,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
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
            onPressed: onTryAgain,
            child: const Text(
              'Try again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUncertainState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF8B6BF6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 26),
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
        const SizedBox(height: 6),
        Text(
          matchMessage.isNotEmpty
              ? matchMessage
              : 'I can\'t identify this medication confidently. Please move closer and scan again.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
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
            onPressed: onTryAgain,
            child: const Text(
              'Try again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundHeaderBtn extends StatelessWidget {
  const _RoundHeaderBtn({required this.icon, required this.onTap});

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
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
