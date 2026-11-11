import 'package:apteka_ryadom/data/models.dart';
import 'package:apteka_ryadom/logic/routing.dart';
import 'package:apteka_ryadom/state/app_state.dart';
import 'package:apteka_ryadom/ui/theme.dart';
import 'package:apteka_ryadom/ui/widgets/pharmacy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show loadDemoCatalog;

void main() {
  final catalog = loadDemoCatalog();
  final pharmacy = catalog.pharmacy('neman-chuy-125')!;
  final drug = catalog.drug('paracetamol-500')!;

  Future<List<String>> pump(
    WidgetTester tester, {
    required bool open,
    int? price,
    Drug? withDrug,
    double width = 320,
  }) async {
    final calls = <String>[];
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: PharmacyCard(
              result: PharmacyResult(
                pharmacy: pharmacy,
                distance: 500,
                isOpen: open,
                price: price,
              ),
              catalog: catalog,
              drug: withDrug,
              now: DateTime(2026, 11, 10, open ? 12 : 23, 30),
              mode: TravelMode.walk,
              isFavorite: false,
              onClose: () => calls.add('close'),
              onRoute: () => calls.add('route'),
              onDetails: () => calls.add('details'),
              onToggleFavorite: () => calls.add('fav'),
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('Открытая аптека с выбранным лекарством: цена и кнопки', (
    tester,
  ) async {
    final calls = await pump(tester, open: true, price: 21, withDrug: drug);
    expect(tester.takeException(), isNull);
    expect(find.text(pharmacy.chain), findsOneWidget);
    expect(find.text('Открыто до ${pharmacy.closesAt}'), findsOneWidget);
    expect(find.text('21 сом'), findsOneWidget);
    // 500 м по прямой ≈ 650 м по улицам ≈ 8 минут пешком.
    expect(find.text('≈ 8 мин'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Все фото'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Image),
      ),
      findsNWidgets(4),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Закрыть'));
    await tester.pumpAndSettle();

    // Ряд кнопок листается вбок (как в 2ГИС): на узком экране докручиваем.
    Future<void> tapIn(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
    }

    await tapIn(find.text('Маршрут'));
    await tapIn(find.byTooltip('В избранное'));
    await tapIn(find.byTooltip('Подробнее'));
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(calls, ['route', 'fav', 'details', 'close']);
  });

  testWidgets(
    'Без лекарства — сколько препаратов в наличии; закрытая — «Закрыто до»',
    (tester) async {
      await pump(tester, open: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Закрыто до ${pharmacy.opensAt}'), findsOneWidget);
      final count = catalog.offersForPharmacy(pharmacy.id).length;
      expect(find.textContaining('$count'), findsWidgets);
    },
  );
}
