import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// An error occurred.
class VoiceError extends VoiceEvent {
  VoiceError(this.message);
  final String message;
}

/// Manages ElevenLabs STT (Scribe v2 Realtime) and TTS (eleven_v3) sessions.
class ElevenLabsService {
  ElevenLabsService();

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

    // Scribe v2 Realtime WebSocket URI:
    // wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=scribe_v2_realtime&audio_format=pcm_16000
    final uri = Uri(
      scheme: 'wss',
      host: _sttHost,
      path: _sttPath,
      queryParameters: {
        'model_id': AppConfig.elevenLabsSttModel,
        'audio_format': 'pcm_16000',
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
        // ElevenLabs Scribe v2 Realtime expects:
        // {"message_type": "input_audio_chunk", "audio_base_64": "..."}
        try {
          _wsChannel!.sink.add(
            jsonEncode({
              'message_type': 'input_audio_chunk',
              'audio_base_64': base64Encode(chunk),
            }),
          );
        } catch (e) {
          debugPrint('ElevenLabs STT: failed to send audio chunk: $e');
        }
      });

      _listening = true;
      debugPrint('ElevenLabs STT: microphone streaming started');
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
          debugPrint('ElevenLabs STT: session started: ${msg['session_id']}');

        case 'partial_transcript':
          final text = (msg['text'] as String?) ?? '';
          if (text.isNotEmpty) {
            _emit(TranscriptionPartial(text));
          }

        case 'committed_transcript':
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

    // Ask server to commit any remaining audio
    try {
      _wsChannel?.sink.add(jsonEncode({
        'message_type': 'input_audio_chunk',
        'audio_base_64': '',
        'commit': true,
      }));
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

  // ── TTS ────────────────────────────────────────────────────────────────────

  /// Converts [text] to speech using eleven_v3 (Conversacional) and emits
  /// [TtsAudioChunk] events with streaming MP3 bytes, followed by [TtsDone].
  Future<void> speak(String text) async {
    final apiKey = AppConfig.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _emit(VoiceError('ElevenLabs API key missing'));
      return;
    }

    final voiceId = AppConfig.elevenLabsVoiceId;
    final url = Uri.parse('$_ttsEndpoint/$voiceId/stream');

    // First try with eleven_v3
    var modelId = AppConfig.elevenLabsTtsModel;
    bool success = await _fetchTtsStream(url, apiKey, text, modelId);

    // If eleven_v3 is not available on this tier, gracefully fall back to eleven_multilingual_v2
    if (!success && modelId == 'eleven_v3') {
      debugPrint('ElevenLabs TTS: eleven_v3 failed, falling back to eleven_multilingual_v2...');
      modelId = 'eleven_multilingual_v2';
      success = await _fetchTtsStream(url, apiKey, text, modelId);
    }

    if (!success) {
      _emit(VoiceError('TTS synthesis failed'));
    }
  }

  Future<bool> _fetchTtsStream(
    Uri url,
    String apiKey,
    String text,
    String modelId,
  ) async {
    final body = jsonEncode({
      'text': text,
      'model_id': modelId,
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.75,
        'style': 0.3,
        'use_speaker_boost': true,
      },
      'output_format': 'mp3_44100_128',
    });

    try {
      final request = http.Request('POST', url)
        ..headers['xi-api-key'] = apiKey
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'audio/mpeg'
        ..body = body;

      debugPrint('ElevenLabs TTS: requesting speech with model $modelId...');
      final response = await request.send();

      if (response.statusCode != 200) {
        final bodyStr = await response.stream.bytesToString();
        debugPrint('ElevenLabs TTS error ${response.statusCode}: $bodyStr');
        return false;
      }

      await for (final chunk in response.stream) {
        _emit(TtsAudioChunk(Uint8List.fromList(chunk)));
      }

      _emit(TtsDone());
      debugPrint('ElevenLabs TTS: streaming finished successfully');
      return true;
    } catch (e) {
      debugPrint('ElevenLabs TTS exception: $e');
      return false;
    }
  }

  void _emit(VoiceEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Releases all resources.
  Future<void> dispose() async {
    await stopListening();
    await _eventController.close();
    _recorder.dispose();
  }
}
