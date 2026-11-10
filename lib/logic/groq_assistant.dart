import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'assistant.dart';
import 'llm_assistant.dart';

export 'llm_assistant.dart';

/// Ассистент через Groq (бесплатный тариф, ключ — console.groq.com, «gsk_…»).
/// Основная модель — Qwen, запасная — Llama, если Qwen перегружена или недоступна.
///
/// Запросы идут из браузера напрямую с ключом пользователя.
/// Для публичного запуска ключ нужно перенести на свой сервер.
class GroqAssistant implements LlmAssistant {
  GroqAssistant({
    required this.apiKey,
    http.Client? client,
    this.models = const ['qwen/qwen3.8-27b', 'llama-3.3-70b-versatile'],
    this.timeout = const Duration(seconds: 30),
    this.endpoint = 'https://api.groq.com/openai/v1/chat/completions',
  }) : _client = client ?? http.Client();

  final String apiKey;
  final List<String> models;
  final Duration timeout;
  final String endpoint;
  final http.Client _client;

  @override
  String get label => 'Qwen';

  /// История в формате chat completions (только текст реплик).
  final List<Map<String, String>> _history = [];
  static const _maxHistoryMessages = 20;

  @override
  Future<AssistantReply> reply({
    required String message,
    required Catalog catalog,
    required double userLat,
    required double userLng,
    required DateTime now,
  }) async {
    final system = [
      llmInstructions,
      catalogContext(catalog, userLat, userLng, now),
      llmLanguageHint(message),
      'Answer with a single JSON object and nothing else: '
          '{"reply": string, "language": "ru"|"ky"|"en", "drug_ids": [string]}.',
    ].join('\n\n');

    final messages = [
      {'role': 'system', 'content': system},
      ..._history,
      {'role': 'user', 'content': message},
    ];

    LlmAssistantException? lastError;
    for (final model in models) {
      try {
        final (result, raw) = await _call(model, messages, catalog);
        _history
          ..add({'role': 'user', 'content': message})
          ..add({'role': 'assistant', 'content': raw});
        while (_history.length > _maxHistoryMessages) {
          _history.removeRange(0, 2);
        }
        return result;
      } on LlmAssistantException catch (e) {
        if (e.isAuthError) rethrow;
        lastError = e;
      }
    }
    throw lastError ?? LlmAssistantException('Модель не ответила');
  }

  Future<(AssistantReply, String)> _call(
    String model,
    List<Map<String, String>> messages,
    Catalog catalog,
  ) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'response_format': {'type': 'json_object'},
              'max_completion_tokens': 4000,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw LlmAssistantException('Сеть недоступна или $model не ответила: $e');
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode != 200) {
      final err = decoded?['error'] as Map<String, dynamic>?;
      throw LlmAssistantException(
        (err?['message'] as String?) ?? res.body,
        statusCode: res.statusCode,
        isAuthError: res.statusCode == 401 || res.statusCode == 403,
        isRateLimited: res.statusCode == 429,
      );
    }

    final choices = (decoded?['choices'] as List?) ?? const [];
    if (choices.isEmpty) throw LlmAssistantException('Модель не ответила');
    final msg = (choices.first as Map)['message'] as Map?;
    var text = (msg?['content'] as String?) ?? '';
    // Qwen может вставить размышления в <think>…</think> — убираем.
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    if (text.isEmpty) throw LlmAssistantException('Пустой ответ');
    return (parseLlmReply(text, catalog), text);
  }

  @override
  void close() => _client.close();
}
