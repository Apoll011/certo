import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
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
///
/// Usage:
/// ```dart
/// final svc = ElevenLabsService();
/// svc.events.listen((e) { ... });
/// await svc.startListening();        // begins STT session
/// await svc.stopListening();         // ends STT, gets final transcript
/// await svc.speak("Hello world!");   // streams TTS audio
/// svc.dispose();
/// ```
class ElevenLabsService {
  ElevenLabsService();

  static const String _sttEndpoint =
      'wss://api.elevenlabs.io/v1/speech-to-text/stream';

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

  /// Starts a Scribe v2 Realtime session and streams mic audio.
  Future<void> startListening() async {
    if (_listening) return;

    final apiKey = AppConfig.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _emit(VoiceError('ElevenLabs API key not configured'));
      return;
    }

    // Check mic permission.
    if (!await _recorder.hasPermission()) {
      _emit(VoiceError('Microphone permission denied'));
      return;
    }

    // Open WebSocket to Scribe v2 Realtime endpoint.
    final uri = Uri.parse(
      '$_sttEndpoint?model_id=${AppConfig.elevenLabsSttModel}'
      '&language=en'
      '&sample_rate=16000'
      '&encoding=pcm_s16le'
      '&inactivity_timeout=60',
    );

    try {
      _wsChannel = WebSocketChannel.connect(
        uri,
        protocols: const [],
      );

      // Send auth handshake as first message.
      _wsChannel!.sink.add(
        jsonEncode({'type': 'authorization', 'authorization': apiKey}),
      );
    } catch (e) {
      _emit(VoiceError('Failed to connect to STT: $e'));
      return;
    }

    _wsSub = _wsChannel!.stream.listen(
      _onSttMessage,
      onError: (e) => _emit(VoiceError('STT WebSocket error: $e')),
      onDone: () => _listening = false,
    );

    // Start mic recording as raw PCM stream (16-bit, 16kHz, mono).
    final audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSub = audioStream.listen((chunk) {
      if (_wsChannel == null) return;
      // Send as base64-encoded audio chunk.
      _wsChannel!.sink.add(
        jsonEncode({
          'type': 'audio_chunk',
          'audio_chunk': base64Encode(chunk),
        }),
      );
    });

    _listening = true;
    debugPrint('ElevenLabs STT: listening started');
  }

  void _onSttMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'transcript') {
        final text = (msg['transcript'] as String?) ?? '';
        final isFinal = msg['is_final'] == true;
        if (text.isEmpty) return;
        _emit(isFinal ? TranscriptionFinal(text) : TranscriptionPartial(text));
      } else if (type == 'error') {
        _emit(VoiceError(msg['message'] as String? ?? 'STT error'));
      }
    } catch (e) {
      debugPrint('ElevenLabs STT: malformed message — $e');
    }
  }

  /// Stops microphone capture and closes the STT WebSocket.
  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;

    await _audioSub?.cancel();
    _audioSub = null;

    await _recorder.stop();

    // Ask the server to flush any buffered audio.
    try {
      _wsChannel?.sink.add(jsonEncode({'type': 'end_of_input'}));
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    debugPrint('ElevenLabs STT: listening stopped');
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  /// Converts [text] to speech using eleven_v3 (Conversacional) and emits
  /// [TtsAudioChunk] events with streaming MP3 bytes, followed by [TtsDone].
  Future<void> speak(String text) async {
    final apiKey = AppConfig.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _emit(VoiceError('ElevenLabs API key not configured'));
      return;
    }

    final voiceId = AppConfig.elevenLabsVoiceId;
    final url = Uri.parse('$_ttsEndpoint/$voiceId/stream');

    final body = jsonEncode({
      'text': text,
      'model_id': AppConfig.elevenLabsTtsModel,
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

      final response = await request.send();

      if (response.statusCode != 200) {
        final bodyStr = await response.stream.bytesToString();
        _emit(VoiceError('TTS error ${response.statusCode}: $bodyStr'));
        return;
      }

      await for (final chunk in response.stream) {
        _emit(TtsAudioChunk(Uint8List.fromList(chunk)));
      }

      _emit(TtsDone());
      debugPrint('ElevenLabs TTS: done');
    } catch (e) {
      _emit(VoiceError('TTS request failed: $e'));
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
