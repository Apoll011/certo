import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/chat_message.dart';

/// Exception thrown when an OpenAI/DeepSeek API call fails.
class OpenAiException implements Exception {
  OpenAiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() =>
      'OpenAiException: $message (statusCode: $statusCode, body: $responseBody)';
}

/// A lightweight, robust HTTP client for OpenAI-compatible APIs (OpenAI, DeepSeek, Groq, Ollama, etc.).
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-flash',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String model;
  final http.Client _httpClient;

  /// Resolves the full URL for `/chat/completions`.
  Uri get _chatCompletionsUri {
    var base = baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) {
      return Uri.parse('$base/chat/completions');
    }
    // DeepSeek supports https://api.deepseek.com/chat/completions
    // and standard OpenAI is https://api.openai.com/v1/chat/completions
    return Uri.parse('$base/chat/completions');
  }

  /// Sends a chat completion request to the OpenAI-compatible endpoint.
  Future<ChatCompletionResponse> chatCompletion({
    required List<ChatMessage> messages,
    List<Map<String, dynamic>>? tools,
    dynamic toolChoice,
    double? temperature,
    int? maxTokens,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };

    if (tools != null && tools.isNotEmpty) {
      payload['tools'] = tools;
      if (toolChoice != null) {
        payload['tool_choice'] = toolChoice;
      }
    }

    if (temperature != null) payload['temperature'] = temperature;
    if (maxTokens != null) payload['max_tokens'] = maxTokens;

    final uri = _chatCompletionsUri;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };

    debugPrint('OpenAiCompatibleClient: POST $uri (model: $model, tools: ${tools?.length ?? 0})');

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);

      if (response.statusCode != 200) {
        String errMsg = 'API request failed with code ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson.containsKey('error')) {
            final err = errJson['error'];
            if (err is Map && err.containsKey('message')) {
              errMsg = err['message'].toString();
            } else {
              errMsg = err.toString();
            }
          }
        } catch (_) {}

        throw OpenAiException(
          errMsg,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeBody(response));
      if (json is! Map<String, dynamic>) {
        throw OpenAiException(
          'Invalid JSON response format from AI API.',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      return ChatCompletionResponse.fromJson(json);
    } catch (e) {
      if (e is OpenAiException) rethrow;
      throw OpenAiException('Network or client error: $e');
    }
  }

  /// Prefer UTF-8 (what DeepSeek / OpenAI return). Fall back to [Response.body]
  /// for latin1-encoded mock responses used in tests.
  static String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  void close() {
    _httpClient.close();
  }
}
