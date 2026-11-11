import 'dart:convert';
import 'dart:io';

import 'package:apteka_ryadom/data/catalog_repository.dart';
import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/assistant.dart';
import 'package:apteka_ryadom/logic/drug_search.dart';
import 'package:apteka_ryadom/logic/geo.dart';
import 'package:apteka_ryadom/logic/opening_hours.dart';
import 'package:apteka_ryadom/logic/tips.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/ui/search_screen.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/three/mesh.dart';
import 'package:apteka_ryadom/ui/three/object3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Настоящие демо-данные из assets, без rootBundle.
Catalog loadDemoCatalog() => Catalog.fromJson(
  jsonDecode(File('assets/demo_data.json').readAsStringSync())
      as Map<String, dynamic>,
);

class _FixedRepository implements CatalogRepository {
  _FixedRepository(this.catalog);
  final Catalog catalog;
  @override
  Future<Catalog> load() async => catalog;
}

class _FailingRepository implements CatalogRepository {
  @override
  Future<Catalog> load() async => throw const SocketException('offline');
}

void main() {
  final catalog = loadDemoCatalog();
  final noon = DateTime(2026, 11, 8, 12);

  group('Демо-данные', () {
    test('загружаются и связаны между собой', () {
      expect(catalog.isDemo, isTrue);
      expect(catalog.drugs, isNotEmpty);
      expect(catalog.pharmacies, isNotEmpty);
      for (final o in catalog.offers) {
        expect(catalog.drug(o.drugId), isNotNull, reason: o.drugId);
        expect(catalog.pharmacy(o.pharmacyId), isNotNull, reason: o.pharmacyId);
        expect(o.price, greaterThan(0));
      }
    });

    test('парацетамол — без рецепта, амоксициллин — по рецепту', () {
      expect(catalog.drug('paracetamol-500')!.rx, isFalse);
      expect(catalog.drug('amoxicillin-500')!.rx, isTrue);
    });

    test('у каждого лекарства есть раздел каталога', () {
      expect(catalog.drugs.every((d) => d.category.isNotEmpty), isTrue);
      expect(catalog.categories, contains('Антибиотики'));
      expect(catalog.drugsInCategory('Антибиотики').every((d) => d.rx), isTrue);
      expect(catalog.minPrice('paracetamol-500'), isNotNull);
    });

    test('в демо-данных нет выдуманных телефонов', () {
      expect(catalog.pharmacies.every((p) => p.phone == null), isTrue);
    });
  });

  group('Поиск лекарств', () {
    test('по началу названия', () {
      expect(searchDrugs(catalog.drugs, 'параце').first.id, 'paracetamol-500');
    });

    test('без учёта регистра и по латинице', () {
      expect(searchDrugs(catalog.drugs, 'NUROFEN').first.id, 'nurofen-200');
    });

    test('по действующему веществу находит аналоги', () {
      final ids = searchDrugs(catalog.drugs, 'ибупрофен').map((d) => d.id);
      expect(ids, containsAll(['ibuprofen-200', 'nurofen-200']));
    });

    test('прощает опечатку', () {
      expect(
        searchDrugs(catalog.drugs, 'парацитамол').map((d) => d.id),
        contains('paracetamol-500'),
      );
    });

    test('понимает падежи и дефис', () {
      expect(searchDrugs(catalog.drugs, 'Но-шпы').first.id, 'no-spa-40');
      expect(searchDrugs(catalog.drugs, 'нурофена').first.id, 'nurofen-200');
      expect(searchDrugs(catalog.drugs, 'смекты').first.id, 'smecta-3');
    });

    test('пустой и бессмысленный запрос — пусто', () {
      expect(searchDrugs(catalog.drugs, '   '), isEmpty);
      expect(searchDrugs(catalog.drugs, 'qwzx'), isEmpty);
    });
  });

  group('Часы работы и расстояние', () {
    const day = Pharmacy(
      id: 'a',
      chain: 'A',
      address: '',
      lat: 0,
      lng: 0,
      opensAt: '08:00',
      closesAt: '22:00',
    );
    const night = Pharmacy(
      id: 'b',
      chain: 'B',
      address: '',
      lat: 0,
      lng: 0,
      opensAt: '20:00',
      closesAt: '08:00',
    );
    const allDay = Pharmacy(id: 'c', chain: 'C', address: '', lat: 0, lng: 0);

    test('дневной график', () {
      expect(isOpenAt(day, DateTime(2026, 1, 1, 7, 59)), isFalse);
      expect(isOpenAt(day, DateTime(2026, 1, 1, 8)), isTrue);
      expect(isOpenAt(day, DateTime(2026, 1, 1, 22)), isFalse);
      expect(openingStatus(day, DateTime(2026, 1, 1, 12)), 'Открыто до 22:00');
    });

    test('график через полночь и круглосуточно', () {
      expect(isOpenAt(night, DateTime(2026, 1, 1, 23)), isTrue);
      expect(isOpenAt(night, DateTime(2026, 1, 1, 3)), isTrue);
      expect(isOpenAt(night, DateTime(2026, 1, 1, 12)), isFalse);
      expect(isOpenAt(allDay, DateTime(2026, 1, 1, 3)), isTrue);
    });

    test('расстояние и формат', () {
      // ~1 км по меридиану
      final d = distanceMeters(42.87, 74.6, 42.879, 74.6);
      expect(d, closeTo(1000, 20));
      expect(formatDistance(447), '450 м');
      expect(formatDistance(1234), '1,2 км');
    });
  });

  group('Состояние приложения', () {
    Future<AppState> makeState() async {
      final s = AppState(
        repository: _FixedRepository(catalog),
        clock: () => noon,
        useDeviceServices: false,
      );
      await s.init();
      return s;
    }

    test('без выбранного лекарства — все аптеки, по расстоянию', () async {
      final s = await makeState();
      final r = s.results;
      expect(r.length, catalog.pharmacies.length);
      expect(r.every((x) => x.price == null), isTrue);
      for (var i = 1; i < r.length; i++) {
        expect(r[i].distance, greaterThanOrEqualTo(r[i - 1].distance));
      }
    });

    test(
      'с лекарством — только аптеки, где оно есть; сортировка по цене',
      () async {
        final s = await makeState();
        final drug = catalog.drug('paracetamol-500')!;
        s.selectDrug(drug);
        expect(s.results.length, catalog.offersForDrug(drug.id).length);
        s.setSort(SortMode.cheapest);
        final prices = s.results.map((r) => r.price!).toList();
        expect(prices, [...prices]..sort());
        expect(s.recentDrugIds.first, drug.id);
      },
    );

    test('фильтр по сети', () async {
      final s = await makeState();
      s.setFilters(onlyOpen: false, chains: {'Эл Аман'});
      expect(s.results, isNotEmpty);
      expect(s.results.every((r) => r.pharmacy.chain == 'Эл Аман'), isTrue);
      expect(s.activeFilterCount, 1);
    });

    test('ошибка загрузки и повтор', () async {
      final s = AppState(
        repository: _FailingRepository(),
        useDeviceServices: false,
      );
      await s.init();
      expect(s.loadError, isNotNull);
      expect(s.results, isEmpty);
    });
  });

  group('Ассистент', () {
    AssistantReply ask(String m) => assistantReply(
      message: m,
      catalog: catalog,
      userLat: bishkekCenterLat,
      userLng: bishkekCenterLng,
      now: noon,
    );

    test('находит лекарство и аналоги', () {
      final r = ask('Где есть Нурофен?');
      expect(r.drug?.id, 'nurofen-200');
      expect(r.text, contains('Ближайшая'));
      expect(r.text, contains('Ибупрофен'));
    });

    test('подсказки из чата работают', () {
      expect(ask('Аналоги Но-шпы').drug?.id, 'no-spa-40');
      expect(ask('Аналоги Но-шпы').text, contains('Дротаверин'));
      expect(ask('Смекта дешевле').drug?.id, 'smecta-3');
    });

    test('предупреждает о рецепте', () {
      expect(ask('амоксициллин').text, contains('по рецепту'));
    });

    test('по симптомам советует безрецептурное из каталога', () {
      final r = ask('что выпить, болит голова');
      expect(r.drug, isNull);
      expect(r.suggestions.map((d) => d.id), contains('paracetamol-500'));
      expect(r.suggestions.any((d) => d.rx), isFalse);
    });
  });

  group('Карточки-советы', () {
    List<Tip> tipsAt(DateTime now) => buildTips(
      catalog: catalog,
      userLat: bishkekCenterLat,
      userLng: bishkekCenterLng,
      now: now,
    );

    test('экономия считается по аналогам с тем же веществом', () {
      final saving = tipsAt(noon).firstWhere((t) => t.kind == TipKind.savings);
      final drug = (saving.action! as SelectDrugAction).drug;
      final analogs = catalog.analogs(drug);
      expect(analogs, isNotEmpty);
      int minPrice(String id) => catalog
          .offersForDrug(id)
          .map((o) => o.price)
          .reduce((a, b) => a < b ? a : b);
      expect(analogs.any((a) => minPrice(a.id) > minPrice(drug.id)), isTrue);
    });

    test('круглосуточная аптека — действительно круглосуточная', () {
      final night = tipsAt(
        noon,
      ).firstWhere((t) => t.kind == TipKind.nightPharmacy);
      final id = (night.action! as OpenPharmacyAction).pharmacyId;
      expect(catalog.pharmacy(id)!.isAroundTheClock, isTrue);
    });

    test('советы переводятся на кыргызский и английский', () {
      List<Tip> tipsIn(String lang) => buildTips(
        catalog: catalog,
        userLat: bishkekCenterLat,
        userLng: bishkekCenterLng,
        now: noon,
        lang: lang,
      );
      final en = tipsIn('en');
      final ky = tipsIn('ky');
      expect(
        en.firstWhere((t) => t.kind == TipKind.homeKit).title,
        'Home first-aid kit',
      );
      expect(
        ky.firstWhere((t) => t.kind == TipKind.homeKit).title,
        'Үй дарылыгы',
      );
      expect(
        en.firstWhere((t) => t.kind == TipKind.nightPharmacy).text,
        contains(' from you'),
      );
      expect(en.map((t) => t.kind), tipsIn('ru').map((t) => t.kind));
    });

    test('совет про льготные рецепты исчезает в 2027 году', () {
      expect(tipsAt(noon).any((t) => t.kind == TipKind.benefit), isTrue);
      expect(
        tipsAt(DateTime(2027, 1, 2, 12)).any((t) => t.kind == TipKind.benefit),
        isFalse,
      );
    });

    test('ночью открыто меньше аптек, чем днём', () {
      int openCount(DateTime t) =>
          catalog.pharmacies.where((p) => isOpenAt(p, t)).length;
      expect(openCount(DateTime(2026, 11, 8, 3)), lessThan(openCount(noon)));
      final tip = tipsAt(
        DateTime(2026, 11, 8, 3),
      ).firstWhere((t) => t.kind == TipKind.openNow);
      expect(tip.action, isA<FilterAction>());
    });
  });

  group('3D-объекты', () {
    test('все сетки корректны: индексы в пределах, нормали единичные', () {
      for (final shape in Shape3D.values) {
        final m = meshFor(shape);
        expect(m.triangleCount, greaterThan(100), reason: '$shape');
        expect(
          m.indices.every((i) => i < m.vertexCount),
          isTrue,
          reason: '$shape',
        );
        for (var v = 0; v < m.vertexCount; v++) {
          final x = m.normals[v * 3],
              y = m.normals[v * 3 + 1],
              z = m.normals[v * 3 + 2];
          final len = x * x + y * y + z * z;
          // У вершин-«полюсов» нормаль может быть нулевой — остальные единичные.
          expect(
            len == 0 || (len - 1).abs() < 1e-3,
            isTrue,
            reason: '$shape #$v',
          );
          expect(
            m.positions[v * 3].isFinite && m.positions[v * 3 + 1].isFinite,
            isTrue,
          );
        }
      }
    });

    test('у каждого раздела каталога свой объект', () {
      final shapes = catalog.categories.map(shapeForCategory).toSet();
      expect(shapes.length, catalog.categories.length);
    });

    testWidgets('объект рисуется без ошибок', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: Object3D(shape: Shape3D.heart)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Экран поиска: ввод → подсказка → выбор', (tester) async {
    final state = AppState(
      repository: _FixedRepository(catalog),
      clock: () => noon,
      useDeviceServices: false,
    );
    await state.init();
    Drug? picked;

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(),
          home: SearchScreen(embedded: true, onPicked: (d) => picked = d),
        ),
      ),
    );

    expect(find.text('Часто ищут'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'смек');
    await tester.pump();
    expect(find.text('Смекта 3 г'), findsOneWidget);

    await tester.tap(find.text('Смекта 3 г'));
    expect(picked?.id, 'smecta-3');

    await tester.enterText(find.byType(TextField), 'qwzx');
    await tester.pump();
    expect(find.text('Ничего не нашли'), findsOneWidget);
  });
}
