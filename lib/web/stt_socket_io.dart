import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectSttSocket(
  Uri uri, {
  required String apiKey,
}) async {
  return IOWebSocketChannel.connect(
    uri,
    headers: {'xi-api-key': apiKey},
    pingInterval: const Duration(seconds: 15),
  );
}
