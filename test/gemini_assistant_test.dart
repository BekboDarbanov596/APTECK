import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/assistant.dart';
import 'package:apteka_ryadom/logic/claude_assistant.dart';
import 'package:apteka_ryadom/logic/gemini_assistant.dart';
import 'package:apteka_ryadom/logic/geo.dart';
import 'package:apteka_ryadom/logic/llm_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final catalog = Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final noon = DateTime(2026, 11, 8, 12);

  http.Response ok(Map<String, dynamic> reply) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'размышления', 'thought': true},
                  {'text': jsonEncode(reply), 'thoughtSignature': 'sig'},
                ],
              },
            },
          ],
        })),
        200,
        headers: {'content-type': 'application/json'},
      );

  Future<AssistantReply> ask(LlmAssistant a, String m) => a.reply(
        message: m,
        catalog: catalog,
        userLat: bishkekCenterLat,
        userLng: bishkekCenterLng,
        now: noon,
      );

  test('провайдер выбирается по ключу', () {
    expect(llmAssistantForKey('AIzaSyTest'), isA<GeminiAssistant>());
    expect(llmAssistantForKey('sk-ant-test'), isA<ClaudeAssistant>());
    expect(llmAssistantForKey('  '), isNull);
  });

  test('Gemini: запрос, разбор ответа, размышления не попадают в текст', () async {
    late http.Request sent;
    final g = GeminiAssistant(
      apiKey: 'AIza-test',
      client: MockClient((req) async {
        sent = req;
        return ok({
          'reply': 'If you ate street food and feel sick, Smecta can help.',
          'language': 'en',
          'drug_ids': ['smecta-3', 'amoxicillin-500', 'nope'],
        });
      }),
    );
    final r = await ask(g, 'I ate samsa');
    expect(sent.url.toString(), contains('gemini-3.8-flash:generateContent'));
    expect(sent.headers['x-goog-api-key'], 'AIza-test');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(jsonEncode(body['systemInstruction']), contains('smecta-3'));
    expect(jsonEncode(body['systemInstruction']), contains('The user wrote in English'));
    expect((body['generationConfig'] as Map)['responseMimeType'], 'application/json');

    expect(r.lang, AssistantLang.en);
    expect(r.text, isNot(contains('размышления')));
    expect(r.suggestions.map((d) => d.id), ['smecta-3', 'amoxicillin-500']);
  });

  test('Gemini: история с ролью model и исходными parts', () async {
    final bodies = <Map<String, dynamic>>[];
    final g = GeminiAssistant(
      apiKey: 'k',
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return ok({'reply': 'ok', 'language': 'ru', 'drug_ids': <String>[]});
      }),
    );
    await ask(g, 'первый');
    await ask(g, 'второй');
    final contents = bodies[1]['contents'] as List;
    expect(contents.map((c) => c['role']), ['user', 'model', 'user']);
    expect(jsonEncode(contents[1]), contains('thoughtSignature'));
  });

  test('Gemini: неверный ключ, лимит, блокировка, JSON в ```', () async {
    var mode = 'auth';
    final g = GeminiAssistant(
      apiKey: 'k',
      client: MockClient((req) async {
        switch (mode) {
          case 'auth':
            return http.Response(
                jsonEncode({
                  'error': {
                    'code': 400,
                    'message': 'API key not valid.',
                    'details': [
                      {'reason': 'API_KEY_INVALID'},
                    ],
                  },
                }),
                400);
          case 'limit':
            return http.Response(jsonEncode({'error': {'code': 429, 'message': 'quota'}}), 429);
          case 'blocked':
            return http.Response(jsonEncode({'promptFeedback': {'blockReason': 'SAFETY'}}), 200);
          default:
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'candidates': [
                  {
                    'finishReason': 'STOP',
                    'content': {
                      'parts': [
                        {'text': '```json\n{"reply":"Салам!","language":"ky","drug_ids":[]}\n```'},
                      ],
                    },
                  },
                ],
              })),
              200,
            );
        }
      }),
    );

    await expectLater(ask(g, 'x'),
        throwsA(isA<LlmAssistantException>().having((e) => e.isAuthError, 'auth', isTrue)));
    mode = 'limit';
    await expectLater(ask(g, 'x'),
        throwsA(isA<LlmAssistantException>().having((e) => e.isRateLimited, 'limit', isTrue)));
    mode = 'blocked';
    await expectLater(ask(g, 'x'), throwsA(isA<LlmAssistantException>()));
    mode = 'fenced';
    final r = await ask(g, 'салам');
    expect(r.text, 'Салам!');
    expect(r.lang, AssistantLang.ky);
  });

  test('Gemini: перегрузка (503) — переходим на следующую бесплатную модель', () async {
    final urls = <String>[];
    final g = GeminiAssistant(
      apiKey: 'k',
      client: MockClient((req) async {
        urls.add(req.url.path);
        if (req.url.path.contains('gemini-3.8-flash')) {
          return http.Response(
              jsonEncode({'error': {'code': 503, 'message': 'high demand'}}), 503);
        }
        return ok({'reply': 'Салам!', 'language': 'ky', 'drug_ids': <String>[]});
      }),
    );
    final r = await ask(g, 'салам');
    expect(r.text, 'Салам!');
    expect(urls.first, contains('gemini-3.8-flash'));
    expect(urls.last, contains('gemini-3.5-flash-lite'));
  });
}
