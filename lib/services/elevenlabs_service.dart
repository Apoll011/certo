import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// Events emitted by [ElevenLabsService] during a voice session.
sealed class VoiceEvent {}

/// A partial (in-progress) transcription segment.
class TranscriptionPartial extends VoiceEvent {
  TranscriptionPartial(this.text);
  final String text;
}

/// A final, committed transcription segment.
class TranscriptionFinal extends VoiceEvent {
  TranscriptionFinal(this.text);
  final String text;
}

/// A chunk of TTS audio bytes (MP3).
class TtsAudioChunk extends VoiceEvent {
  TtsAudioChunk(this.bytes);
  final Uint8List bytes;
}

/// The TTS stream finished sending all bytes.
class TtsDone extends VoiceEvent {}

/// User speech detected while TTS was playing (barge-in).
class BargeInDetected extends VoiceEvent {}

/// An error occurred.
class VoiceError extends VoiceEvent {
  VoiceError(this.message);
  final String message;
}

/// Manages ElevenLabs STT (Scribe v2 Realtime) and TTS sessions.
///
/// Mic transcription uses the server-side **VAD commit strategy**: the model
/// detects when the user stops speaking (not a fixed wall-clock timer), which
/// holds up much better in noisy rooms. Background audio filtering is enabled.
class ElevenLabsService {
  ElevenLabsService({
    this.vadSilenceThresholdSecs = 1.2,
    this.vadThreshold = 0.5,
    this.minSpeechDurationMs = 120,
    this.minSilenceDurationMs = 120,
  });

  /// How long the user must be silent (speech stopped) before VAD commits.
  final double vadSilenceThresholdSecs;

  /// Voice-activity sensitivity (0–1). Higher = less likely to treat noise as speech.
  final double vadThreshold;

  final int minSpeechDurationMs;
  final int minSilenceDurationMs;

  // Official ElevenLabs Scribe v2 Realtime WebSocket endpoint
  static const String _sttHost = 'api.elevenlabs.io';
  static const String _sttPath = '/v1/speech-to-text/realtime';

  static const String _ttsEndpoint =
      'https://api.elevenlabs.io/v1/text-to-speech';

  final _eventController = StreamController<VoiceEvent>.broadcast();

  /// Broadcast stream of all voice session events.
  Stream<VoiceEvent> get events => _eventController.stream;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  bool _listening = false;
  bool _ttsCancelled = false;

  /// Mic RMS monitor used while TTS plays so the user can interrupt.
  bool _bargeInActive = false;
  StreamSubscription<Uint8List>? _bargeInSub;
  int _bargeInHotChunks = 0;
  DateTime? _bargeInArmedAt;

  // ── STT ────────────────────────────────────────────────────────────────────

  /// Starts a Scribe v2 Realtime session and streams mic audio over WebSocket.
  Future<void> startListening() async {
    if (_listening) return;

    final apiKey = AppConfig.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _emit(VoiceError(
        'ElevenLabs API key is missing. Set ELEVENLABS_API_KEY with --dart-define.',
      ));
      return;
    }

    // Check mic permission.
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        _emit(VoiceError('Microphone permission denied. Please allow microphone access in settings.'));
        return;
      }
    } catch (e) {
      _emit(VoiceError('Failed to check microphone permission: $e'));
      return;
    }

    // VAD commit strategy: server detects end-of-speech and emits
    // committed_transcript. filter_background_audio helps in loud rooms.
    final uri = Uri(
      scheme: 'wss',
      host: _sttHost,
      path: _sttPath,
      queryParameters: {
        'model_id': AppConfig.elevenLabsSttModel,
        'audio_format': 'pcm_16000',
        'commit_strategy': 'vad',
        'vad_silence_threshold_secs': vadSilenceThresholdSecs.toString(),
        'vad_threshold': vadThreshold.toString(),
        'min_speech_duration_ms': minSpeechDurationMs.toString(),
        'min_silence_duration_ms': minSilenceDurationMs.toString(),
        'filter_background_audio': 'true',
      },
    );

    try {
      debugPrint('ElevenLabs STT: connecting to $uri ...');
      _wsChannel = IOWebSocketChannel.connect(
        uri,
        headers: {'xi-api-key': apiKey},
        pingInterval: const Duration(seconds: 15),
      );

      // Wait for handshake
      await _wsChannel!.ready;
      debugPrint('ElevenLabs STT: WebSocket connected successfully!');
    } on WebSocketChannelException catch (e) {
      debugPrint('ElevenLabs STT: WebSocketChannelException: $e');
      _emit(VoiceError('STT connection error: $e'));
      _wsChannel = null;
      return;
    } catch (e) {
      debugPrint('ElevenLabs STT: Connection failed: $e');
      _emit(VoiceError('STT connection failed: $e'));
      _wsChannel = null;
      return;
    }

    _wsSub = _wsChannel!.stream.listen(
      _onSttMessage,
      onError: (Object e) {
        debugPrint('ElevenLabs STT: Stream error: $e');
        _emit(VoiceError('STT stream error: $e'));
      },
      onDone: () {
        debugPrint('ElevenLabs STT: WebSocket closed by server');
        _listening = false;
      },
    );

    // Start mic recording as raw PCM stream (16-bit, 16kHz, mono).
    try {
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSub = audioStream.listen((chunk) {
        if (_wsChannel == null) return;
        // Scribe realtime requires commit + sample_rate on every chunk.
        try {
          _wsChannel!.sink.add(
            jsonEncode({
              'message_type': 'input_audio_chunk',
              'audio_base_64': base64Encode(chunk),
              'commit': false,
              'sample_rate': 16000,
            }),
          );
        } catch (e) {
          debugPrint('ElevenLabs STT: failed to send audio chunk: $e');
        }
      });

      _listening = true;
      debugPrint('ElevenLabs STT: microphone streaming started (VAD commit)');
    } catch (e) {
      debugPrint('ElevenLabs STT: failed to start mic recorder: $e');
      _emit(VoiceError('Microphone recording failed: $e'));
      await stopListening();
    }
  }

  void _onSttMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final msgType = (msg['message_type'] as String?) ?? (msg['type'] as String?);

      debugPrint('ElevenLabs STT received: $msgType');

      switch (msgType) {
        case 'session_started':
          debugPrint(
            'ElevenLabs STT: session started: ${msg['session_id']} '
            'config=${msg['config']}',
          );

        case 'partial_transcript':
          final text = (msg['text'] as String?) ?? '';
          if (text.isNotEmpty) {
            _emit(TranscriptionPartial(text));
          }

        case 'committed_transcript':
        case 'committed_transcript_with_timestamps':
          // VAD (or manual commit) finalized this utterance segment.
          final text = (msg['text'] as String?) ?? '';
          if (text.isNotEmpty) {
            _emit(TranscriptionFinal(text));
          }

        case 'rate_limited':
        case 'error':
          final err = (msg['error'] as String?) ??
              (msg['message'] as String?) ??
              'STT error ($msgType)';
          debugPrint('ElevenLabs STT error: $err');
          _emit(VoiceError(err));

        case 'warning':
          debugPrint('ElevenLabs STT warning: ${msg['warning']}');

        default:
          debugPrint('ElevenLabs STT unhandled message: $raw');
      }
    } catch (e) {
      debugPrint('ElevenLabs STT: malformed message: $e — $raw');
    }
  }

  /// Stops microphone capture and closes the STT WebSocket.
  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    // Flush any remaining buffered speech as a final commit.
    try {
      _wsChannel?.sink.add(
        jsonEncode({
          'message_type': 'input_audio_chunk',
          'audio_base_64': '',
          'commit': true,
          'sample_rate': 16000,
        }),
      );
    } catch (_) {}

    // Give server a brief window to commit
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _wsChannel?.sink.close(WebSocketStatus.normalClosure);
    } catch (_) {}
    _wsChannel = null;
    debugPrint('ElevenLabs STT: listening stopped');
  }

  // ── Barge-in (speech while TTS plays) ─────────────────────────────────────

  /// Opens the mic and watches PCM energy. Emits [BargeInDetected] once when
  /// the user speaks over the AI (after a short arming delay to avoid echo).
  Future<void> startBargeInMonitor({
    double rmsThreshold = 0.06,
    int consecutiveChunks = 4,
    Duration armDelay = const Duration(milliseconds: 400),
  }) async {
    await stopBargeInMonitor();
    if (_listening) return;

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) return;
    } catch (_) {
      return;
    }

    _bargeInHotChunks = 0;
    _bargeInArmedAt = DateTime.now().add(armDelay);
    _bargeInActive = true;

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _bargeInSub = stream.listen((chunk) {
        if (!_bargeInActive) return;
        final armedAt = _bargeInArmedAt;
        if (armedAt != null && DateTime.now().isBefore(armedAt)) {
          return;
        }

        final rms = _pcm16Rms(chunk);
        if (rms >= rmsThreshold) {
          _bargeInHotChunks += 1;
          if (_bargeInHotChunks >= consecutiveChunks) {
            _bargeInActive = false;
            debugPrint('ElevenLabs: barge-in detected (rms=$rms)');
            _emit(BargeInDetected());
            // Stop mic async; don't block the stream callback.
            unawaited(stopBargeInMonitor());
          }
        } else {
          _bargeInHotChunks = 0;
        }
      });
      debugPrint('ElevenLabs: barge-in monitor started');
    } catch (e) {
      debugPrint('ElevenLabs: barge-in monitor failed: $e');
      _bargeInActive = false;
    }
  }

  /// Stops the barge-in mic monitor (safe if not running).
  Future<void> stopBargeInMonitor() async {
    _bargeInActive = false;
    _bargeInHotChunks = 0;
    _bargeInArmedAt = null;
    await _bargeInSub?.cancel();
    _bargeInSub = null;
    // Only stop the recorder if we aren't in a normal STT listen session.
    if (!_listening) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
  }

  static double _pcm16Rms(Uint8List chunk) {
    final sampleCount = chunk.length ~/ 2;
    if (sampleCount == 0) return 0;
    var sumSq = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final lo = chunk[i * 2];
      final hi = chunk[i * 2 + 1];
      var sample = lo | (hi << 8);
      if (sample >= 0x8000) sample -= 0x10000;
      sumSq += sample * sample;
    }
    return math.sqrt(sumSq / sampleCount) / 32768.0;
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  /// Stops emitting further TTS chunks for the in-flight [speak] call.
  void cancelSpeak() {
    _ttsCancelled = true;
  }

  /// Converts [text] to speech using ElevenLabs TTS and emits
  /// [TtsAudioChunk] events with streaming MP3 bytes, followed by [TtsDone].
  Future<void> speak(String text) async {
    final apiKey = AppConfig.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _emit(VoiceError('ElevenLabs API key is missing. Set ELEVENLABS_API_KEY with --dart-define.'));
      return;
    }

    _ttsCancelled = false;

    final voiceId = AppConfig.elevenLabsVoiceId;
    final primaryModel = AppConfig.elevenLabsTtsModel;

    // Prioritize configured model, then fallback to other reliable models
    final modelsToTry = <String>[
      primaryModel,
      if (primaryModel != 'eleven_flash_v2_5') 'eleven_flash_v2_5',
      if (primaryModel != 'eleven_multilingual_v2') 'eleven_multilingual_v2',
      if (primaryModel != 'eleven_v3') 'eleven_v3',
    ];

    String? lastError;

    for (final modelId in modelsToTry) {
      if (_ttsCancelled) return;
      debugPrint('ElevenLabs TTS: trying model $modelId with voice $voiceId...');
      final (success, errorMsg) = await _fetchTtsStream(
        voiceId: voiceId,
        apiKey: apiKey,
        text: text,
        modelId: modelId,
      );

      if (success) {
        return;
      }
      lastError = errorMsg;
      debugPrint('ElevenLabs TTS: model $modelId failed ($lastError), trying fallback...');
    }

    if (!_ttsCancelled) {
      _emit(VoiceError(lastError ?? 'TTS synthesis failed. Check your API key and voice ID.'));
    }
  }

  Future<(bool, String?)> _fetchTtsStream({
    required String voiceId,
    required String apiKey,
    required String text,
    required String modelId,
  }) async {
    final url = Uri.parse('$_ttsEndpoint/$voiceId/stream?output_format=mp3_44100_128');

    final body = jsonEncode({
      'text': text,
      'model_id': modelId,
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.75,
      },
    });

    try {
      final request = http.Request('POST', url)
        ..headers['xi-api-key'] = apiKey
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'audio/mpeg'
        ..body = body;

      final response = await request.send();

      if (response.statusCode != 200) {
        final bodyStr = await response.stream.bytesToString();
        debugPrint('ElevenLabs TTS error ${response.statusCode} ($modelId): $bodyStr');
        return (false, 'TTS error (${response.statusCode}): $bodyStr');
      }

      await for (final chunk in response.stream) {
        if (_ttsCancelled) {
          debugPrint('ElevenLabs TTS: cancelled mid-stream');
          return (true, null);
        }
        _emit(TtsAudioChunk(Uint8List.fromList(chunk)));
      }

      if (!_ttsCancelled) {
        _emit(TtsDone());
        debugPrint('ElevenLabs TTS: streaming finished successfully with $modelId');
      }
      return (true, null);
    } catch (e) {
      debugPrint('ElevenLabs TTS exception ($modelId): $e');
      return (false, 'TTS connection error: $e');
    }
  }

  void _emit(VoiceEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Releases all resources.
  Future<void> dispose() async {
    await stopBargeInMonitor();
    await stopListening();
    await _eventController.close();
    _recorder.dispose();
  }
}
