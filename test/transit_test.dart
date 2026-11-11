import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/routing.dart';
import 'package:apteka_ryadom/logic/transit.dart';
import 'package:apteka_ryadom/state/route_state.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/route_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Ответ в форме из документации 2ГИС (/public_transport/2.0): массив вариантов.
String twoGisBody() => jsonEncode([
  {
    'id': '1',
    'pedestrian': false,
    'total_distance': 3200,
    'total_duration': 1260,
    'total_walkway_distance': 'пешком 6 мин',
    'transfer_count': 0,
    'crossing_count': 0,
    'schedules': [
      {'precise_time': '15:42', 'start_time': 56520},
    ],
    'movements': [
      {
        'type': 'walkway',
        'distance': 300,
        'moving_duration': 240,
        'waiting_duration': 0,
        'waypoint': {'subtype': 'start', 'comment': '300 м пешком'},
        'routes': null,
        'platforms': null,
        'alternatives': [
          {
            'geometry': [
              {'selection': 'LINESTRING(74.6036 42.8766, 74.6050 42.8770)'},
            ],
          },
        ],
      },
      {
        'type': 'passage',
        'distance': 2700,
        'moving_duration': 780,
        'waiting_duration': 120,
        'waypoint': {'name': 'Филармония', 'subtype': 'bus', 'combined': false},
        'routes': [
          {
            'names': ['10', '42'],
            'subtype': 'bus',
            'subtype_name': 'автобус',
            'color': '#e0821e',
          },
        ],
        'platforms': {
          'names': ['ЦУМ', 'Ала-Тоо', 'Дом правительства', 'Чуй — Советская'],
        },
        'alternatives': [
          {
            'geometry': [
              {
                'selection':
                    'LINESTRING(74.6050 42.8770, 74.6150 42.8765, 74.6230 42.8757)',
              },
            ],
          },
        ],
      },
      {
        'type': 'walkway',
        'distance': 200,
        'moving_duration': 120,
        'waiting_duration': 0,
        'waypoint': {'subtype': 'finish', 'comment': 'Вы на месте в 16:03.'},
        'routes': null,
        'platforms': null,
        'alternatives': [
          {
            'geometry': [
              {'selection': 'LINESTRING(74.6230 42.8757, 74.6242 42.8755)'},
            ],
          },
        ],
      },
    ],
  },
  {
    // Целиком пешком — для автобуса не показываем.
    'id': '2',
    'pedestrian': true,
    'total_distance': 1900,
    'total_duration': 1500,
    'movements': [],
  },
]);

http.Response ok(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const pharmacy = Pharmacy(
  id: 'neman-chuy-125',
  chain: 'Неман Фарм',
  address: 'просп. Чуй, 125',
  lat: 42.8754516,
  lng: 74.6242515,
);

void main() {
  group('Разбор ответа 2ГИС', () {
    test('номера, остановки, время, геометрия (долгота перед широтой)', () {
      final options = parseTwoGisTransit(twoGisBody());
      expect(options, hasLength(1)); // пеший вариант отброшен
      final o = options.first;
      expect(o.totalSeconds, 1260);
      expect(o.departure, '15:42');
      expect(o.transfers, 0);
      final ride = o.rides.single;
      expect(ride.lines, ['10', '42']);
      expect(ride.kindLabel, 'Автобус');
      expect(ride.fromStop, 'Филармония');
      expect(ride.stopCount, 5); // 4 промежуточные + выход
      expect(o.points.first.latitude, closeTo(42.8766, 1e-9));
      expect(o.points.first.longitude, closeTo(74.6036, 1e-9));
    });

    test('шаги маршрута для панели', () {
      final r = transitToRoute(parseTwoGisTransit(twoGisBody()).first);
      expect(r.mode, TravelMode.bus);
      expect(r.steps.map((s) => s.instruction), [
        'Пешком до остановки «Филармония»',
        'Автобус № 10, 42 — от «Филармония», 5 ост.',
        'Пешком до аптеки',
        'Вы на месте',
      ]);
    });

    test('битый ответ и WKT', () {
      expect(
        () => parseTwoGisTransit('<html>'),
        throwsA(isA<TransitException>()),
      );
      expect(parseWktLine('POINT(74.6 42.8)').single.latitude, 42.8);
      expect(parseWktLine('мусор'), isEmpty);
    });
  });

  group('Настоящий ответ 2ГИС (Бишкек, Ала-Тоо → юг)', () {
    final real = File('test/fixtures/twogis_bishkek.json').readAsStringSync();

    test('автобус № 10: посадка, выход, остановки, интервал', () {
      final o = parseTwoGisTransit(real).first;
      final ride = o.rides.single;
      expect(ride.lines, ['10']);
      expect(ride.fromStop, 'Площадь Ала-Тоо');
      expect(ride.toStop, 'Шота Руставели');
      expect(ride.stopCount, 8);
      expect(o.departure, isNull); // precise_time пустой
      expect(o.intervalMinutes, 10);
      expect(o.points.first.latitude, closeTo(42.8766, 1e-6));
    });

    test('шаги без пустого хвостового участка', () {
      final r = transitToRoute(parseTwoGisTransit(real).first);
      expect(r.steps.map((s) => s.instruction), [
        'Пешком до остановки «Площадь Ала-Тоо»',
        'Автобус № 10 — от «Площадь Ала-Тоо» до «Шота Руставели», 8 ост.',
        'Пешком до аптеки',
        'Вы на месте',
      ]);
    });
  });

  group('Запрос и поведение', () {
    test('POST с ключом, точками и видами транспорта', () async {
      http.Request? sent;
      final service = TwoGisTransitService(
        apiKey: 'test-key',
        client: MockClient((req) async {
          sent = req;
          return ok(twoGisBody());
        }),
      );
      await service.plan(
        const LatLng(42.8766, 74.6036),
        const LatLng(42.8755, 74.6243),
      );
      expect(sent!.method, 'POST');
      expect(
        sent!.url.toString(),
        'https://routing.api.2gis.com/public_transport/2.0?key=test-key',
      );
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['source'], {
        'point': {'lat': 42.8766, 'lon': 74.6036},
      });
      expect(
        body['transport'],
        containsAll(['bus', 'trolleybus', 'shuttle_bus']),
      );
      expect(body['locale'], 'ru');
    });

    test('неверный ключ — понятная ошибка', () async {
      final service = TwoGisTransitService(
        apiKey: 'bad',
        client: MockClient((_) async => http.Response('', 403)),
      );
      expect(
        () => service.plan(const LatLng(0, 0), const LatLng(1, 1)),
        throwsA(
          isA<TransitException>().having(
            (e) => e.message,
            'm',
            contains('Ключ 2ГИС'),
          ),
        ),
      );
    });

    test(
      'без ключа автобус не строится у нас (панель предложит 2ГИС)',
      () async {
        final route = RouteState(
          RouteService(client: MockClient((_) async => ok('{}'))),
        );
        await route.setMode(TravelMode.bus);
        await route.buildTo(
          pharmacy,
          from: const LatLng(42.8766, 74.6036),
          fromDevice: false,
        );
        expect(route.inApp, isFalse);
        expect(route.result, isNull);
        expect(route.error, isNull);
      },
    );

    test('с ключом автобус строится в приложении', () async {
      final route = RouteState(
        RouteService(
          transit: TwoGisTransitService(
            apiKey: 'k',
            client: MockClient((_) async => ok(twoGisBody())),
          ),
        ),
      );
      await route.setMode(TravelMode.bus);
      await route.buildTo(
        pharmacy,
        from: const LatLng(42.8766, 74.6036),
        fromDevice: true,
      );
      expect(route.inApp, isTrue);
      expect(route.result?.transit?.rides.single.lines, ['10', '42']);
      expect(route.result?.points, isNotEmpty);
    });
  });

  testWidgets('Панель автобуса как в 2ГИС: варианты, О маршруте, способы', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final real = File('test/fixtures/twogis_bishkek.json').readAsStringSync();
    final route = RouteState(
      RouteService(
        transit: TwoGisTransitService(
          apiKey: 'k',
          client: MockClient((_) async => ok(real)),
        ),
      ),
    );
    await route.setMode(TravelMode.bus);
    await route.buildTo(
      pharmacy,
      from: const LatLng(42.8766, 74.6036),
      fromDevice: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: route,
            builder: (context, _) => SingleChildScrollView(
              child: RoutePanel(route: route, onClose: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Моё местоположение'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget); // прибытие из ответа 2ГИС
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Каждые 10 мин'), findsOneWidget);
    expect(find.textContaining('Вариант 1 из 2'), findsOneWidget);

    // Листаем на второй вариант — выбран автобус 216.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(route.result!.transit!.rides.single.lines, ['216']);
    expect(find.textContaining('Вариант 2 из 2'), findsOneWidget);

    await tester.tap(find.text('О маршруте'));
    await tester.pump();
    expect(find.text('Посадка: «Площадь Ала-Тоо»'), findsOneWidget);
    expect(find.textContaining('выход: «Айни»'), findsOneWidget);
    expect(find.text('Пешком до аптеки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2ГИС предлагает только пешком — панель зовёт идти пешком', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final route = RouteState(
      RouteService(
        client: MockClient((_) async => ok('{}')),
        transit: TwoGisTransitService(
          apiKey: 'k',
          client: MockClient(
            (_) async => ok(
              jsonEncode([
                {'id': '1', 'pedestrian': true, 'movements': []},
              ]),
            ),
          ),
        ),
      ),
    );
    await route.setMode(TravelMode.bus);
    await route.buildTo(
      pharmacy,
      from: const LatLng(42.8766, 74.6036),
      fromDevice: true,
    );
    expect(route.walkInstead, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: route,
            builder: (context, _) => SingleChildScrollView(
              child: RoutePanel(route: route, onClose: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Автобус не нужен'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
    expect(find.textContaining('Пешком быстрее'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Пешком'));
    await tester.pump();
    expect(route.mode, TravelMode.walk);
    expect(route.walkInstead, isFalse);
    expect(tester.takeException(), isNull);
  });
}
