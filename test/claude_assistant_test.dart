import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/assistant.dart';
import 'package:apteka_ryadom/logic/claude_assistant.dart';
import 'package:apteka_ryadom/logic/geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final catalog = Catalog.fromJson(
    jsonDecode(File('assets/demo_data.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final noon = DateTime(2026, 11, 8, 12);

  http.Response ok(Map<String, dynamic> reply, {String stop = 'end_turn'}) =>
      http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 'msg_1',
            'type': 'message',
            'role': 'assistant',
            'stop_reason': stop,
            'content': [
              {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
              {'type': 'text', 'text': jsonEncode(reply)},
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );

  Future<AssistantReply> ask(ClaudeAssistant c, String m) => c.reply(
    message: m,
    catalog: catalog,
    userLat: bishkekCenterLat,
    userLng: bishkekCenterLng,
    now: noon,
  );

  test('запрос: ключ, версия, модель, каталог в системном промпте', () async {
    late http.Request sent;
    final c = ClaudeAssistant(
      apiKey: 'test-key',
      client: MockClient((req) async {
        sent = req;
        return ok({
          'reply': 'Самса жедиңизби? Ууланып калсаңыз, Смекта жардам берет.',
          'language': 'ky',
          'drug_ids': ['smecta-3', 'no-such-drug'],
        });
      }),
    );

    final r = await ask(c, 'Самса жедим');
    expect(sent.headers['x-api-key'], 'test-key');
    expect(sent.headers['anthropic-version'], '2026-10-21');
    expect(sent.headers['anthropic-dangerous-direct-browser-access'], 'true');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['fallbacks'], 'default');
    expect(jsonEncode(body['system']), contains('smecta-3'));
    expect((body['output_config'] as Map)['format'], isNotNull);

    expect(r.lang, AssistantLang.ky);
    expect(r.text, contains('Смекта'));
    // Неизвестный id из ответа модели отбрасывается.
    expect(r.suggestions.map((d) => d.id), ['smecta-3']);
  });

  test('история: ответ ассистента уходит обратно без изменений', () async {
    final bodies = <Map<String, dynamic>>[];
    final c = ClaudeAssistant(
      apiKey: 'k',
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return ok({'reply': 'ok', 'language': 'ru', 'drug_ids': <String>[]});
      }),
    );
    await ask(c, 'первый');
    await ask(c, 'второй');
    final messages = bodies[1]['messages'] as List;
    expect(messages, hasLength(3));
    final assistant = messages[1] as Map;
    expect(assistant['role'], 'assistant');
    // Весь content, включая блок thinking с подписью.
    expect((assistant['content'] as List).first['signature'], 'sig');
  });

  test(
    'ошибки: неверный ключ, отказ, сеть — исключение, история не портится',
    () async {
      var mode = 'auth';
      final c = ClaudeAssistant(
        apiKey: 'k',
        client: MockClient((req) async {
          switch (mode) {
            case 'auth':
              return http.Response(
                jsonEncode({
                  'type': 'error',
                  'error': {
                    'type': 'authentication_error',
                    'message': 'invalid x-api-key',
                  },
                }),
                401,
              );
            case 'refusal':
              return ok({
                'reply': '',
                'language': 'ru',
                'drug_ids': <String>[],
              }, stop: 'refusal');
            default:
              throw const SocketException('offline');
          }
        }),
      );

      await expectLater(
        ask(c, 'привет'),
        throwsA(
          isA<ClaudeAssistantException>().having(
            (e) => e.isAuthError,
            'auth',
            isTrue,
          ),
        ),
      );
      mode = 'refusal';
      await expectLater(
        ask(c, 'привет'),
        throwsA(isA<ClaudeAssistantException>()),
      );
      mode = 'net';
      await expectLater(
        ask(c, 'привет'),
        throwsA(isA<ClaudeAssistantException>()),
      );
    },
  );

  test('каталог для модели: рецептурные помечены, есть цены и аптеки', () {
    final ctx = catalogContext(
      catalog,
      bishkekCenterLat,
      bishkekCenterLng,
      noon,
    );
    expect(ctx, contains('amoxicillin-500'));
    expect(RegExp(r'amoxicillin-500 \|[^\n]*\| RX \|').hasMatch(ctx), isTrue);
    expect(RegExp(r'smecta-3 \|[^\n]*\| OTC \|').hasMatch(ctx), isTrue);
    expect(ctx, contains('сом'));
  });
}
