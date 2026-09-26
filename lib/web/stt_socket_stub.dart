import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectSttSocket(
  Uri uri, {
  required String apiKey,
}) async {
  throw UnsupportedError('STT WebSocket is not supported on this platform');
}
