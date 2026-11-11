import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'assistant.dart';
import 'llm_assistant.dart';

export 'llm_assistant.dart';

/// Ассистент на Google Gemini. У Gemini API есть бесплатный тариф
/// (ключ — aistudio.google.com), с небольшим лимитом запросов в минуту и в день.
///
/// Запросы идут из браузера напрямую с ключом пользователя.
/// Для публичного запуска ключ нужно перенести на свой сервер.
class GeminiAssistant implements LlmAssistant {
  GeminiAssistant({
    required this.apiKey,
    http.Client? client,
    this.models = const [
      'gemini-3.8-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.1-flash-lite',
    ],
    this.timeout = const Duration(seconds: 30),
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _client = client ?? http.Client();

  final String apiKey;

  /// Бесплатные модели по порядку: если первая перегружена (503) или молчит,
  /// пробуем следующую.
  final List<String> models;
  final Duration timeout;
  final String baseUrl;
  final http.Client _client;

  @override
  String get label => 'Gemini';

  /// История в формате generateContent. Ответы модели хранятся как пришли
  /// (все `parts`, включая служебные подписи), чтобы отправлять их обратно.
  final List<Map<String, dynamic>> _history = [];

  static const _maxHistoryMessages = 20;

  @override
  Future<AssistantReply> reply({
    required String message,
    required Catalog catalog,
    required double userLat,
    required double userLng,
    required DateTime now,
  }) async {
    final userTurn = <String, dynamic>{
      'role': 'user',
      'parts': [
        {'text': message},
      ],
    };

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': llmInstructions},
          {'text': catalogContext(catalog, userLat, userLng, now)},
          {'text': llmLanguageHint(message)},
        ],
      },
      'contents': [..._history, userTurn],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': _geminiSchema,
        'maxOutputTokens': 8000,
      },
    };

    LlmAssistantException? lastError;
    for (final model in models) {
      try {
        return await _call(model, body, userTurn, catalog);
      } on LlmAssistantException catch (e) {
        // Ключ неверный или лимит исчерпан — другие модели не помогут.
        if (e.isAuthError || e.isRateLimited) rethrow;
        lastError = e;
      }
    }
    throw lastError ?? LlmAssistantException('Модель не ответила');
  }

  Future<AssistantReply> _call(
    String model,
    Map<String, dynamic> body,
    Map<String, dynamic> userTurn,
    Catalog catalog,
  ) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/models/$model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      throw LlmAssistantException('Сеть недоступна или $model не ответила: $e');
    }

    final decoded = _decode(res);
    if (res.statusCode != 200) {
      final err = decoded?['error'] as Map<String, dynamic>?;
      final details = jsonEncode(err?['details'] ?? const []);
      throw LlmAssistantException(
        (err?['message'] as String?) ?? res.body,
        statusCode: res.statusCode,
        isAuthError:
            res.statusCode == 401 ||
            res.statusCode == 403 ||
            details.contains('API_KEY_INVALID'),
        isRateLimited: res.statusCode == 429,
      );
    }
    if (decoded == null) throw LlmAssistantException('Ответ не в формате JSON');

    final blocked = (decoded['promptFeedback'] as Map?)?['blockReason'];
    if (blocked != null) {
      throw LlmAssistantException('Запрос заблокирован фильтрами: $blocked');
    }
    final candidates = (decoded['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) throw LlmAssistantException('Модель не ответила');
    final candidate = candidates.first as Map<String, dynamic>;
    final finish = candidate['finishReason'] as String?;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = ((content?['parts'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // Части с thought: true — размышления модели, в ответ не идут.
    final text = parts
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    if (finish != null && finish != 'STOP' || text.isEmpty) {
      throw LlmAssistantException('Ответ не получен (finishReason: $finish)');
    }

    final result = parseLlmReply(text, catalog);

    _history
      ..add(userTurn)
      ..add({'role': 'model', 'parts': parts});
    while (_history.length > _maxHistoryMessages) {
      _history.removeRange(0, 2);
    }
    return result;
  }

  static Map<String, dynamic>? _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  void close() => _client.close();
}

/// Та же схема ответа, но без additionalProperties — не все версии
/// Gemini его принимают.
final _geminiSchema = {
  for (final e in llmReplySchema.entries)
    if (e.key != 'additionalProperties') e.key: e.value,
};
