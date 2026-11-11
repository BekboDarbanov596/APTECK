import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/assistant.dart';
import 'package:apteka_ryadom/logic/geo.dart';
import 'package:apteka_ryadom/logic/groq_assistant.dart';
import 'package:apteka_ryadom/logic/llm_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final catalog = Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  http.Response ok(String content) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content},
          },
        ],
      }),
    ),
    200,
  );

  Future<AssistantReply> ask(GroqAssistant g, String m) => g.reply(
    message: m,
    catalog: catalog,
    userLat: bishkekCenterLat,
    userLng: bishkekCenterLng,
    now: DateTime(2026, 11, 8, 12),
  );

  test('ключ gsk_ — Groq с Qwen', () {
    expect(llmAssistantForKey('gsk_test'), isA<GroqAssistant>());
    expect(llmAssistantForKey('gsk_test')!.label, 'Qwen');
  });

  test('Groq: Qwen, JSON-режим, <think> вырезается, история', () async {
    final bodies = <Map<String, dynamic>>[];
    late http.Request last;
    final g = GroqAssistant(
      apiKey: 'gsk_test',
      client: MockClient((req) async {
        last = req;
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return ok(
          '<think>думаю…</think>{"reply":"Смекта поможет.","language":"ru",'
          '"drug_ids":["smecta-3"]}',
        );
      }),
    );
    final r = await ask(g, 'съел самсу');
    expect(last.headers['authorization'], 'Bearer gsk_test');
    expect(bodies.first['model'], 'qwen/qwen3.8-27b');
    expect((bodies.first['response_format'] as Map)['type'], 'json_object');
    expect(jsonEncode(bodies.first['messages']), contains('smecta-3'));
    expect(r.text, 'Смекта поможет.');
    expect(r.suggestions.map((d) => d.id), ['smecta-3']);

    await ask(g, 'а дешевле?');
    final roles = (bodies[1]['messages'] as List)
        .map((m) => m['role'])
        .toList();
    expect(roles, ['system', 'user', 'assistant', 'user']);
  });

  test(
    'Groq: Qwen недоступна — запасная модель; неверный ключ — ошибка',
    () async {
      final models = <String>[];
      var auth = false;
      final g = GroqAssistant(
        apiKey: 'k',
        client: MockClient((req) async {
          if (auth) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'Invalid API Key'},
              }),
              401,
            );
          }
          final m = (jsonDecode(req.body) as Map)['model'] as String;
          models.add(m);
          if (m.startsWith('qwen')) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'over capacity'},
              }),
              503,
            );
          }
          return ok('{"reply":"Hello!","language":"en","drug_ids":[]}');
        }),
      );
      expect((await ask(g, 'hi')).text, 'Hello!');
      expect(models, ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b']);

      auth = true;
      await expectLater(
        ask(g, 'hi'),
        throwsA(
          isA<LlmAssistantException>().having(
            (e) => e.isAuthError,
            'auth',
            isTrue,
          ),
        ),
      );
    },
  );
}
