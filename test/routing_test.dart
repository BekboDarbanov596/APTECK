import 'dart:convert';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/routing.dart';
import 'package:apteka_ryadom/state/route_state.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/route_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Ответ OSRM в том виде, как его отдаёт routing.openstreetmap.de (сокращён).
String osrmBody({double distance = 542.2, double duration = 433.7}) =>
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'distance': distance,
          'duration': duration,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [74.6036, 42.8766],
              [74.6050, 42.8770],
              [74.6097, 42.8762],
            ],
          },
          'legs': [
            {
              'steps': [
                {
                  'name': 'проспект Чуй',
                  'distance': 100.0,
                  'maneuver': {'type': 'depart', 'modifier': 'left'},
                },
                {
                  'name': 'улица Киевская',
                  'distance': 189.0,
                  'maneuver': {'type': 'turn', 'modifier': 'right'},
                },
                {
                  'name': '',
                  'distance': 0.0,
                  'maneuver': {'type': 'arrive', 'modifier': 'left'},
                },
              ],
            },
          ],
        },
      ],
    });

/// Ответ в UTF-8, как у настоящего сервера (в теле — русские названия улиц).
http.Response ok(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const pharmacy = Pharmacy(
  id: 'neman-chuy-125',
  chain: 'Неман Фарм',
  address: 'просп. Чуй, 125',
  lat: 42.8762,
  lng: 74.6097,
);

void main() {
  group('Разбор ответа OSRM', () {
    test('точки, расстояние, время и шаги', () {
      final r = parseOsrmResponse(osrmBody(), TravelMode.walk);
      expect(r.points, hasLength(3));
      // GeoJSON хранит [долгота, широта] — проверяем, что не перепутали.
      expect(r.points.first.latitude, closeTo(42.8766, 1e-9));
      expect(r.points.first.longitude, closeTo(74.6036, 1e-9));
      expect(r.distance, 542.2);
      expect(r.steps.map((s) => s.instruction), [
        'Начните движение по проспект Чуй',
        'Поверните направо на улица Киевская',
        'Вы на месте — аптека слева',
      ]);
      expect(r.steps.map((s) => s.kind), ['depart', 'right', 'arrive']);
    });

    test('нет маршрута и битый ответ — понятные ошибки', () {
      expect(
        () =>
            parseOsrmResponse('{"code":"NoRoute","routes":[]}', TravelMode.car),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.message,
            'message',
            contains('нет маршрута'),
          ),
        ),
      );
      expect(
        () => parseOsrmResponse('<html>', TravelMode.car),
        throwsA(isA<RoutingException>()),
      );
    });

    test('подсказки на русском', () {
      expect(
        instructionRu(
          type: 'end of road',
          modifier: 'left',
          name: 'ул. Токтогула',
        ),
        'В конце дороги поверните налево на ул. Токтогула',
      );
      expect(
        instructionRu(type: 'roundabout', exit: 2),
        'На круге — 2-й съезд',
      );
      expect(
        instructionRu(type: 'continue', modifier: 'straight', name: 'Чуй'),
        'Продолжайте прямо по Чуй',
      );
      expect(instructionRu(type: 'turn', modifier: 'uturn'), 'Развернитесь');
    });

    test('время в пути', () {
      expect(formatDuration(20), 'меньше минуты');
      expect(formatDuration(434), '7 мин');
      expect(formatDuration(3900), '1 ч 05 мин');
    });
  });

  group('Запрос к серверу', () {
    test('правильный адрес: профиль, долгота перед широтой', () async {
      Uri? asked;
      final service = RouteService(
        client: MockClient((req) async {
          asked = req.url;
          return ok(osrmBody());
        }),
      );
      await service.route(
        const LatLng(42.8766, 74.6036),
        const LatLng(42.8762, 74.6097),
        TravelMode.car,
      );
      expect(
        asked.toString(),
        startsWith(
          'https://routing.openstreetmap.de/routed-car/route/v1/driving/74.6036,42.8766;74.6097,42.8762',
        ),
      );
      expect(asked!.queryParameters['geometries'], 'geojson');
    });

    test('ошибка сервера и нет сети', () async {
      final down = RouteService(
        client: MockClient((_) async => http.Response('', 503)),
      );
      expect(
        () =>
            down.route(const LatLng(0, 0), const LatLng(1, 1), TravelMode.walk),
        throwsA(isA<RoutingException>()),
      );
      final offline = RouteService(
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(
        () => offline.route(
          const LatLng(0, 0),
          const LatLng(1, 1),
          TravelMode.walk,
        ),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.message,
            'message',
            contains('интернета'),
          ),
        ),
      );
    });
  });

  group('Состояние маршрута', () {
    test(
      'строит, меняет режим, закрывается; старые ответы не перетирают новые',
      () async {
        final calls = <String>[];
        final route = RouteState(
          RouteService(
            client: MockClient((req) async {
              calls.add(req.url.pathSegments.first);
              return ok(
                osrmBody(duration: req.url.path.contains('car') ? 120 : 434),
              );
            }),
          ),
        );
        await route.buildTo(
          pharmacy,
          from: const LatLng(42.8766, 74.6036),
          fromDevice: false,
        );
        expect(route.result?.mode, TravelMode.walk);
        expect(route.takeShowMapRequest(), isTrue);
        expect(route.takeShowMapRequest(), isFalse);

        await route.setMode(TravelMode.car);
        expect(calls, ['routed-foot', 'routed-car']);
        expect(route.result?.duration, 120);

        route.clear();
        expect(route.active, isFalse);
        expect(route.result, isNull);
      },
    );

    test('ошибка показывается и повтор работает', () async {
      var fail = true;
      final route = RouteState(
        RouteService(
          client: MockClient(
            (_) async => fail ? http.Response('', 500) : ok(osrmBody()),
          ),
        ),
      );
      await route.buildTo(
        pharmacy,
        from: const LatLng(42.8766, 74.6036),
        fromDevice: true,
      );
      expect(route.error, isNotNull);
      fail = false;
      await route.retry();
      expect(route.error, isNull);
      expect(route.result, isNotNull);
    });
  });

  testWidgets(
    'Панель маршрута: время, копирование адреса, смена режима и закрытие',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = RouteState(
        RouteService(
          client: MockClient(
            (req) async => ok(
              osrmBody(duration: req.url.path.contains('car') ? 120 : 434),
            ),
          ),
        ),
      );
      await route.buildTo(
        pharmacy,
        from: const LatLng(42.8766, 74.6036),
        fromDevice: false,
      );
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: route,
              builder: (context, _) => SingleChildScrollView(
                child: RoutePanel(route: route, onClose: () => closed = true),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Неман Фарм', findRichText: true),
        findsOneWidget,
      );
      // Время — в карточке и в полоске способов внизу.
      expect(find.text('7 мин'), findsWidgets);
      expect(find.text('Моё местоположение'), findsNothing);
      expect(find.text('Площадь Ала-Тоо'), findsOneWidget);
      final platform = tester.binding.defaultBinaryMessenger;
      String? copied;
      platform.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => platform.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.tap(find.byTooltip('Скопировать адрес'));
      await tester.pump();
      expect(copied, pharmacy.address);
      expect(find.text('Адрес скопирован'), findsOneWidget);
      expect(find.textContaining('от площади Ала-Тоо'), findsOneWidget);
      expect(find.text('В путь'), findsOneWidget);

      await tester.tap(find.byTooltip('На машине'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 мин'), findsWidgets);
      // Пешком уже считали — в полоске осталось точное время.
      expect(find.text('7 мин'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть маршрут'));
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 412.0]) {
    testWidgets('Панель маршрута помещается на экране шириной $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = RouteState(
        RouteService(client: MockClient((_) async => ok(osrmBody()))),
      );
      await route.buildTo(
        pharmacy,
        from: const LatLng(42.8766, 74.6036),
        fromDevice: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RoutePanel(route: route, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
