import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/routing.dart';
import 'package:apteka_ryadom/logic/tips.dart';
import 'package:apteka_ryadom/state/route_state.dart';
import 'package:apteka_ryadom/ui/actions.dart' show twoGisTransitUri;
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/popular_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' show LatLng;

const pharmacy = Pharmacy(
  id: 'p1',
  chain: 'Неман Фарм',
  address: 'просп. Чуй, 125',
  lat: 42.8762,
  lng: 74.6097,
);

void main() {
  group('Способы передвижения', () {
    test('порядок и названия', () {
      expect(TravelMode.values.map((m) => m.label), [
        'Пешком',
        'Автобус',
        'Велосипед',
        'Самокат',
        'На машине',
      ]);
    });

    test('примерное время: пешком дольше велосипеда, для автобуса нет', () {
      final walk = TravelMode.walk.estimateSeconds(1000)!;
      final bike = TravelMode.bike.estimateSeconds(1000)!;
      expect(walk, greaterThan(bike));
      // 1 км по прямой ≈ 1,3 км по улицам ≈ 16 минут пешком.
      expect(walk / 60, closeTo(16.25, 0.1));
      expect(TravelMode.bus.estimateSeconds(1000), isNull);
    });

    test('автобус в 2ГИС: общественный транспорт, сначала долгота', () {
      expect(
        twoGisTransitUri(42.8754516, 74.6242515).toString(),
        'dgis://2gis.ru/routeSearch/rsType/ctx/to/74.6242515,42.8754516',
      );
    });

    test('режимы Google Карт', () {
      expect(TravelMode.bus.googleMode, 'transit');
      expect(TravelMode.scooter.googleMode, 'bicycling');
      expect(TravelMode.car.googleMode, 'driving');
    });

    test(
      'автобус не ходит на сервер маршрутов, остальные — с нужным профилем',
      () async {
        final asked = <String>[];
        final route = RouteState(
          RouteService(
            client: MockClient((req) async {
              asked.add(req.url.pathSegments.first);
              return http.Response('{"code":"NoRoute","routes":[]}', 200);
            }),
          ),
        );
        await route.buildTo(
          pharmacy,
          from: const LatLng(42.8766, 74.6036),
          fromDevice: false,
        );
        await route.setMode(TravelMode.bus);
        expect(route.loading, isFalse);
        expect(route.error, isNull);
        expect(route.result, isNull);
        await route.setMode(TravelMode.scooter);
        expect(asked, ['routed-foot', 'routed-bike']);
      },
    );
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('Плитки «Популярное» помещаются при ширине $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TipAction? tapped;
      var intro = false;
      const tips = [
        Tip(
          kind: TipKind.nightPharmacy,
          title: 'Работает круглосуточно',
          text: '',
          action: OpenPharmacyAction('p1'),
        ),
        Tip(kind: TipKind.savings, title: 'Экономия до 191 сом', text: ''),
        Tip(
          kind: TipKind.openNow,
          title: 'Сейчас открыто 14 из 16',
          text: '',
          action: FilterAction(onlyOpen: true),
        ),
        Tip(kind: TipKind.benefit, title: 'Льготный э-рецепт', text: ''),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: PopularTiles(
                tips: tips,
                onTipAction: (a) => tapped = a,
                introTitle: 'Как это работает',
                onIntro: () => intro = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Как это работает'), findsOneWidget);

      await tester.tap(find.text('Сейчас открыто 14 из 16'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped, isA<FilterAction>());

      await tester.tap(find.text('Как это работает'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(intro, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
