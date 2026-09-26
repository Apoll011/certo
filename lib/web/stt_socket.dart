import 'package:web_socket_channel/web_socket_channel.dart';

import 'stt_socket_stub.dart'
    if (dart.library.io) 'stt_socket_io.dart'
    if (dart.library.html) 'stt_socket_web.dart' as impl;

/// Opens the ElevenLabs STT WebSocket with platform-appropriate auth.
///
/// Native: `xi-api-key` header. Web: single-use `token` query param.
Future<WebSocketChannel> connectSttSocket(
  Uri uri, {
  required String apiKey,
}) =>
    impl.connectSttSocket(uri, apiKey: apiKey);
