import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'assistant.dart';
import 'llm_assistant.dart';

export 'llm_assistant.dart';

/// Старое имя ошибки — оставлено для совместимости.
typedef ClaudeAssistantException = LlmAssistantException;

/// Ассистент на Claude: понимает свободные фразы на русском, кыргызском и
/// английском, отвечает только на аптечные темы и опирается на каталог.
///
/// Запросы идут из браузера напрямую в Claude API с ключом пользователя.
/// Для публичного запуска ключ нужно перенести на свой сервер.
class ClaudeAssistant implements LlmAssistant {
  ClaudeAssistant({
    required this.apiKey,
    http.Client? client,
    this.model = 'claude-opus-5-5',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String endpoint;
  final http.Client _client;

  @override
  String get label => 'Claude';

  /// История в формате Messages API. Ответы ассистента хранятся как пришли
  /// (весь `content`), чтобы отправлять их обратно без изменений.
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
    final userTurn = <String, dynamic>{'role': 'user', 'content': message};
    final messages = [..._history, userTurn];

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 8000,
      'system': [
        {'type': 'text', 'text': llmInstructions},
        {'type': 'text', 'text': catalogContext(catalog, userLat, userLng, now)},
        {'type': 'text', 'text': llmLanguageHint(message)},
      ],
      'messages': messages,
      'output_config': {
        // Короткий чат: низкое усилие — быстрее и дешевле.
        'effort': 'low',
        'format': {'type': 'json_schema', 'schema': llmReplySchema},
      },
      // Если фильтры безопасности отклонят запрос, сервер сам повторит его
      // на рекомендованной модели.
      'fallbacks': 'default',
    };

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2026-10-21',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw LlmAssistantException('Сеть недоступна: $e');
    }

    if (res.statusCode != 200) {
      String detail = res.body;
      try {
        final err = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = ((err['error'] as Map?)?['message'] as String?) ?? detail;
      } catch (_) {}
      throw LlmAssistantException(
        detail,
        statusCode: res.statusCode,
        isAuthError: res.statusCode == 401 || res.statusCode == 403,
        isRateLimited: res.statusCode == 429,
      );
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final stop = data['stop_reason'] as String?;
    if (stop == 'refusal') {
      throw LlmAssistantException('Запрос отклонён фильтрами безопасности');
    }
    final content = (data['content'] as List?) ?? const [];
    final text = content
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    if (stop == 'max_tokens' || text.isEmpty) {
      throw LlmAssistantException('Ответ оборвался (stop_reason: $stop)');
    }

    final result = parseLlmReply(text, catalog);

    // Только теперь записываем ход в историю — неудачные запросы не сохраняем.
    _history
      ..add(userTurn)
      ..add({'role': 'assistant', 'content': content});
    while (_history.length > _maxHistoryMessages) {
      _history.removeRange(0, 2);
    }

    return result;
  }

  @override
  void close() => _client.close();
}

