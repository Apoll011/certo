import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Browser WebSockets cannot set custom headers, so we mint a single-use
/// token via HTTPS and pass it as the `token` query parameter.
Future<WebSocketChannel> connectSttSocket(
  Uri uri, {
  required String apiKey,
}) async {
  final token = await _mintRealtimeScribeToken(apiKey);
  final params = Map<String, String>.from(uri.queryParameters);
  params['token'] = token;
  return WebSocketChannel.connect(uri.replace(queryParameters: params));
}

Future<String> _mintRealtimeScribeToken(String apiKey) async {
  final response = await http.post(
    Uri.parse('https://api.elevenlabs.io/v1/single-use-token/realtime_scribe'),
    headers: {'xi-api-key': apiKey},
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Failed to mint STT token (${response.statusCode}): ${response.body}',
    );
  }
  final body = response.body.trim();
  if (body.startsWith('{')) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['token'] is String) {
      return decoded['token'] as String;
    }
  }
  if (body.isNotEmpty) return body.replaceAll('"', '');
  throw Exception('Empty STT token response');
}
